import sqlite3
import json
import time
import uuid as uuid_module
import threading
import os
from dataclasses import dataclass, field
from typing import Optional

ROLE_MAP = {
    "inductionPort": "battery",
    "mekanism:induction_port": "battery",
    "fissionReactorLogicAdapter": "reactor",
    "mekanism:fission_reactor_logic_adapter": "reactor",
    "fusionReactorLogicAdapter": "reactor",
    "BigReactors-Reactor": "reactor",
    "BiggerReactors_Reactor": "reactor",
    "bigger_reactors_reactor": "reactor",
    "BigReactors-Turbine": "turbine",
    "BiggerReactors_Turbine": "turbine",
    "bigger_reactors_turbine": "turbine",
    "energyDetector": "energy_detector",
    "energy_detector": "energy_detector",
}

ROLE_PRIORITY = ["battery", "reactor", "turbine", "energy_detector", "unknown"]

NAME_PREFIX = {
    "battery": "Battery",
    "reactor": "Reactor",
    "turbine": "Turbine",
    "energy_detector": "Sensor",
    "unknown": "Node",
}


@dataclass
class Slave:
    uuid: str
    computer_id: Optional[int]
    name: str
    role: str
    ptype: str
    primary_side: str
    peripherals: dict
    version: str
    online: bool
    last_seen: float
    data: dict
    last_commanded_at: Optional[float]
    last_commanded_action: Optional[str]
    last_commanded_state: Optional[bool]
    target_rpm: int = 1800
    # Turbine auto-tune state
    tune_phase: str = "needs_tune"   # needs_tune | spinning_up | seeking | verifying | calibrated
    tune_steam: float = 0.0          # calibrated steam (mB/t) / current seek steam
    tune_rpm: float = 0.0            # calibrated RPM / last seen RPM during spinning_up
    tune_stable_count: int = 0       # consecutive ticks within tolerance


class Database:
    def __init__(self, path: str = None):
        self.path = path or os.environ.get("DB_PATH", "/data/power.db")
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        self._lock = threading.Lock()
        self._conn = sqlite3.connect(self.path, check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        self._init()

    def _init(self):
        with self._lock:
            self._conn.executescript("""
                CREATE TABLE IF NOT EXISTS slaves (
                    uuid TEXT PRIMARY KEY,
                    computer_id INTEGER,
                    name TEXT,
                    role TEXT,
                    ptype TEXT,
                    primary_side TEXT,
                    peripherals TEXT DEFAULT '{}',
                    version TEXT,
                    online INTEGER DEFAULT 0,
                    last_seen REAL DEFAULT 0,
                    data TEXT DEFAULT '{}',
                    last_commanded_at REAL,
                    last_commanded_action TEXT,
                    last_commanded_state INTEGER,
                    target_rpm INTEGER DEFAULT 1800,
                    tune_phase TEXT DEFAULT 'needs_tune',
                    tune_steam REAL DEFAULT 0,
                    tune_rpm REAL DEFAULT 0,
                    tune_stable_count INTEGER DEFAULT 0
                );
                CREATE TABLE IF NOT EXISTS commands (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp REAL,
                    slave_uuid TEXT,
                    slave_name TEXT,
                    action TEXT,
                    params TEXT,
                    reason TEXT,
                    triggered_by TEXT DEFAULT 'control_loop'
                );
                CREATE TABLE IF NOT EXISTS config (
                    key TEXT PRIMARY KEY,
                    value TEXT
                );
                CREATE TABLE IF NOT EXISTS serial_counters (
                    role TEXT PRIMARY KEY,
                    count INTEGER DEFAULT 0
                );
            """)
            for k, v in {
                "mode": "SMART",
                "turn_on_percent": "30",
                "turn_off_percent": "90",
                "desired_reactor_state": "",
                "commands_sent": "0",
            }.items():
                self._conn.execute(
                    "INSERT OR IGNORE INTO config (key, value) VALUES (?, ?)", (k, v)
                )
            # Migrate existing DBs — ADD COLUMN is idempotent via try/except
            for col, defn in [
                ("tune_phase", "TEXT DEFAULT 'needs_tune'"),
                ("tune_steam", "REAL DEFAULT 0"),
                ("tune_rpm",   "REAL DEFAULT 0"),
                ("tune_stable_count", "INTEGER DEFAULT 0"),
            ]:
                try:
                    self._conn.execute(f"ALTER TABLE slaves ADD COLUMN {col} {defn}")
                except Exception:
                    pass  # column already exists
            self._conn.commit()

    # ------------------------------------------------------------------ helpers
    def _determine_role(self, peripherals: dict) -> tuple[str, str, str]:
        found = {}
        for side, info in peripherals.items():
            ptype = info.get("type", "")
            role = ROLE_MAP.get(ptype, "unknown")
            if role not in found:
                found[role] = (side, ptype)
        for r in ROLE_PRIORITY:
            if r in found:
                return r, found[r][0], found[r][1]
        if peripherals:
            side = next(iter(peripherals))
            return "unknown", side, peripherals[side].get("type", "unknown")
        return "unknown", "back", "unknown"

    def _next_serial(self, role: str) -> int:
        self._conn.execute(
            "INSERT OR IGNORE INTO serial_counters (role, count) VALUES (?, 0)", (role,)
        )
        self._conn.execute(
            "UPDATE serial_counters SET count = count + 1 WHERE role = ?", (role,)
        )
        row = self._conn.execute(
            "SELECT count FROM serial_counters WHERE role = ?", (role,)
        ).fetchone()
        self._conn.commit()
        return row[0]

    def _row_to_slave(self, row) -> Slave:
        lcs = row["last_commanded_state"]
        keys = row.keys()
        return Slave(
            uuid=row["uuid"],
            computer_id=row["computer_id"],
            name=row["name"],
            role=row["role"] or "unknown",
            ptype=row["ptype"] or "",
            primary_side=row["primary_side"] or "back",
            peripherals=json.loads(row["peripherals"] or "{}"),
            version=row["version"] or "?",
            online=bool(row["online"]),
            last_seen=row["last_seen"] or 0,
            data=json.loads(row["data"] or "{}"),
            last_commanded_at=row["last_commanded_at"],
            last_commanded_action=row["last_commanded_action"],
            last_commanded_state=bool(lcs) if lcs is not None else None,
            target_rpm=row["target_rpm"] or 1800,
            tune_phase=row["tune_phase"] if "tune_phase" in keys else "needs_tune",
            tune_steam=row["tune_steam"] if "tune_steam" in keys else 0.0,
            tune_rpm=row["tune_rpm"] if "tune_rpm" in keys else 0.0,
            tune_stable_count=row["tune_stable_count"] if "tune_stable_count" in keys else 0,
        )

    # ------------------------------------------------------------------ slaves
    def slave_exists(self, uuid: str) -> bool:
        return self._conn.execute(
            "SELECT 1 FROM slaves WHERE uuid = ?", (uuid,)
        ).fetchone() is not None

    def register_slave(self, uuid, computer_id, peripherals, version) -> Slave:
        role, primary_side, ptype = self._determine_role(peripherals)

        if uuid and self.slave_exists(uuid):
            with self._lock:
                self._conn.execute(
                    "UPDATE slaves SET computer_id=?, version=?, online=1, last_seen=?, peripherals=? WHERE uuid=?",
                    (computer_id, version, time.time(), json.dumps(peripherals), uuid),
                )
                self._conn.commit()
            return self.get_slave(uuid)

        new_uuid = uuid or str(uuid_module.uuid4())[:13]
        with self._lock:
            n = self._next_serial(role)
            name = f"{NAME_PREFIX.get(role, 'Node')}-{n}"
            self._conn.execute(
                """INSERT OR REPLACE INTO slaves
                   (uuid, computer_id, name, role, ptype, primary_side, peripherals,
                    version, online, last_seen, data, target_rpm)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, '{}', 1800)""",
                (new_uuid, computer_id, name, role, ptype, primary_side,
                 json.dumps(peripherals), version, time.time()),
            )
            self._conn.commit()
        return self.get_slave(new_uuid)

    def get_slave(self, uuid: str) -> Optional[Slave]:
        row = self._conn.execute(
            "SELECT * FROM slaves WHERE uuid = ?", (uuid,)
        ).fetchone()
        return self._row_to_slave(row) if row else None

    def update_slave_data(self, uuid: str, data: dict, version: str):
        row = self._conn.execute(
            "SELECT online, role, tune_phase FROM slaves WHERE uuid=?", (uuid,)
        ).fetchone()
        coming_online = row and not row["online"]
        is_turbine    = row and row["role"] == "turbine"
        was_calibrated = row and row["tune_phase"] == "calibrated"

        with self._lock:
            self._conn.execute(
                "UPDATE slaves SET data=?, version=?, online=1, last_seen=? WHERE uuid=?",
                (json.dumps(data), version, time.time(), uuid),
            )
            # Turbine coming back online after being calibrated → re-verify
            if coming_online and is_turbine and was_calibrated:
                self._conn.execute(
                    "UPDATE slaves SET tune_phase='verifying', tune_stable_count=0 WHERE uuid=?",
                    (uuid,),
                )
            self._conn.commit()

    def mark_offline_stale(self, timeout_seconds: float = 10):
        cutoff = time.time() - timeout_seconds
        with self._lock:
            self._conn.execute(
                "UPDATE slaves SET online=0 WHERE last_seen < ? AND online=1", (cutoff,)
            )
            self._conn.commit()

    def get_all_slaves_dict(self) -> dict:
        rows = self._conn.execute("SELECT * FROM slaves").fetchall()
        result = {}
        for row in rows:
            s = self._row_to_slave(row)
            result[s.uuid] = {
                "name": s.name, "role": s.role, "ptype": s.ptype,
                "online": s.online, "last_seen": s.last_seen,
                "data": s.data, "version": s.version,
                "last_commanded_action": s.last_commanded_action,
                "last_commanded_state": s.last_commanded_state,
                "target_rpm": s.target_rpm,
                "tune_phase": s.tune_phase,
                "peripherals": s.peripherals,
            }
        return result

    def get_battery(self) -> Optional[Slave]:
        row = self._conn.execute(
            "SELECT * FROM slaves WHERE role='battery' AND online=1 LIMIT 1"
        ).fetchone()
        return self._row_to_slave(row) if row else None

    def get_slaves_by_role(self, role: str) -> list[Slave]:
        rows = self._conn.execute(
            "SELECT * FROM slaves WHERE role=?", (role,)
        ).fetchall()
        return [self._row_to_slave(r) for r in rows]

    # ------------------------------------------------------------------ config
    def get_config(self) -> dict:
        rows = self._conn.execute("SELECT key, value FROM config").fetchall()
        cfg = {r["key"]: r["value"] for r in rows}
        drs = cfg.get("desired_reactor_state", "")
        return {
            "mode": cfg.get("mode", "SMART"),
            "turn_on_percent": float(cfg.get("turn_on_percent", 30)),
            "turn_off_percent": float(cfg.get("turn_off_percent", 90)),
            "desired_reactor_state": (True if drs == "true" else False if drs == "false" else None),
            "commands_sent": int(cfg.get("commands_sent", 0)),
        }

    def set_config(self, key: str, value: str):
        with self._lock:
            self._conn.execute(
                "INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)", (key, value)
            )
            self._conn.commit()

    def get_config_value(self, key: str, default=None) -> Optional[str]:
        row = self._conn.execute(
            "SELECT value FROM config WHERE key = ?", (key,)
        ).fetchone()
        return row["value"] if row else default

    # ------------------------------------------------------------------ commands
    def log_command(
        self, uuid: str, action: str, params: dict, reason: str,
        triggered_by: str = "control_loop"
    ):
        slave = self.get_slave(uuid)
        state_val = None
        if "state" in params:
            state_val = 1 if params["state"] else 0
        with self._lock:
            self._conn.execute(
                """INSERT INTO commands
                   (timestamp, slave_uuid, slave_name, action, params, reason, triggered_by)
                   VALUES (?, ?, ?, ?, ?, ?, ?)""",
                (time.time(), uuid, slave.name if slave else uuid,
                 action, json.dumps(params), reason, triggered_by),
            )
            self._conn.execute(
                "UPDATE slaves SET last_commanded_at=?, last_commanded_action=?, last_commanded_state=? WHERE uuid=?",
                (time.time(), action, state_val, uuid),
            )
            self._conn.execute(
                "UPDATE config SET value=CAST(CAST(value AS INTEGER)+1 AS TEXT) WHERE key='commands_sent'"
            )
            self._conn.commit()

    def get_commands(self, limit: int = 100, slave_name: str = None) -> list:
        if slave_name:
            rows = self._conn.execute(
                "SELECT * FROM commands WHERE slave_name=? ORDER BY timestamp DESC LIMIT ?",
                (slave_name, limit),
            ).fetchall()
        else:
            rows = self._conn.execute(
                "SELECT * FROM commands ORDER BY timestamp DESC LIMIT ?", (limit,)
            ).fetchall()
        return [
            {
                "id": r["id"], "timestamp": r["timestamp"],
                "slave_name": r["slave_name"], "action": r["action"],
                "params": json.loads(r["params"]), "reason": r["reason"],
                "triggered_by": r["triggered_by"],
            }
            for r in rows
        ]

    def get_command_count(self) -> int:
        return int(self.get_config_value("commands_sent", "0"))

    def set_tune_state(
        self, uuid: str, phase: str,
        steam: float = None, rpm: float = None, stable: int = None
    ):
        parts, vals = [], []
        parts.append("tune_phase=?"); vals.append(phase)
        if steam is not None:
            parts.append("tune_steam=?"); vals.append(steam)
        if rpm is not None:
            parts.append("tune_rpm=?"); vals.append(rpm)
        if stable is not None:
            parts.append("tune_stable_count=?"); vals.append(stable)
        vals.append(uuid)
        with self._lock:
            self._conn.execute(
                f"UPDATE slaves SET {', '.join(parts)} WHERE uuid=?", vals
            )
            self._conn.commit()

    def set_target_rpm(self, uuid: str, rpm: int):
        with self._lock:
            self._conn.execute(
                "UPDATE slaves SET target_rpm=? WHERE uuid=?", (rpm, uuid)
            )
            self._conn.commit()


db = Database()
