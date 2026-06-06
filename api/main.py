from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from typing import Optional
from contextlib import asynccontextmanager
import asyncio
import time

from database import db
from control import ControlEngine
from telemetry import log_event, push_metrics

control = ControlEngine(db)
API_START = time.time()


# ============================================================
# MODELS
# ============================================================
class ReportRequest(BaseModel):
    uuid: Optional[str] = None
    computer_id: Optional[int] = None
    version: str = "unknown"
    peripherals: Optional[dict] = None  # sent on first contact / registration
    data: Optional[dict] = None         # telemetry payload

class ConfigRequest(BaseModel):
    mode: Optional[str] = None
    turn_on_percent: Optional[float] = None
    turn_off_percent: Optional[float] = None

class TargetRpmRequest(BaseModel):
    uuid: str
    rpm: int


# ============================================================
# LIFESPAN — background tasks
# ============================================================
@asynccontextmanager
async def lifespan(app: FastAPI):
    task = asyncio.create_task(_offline_checker())
    yield
    task.cancel()

async def _offline_checker():
    while True:
        await asyncio.sleep(5)
        db.mark_offline_stale(timeout_seconds=10)


app = FastAPI(title="Nerdtropy Power Control", lifespan=lifespan)


# ============================================================
# ROUTES
# ============================================================
@app.post("/api/report")
async def report(req: ReportRequest):
    """
    Single endpoint for both registration and telemetry.

    First contact (uuid=None or unknown uuid): slave sends peripherals dict.
    API assigns uuid, name, role and returns them.

    Subsequent calls: slave sends uuid + data. API returns optional command.
    Command includes a human-readable `reason` field for the decision log.
    """
    # --- Registration ---
    is_new = not req.uuid or not db.slave_exists(req.uuid)
    if is_new:
        if not req.peripherals:
            raise HTTPException(400, "peripherals required for first registration")
        slave = db.register_slave(
            uuid=req.uuid,
            computer_id=req.computer_id,
            peripherals=req.peripherals,
            version=req.version,
        )
        log_event(
            slave.name,
            f"Registered {slave.name} ({slave.role}) computer_id={req.computer_id}",
            {"event": "connect", "role": slave.role},
        )
        return {"uuid": slave.uuid, "name": slave.name, "role": slave.role, "command": None}

    # --- Regular telemetry ---
    if req.peripherals:
        db.register_slave(req.uuid, req.computer_id, req.peripherals, req.version)
    db.update_slave_data(req.uuid, req.data or {}, req.version)
    slave = db.get_slave(req.uuid)
    push_metrics(slave)

    command = control.get_command(req.uuid)
    if command:
        db.log_command(req.uuid, command["action"], command["params"], command["reason"])
        log_event(
            slave.name,
            command["reason"],
            {"event": "command", "action": command["action"]},
        )

    return {
        "uuid": req.uuid,
        "name": slave.name,
        "role": slave.role,
        "command": command,
    }


@app.get("/api/state")
async def state():
    """Full system state — polled by the master monitor renderer."""
    return {
        "slaves": db.get_all_slaves_dict(),
        "config": db.get_config(),
        "api_uptime": time.time() - API_START,
        "commands_sent": db.get_command_count(),
    }


@app.get("/api/commands")
async def commands(limit: int = 200, slave_name: str = None):
    """Command history with reasons — the decision log."""
    return db.get_commands(limit=limit, slave_name=slave_name)


@app.post("/api/config")
async def config(req: ConfigRequest):
    """Update operating mode or thresholds from the monitor touch buttons."""
    if req.mode is not None:
        if req.mode not in ("ON", "OFF", "SMART"):
            raise HTTPException(400, "mode must be ON, OFF, or SMART")
        db.set_config("mode", req.mode)
        control.reset_desired_state()
        log_event("system", f"Mode changed to {req.mode}", {"event": "config"})
    if req.turn_on_percent is not None:
        db.set_config("turn_on_percent", str(req.turn_on_percent))
    if req.turn_off_percent is not None:
        db.set_config("turn_off_percent", str(req.turn_off_percent))
    return {"ok": True, "config": db.get_config()}


@app.post("/api/emergency")
async def emergency():
    """Emergency stop — scrams all reactors and turbines immediately."""
    control.emergency_stop()
    log_event("system", "EMERGENCY STOP triggered", {"event": "emergency"})
    return {"ok": True}


@app.post("/api/target_rpm")
async def target_rpm(req: TargetRpmRequest):
    """Set target RPM for a turbine slave."""
    if not db.slave_exists(req.uuid):
        raise HTTPException(404, "slave not found")
    db.set_target_rpm(req.uuid, req.rpm)
    return {"ok": True}


@app.get("/api/health")
async def health():
    return {"ok": True, "uptime": time.time() - API_START}


# ============================================================
# SIMPLE WEB DASHBOARD
# ============================================================
@app.get("/", response_class=HTMLResponse)
async def dashboard():
    """Minimal live dashboard — auto-refreshes every 2 seconds."""
    return HTMLResponse("""<!DOCTYPE html>
<html>
<head>
<title>Nerdtropy Power Control</title>
<meta http-equiv="refresh" content="2">
<style>
body{background:#111;color:#ccc;font-family:monospace;padding:1rem}
h1{color:#0ff}h2{color:#aaa;margin-top:1.5rem}
table{border-collapse:collapse;width:100%;margin-bottom:1rem}
th{color:#888;text-align:left;padding:4px 8px;border-bottom:1px solid #333}
td{padding:4px 8px;border-bottom:1px solid #222}
.ok{color:#0f0}.warn{color:#ff0}.crit{color:#f44}.offline{color:#555}
.cmd-log{max-height:400px;overflow-y:auto}
pre{margin:0}
</style>
</head>
<body>
<h1>⚡ Nerdtropy Power Control</h1>
<div id="state">Loading...</div>
<h2>Decision Log</h2>
<div class="cmd-log" id="cmds">Loading...</div>
<script>
async function refresh() {
    const [state, cmds] = await Promise.all([
        fetch('/api/state').then(r=>r.json()),
        fetch('/api/commands?limit=50').then(r=>r.json()),
    ]);

    const cfg = state.config;
    const slaves = state.slaves;

    let html = `<p>Mode: <b>${cfg.mode}</b> &nbsp;|&nbsp;
        ON @ ${cfg.turn_on_percent}% &nbsp;
        OFF @ ${cfg.turn_off_percent}% &nbsp;|&nbsp;
        Commands sent: ${state.commands_sent} &nbsp;|&nbsp;
        Uptime: ${Math.floor(state.api_uptime)}s</p>`;

    // Battery
    const bats = Object.values(slaves).filter(s=>s.role==='battery');
    if (bats.length) {
        html += '<h2>Battery</h2><table><tr><th>Name</th><th>Fill %</th><th>Energy</th><th>Input</th><th>Output</th><th>Status</th></tr>';
        for (const s of bats) {
            const cls = s.online ? (s.data.fillPercent < 30 ? 'crit' : s.data.fillPercent > 80 ? 'ok' : 'warn') : 'offline';
            html += `<tr class="${cls}"><td>${s.name}</td><td>${s.data.fillPercent?.toFixed(1) ?? '--'}%</td>
                <td>${fmtFE(s.data.energy, s.ptype)}</td>
                <td>+${fmtFE(s.data.lastInput, s.ptype)}/t</td>
                <td>-${fmtFE(s.data.lastOutput, s.ptype)}/t</td>
                <td>${s.online ? 'ONLINE' : 'OFFLINE'}</td></tr>`;
        }
        html += '</table>';
    }

    // Reactors
    const reactors = Object.values(slaves).filter(s=>s.role==='reactor').sort((a,b)=>a.name.localeCompare(b.name));
    if (reactors.length) {
        html += '<h2>Reactors</h2><table><tr><th>Name</th><th>Status</th><th>Output</th><th>Temp</th><th>Fuel %</th><th>Last Cmd</th></tr>';
        for (const s of reactors) {
            const cls = !s.online ? 'offline' : s.data.active ? 'ok' : 'warn';
            const fuel = s.data.fuel && s.data.fuelMax ? (s.data.fuel/s.data.fuelMax*100).toFixed(0)+'%' : '--';
            html += `<tr class="${cls}"><td>${s.name}</td>
                <td>${!s.online ? 'OFFLINE' : s.data.active ? 'ACTIVE' : 'IDLE'}</td>
                <td>${s.data.activelyCooled ? (s.data.steamOutput?.toFixed(0)??'--')+' mB/t' : fmtRawFE(s.data.output)+'/t'}</td>
                <td>${s.data.casingTemp?.toFixed(0) ?? '--'}°C</td>
                <td>${fuel}</td>
                <td title="${s.last_commanded_action??''}">${s.last_commanded_action ? s.last_commanded_action+'='+(s.last_commanded_state??'?') : '--'}</td></tr>`;
        }
        html += '</table>';
    }

    // Turbines
    const turbines = Object.values(slaves).filter(s=>s.role==='turbine').sort((a,b)=>a.name.localeCompare(b.name));
    if (turbines.length) {
        html += '<h2>Turbines</h2><table><tr><th>Name</th><th>RPM</th><th>Target</th><th>Steam</th><th>Output</th><th>Eff%</th><th>Ind</th></tr>';
        for (const s of turbines) {
            const rpm = s.data.rpm ?? 0;
            const tgt = s.target_rpm ?? 1800;
            const rpmCls = Math.abs(rpm-tgt)<=30 ? 'ok' : Math.abs(rpm-tgt)<200 ? 'warn' : 'crit';
            html += `<tr class="${!s.online?'offline':''}"><td>${s.name}</td>
                <td class="${rpmCls}">${rpm.toFixed(0)}</td>
                <td>${tgt}</td>
                <td>${s.data.steamIn?.toFixed(0)??'--'}/${s.data.steamMax?.toFixed(0)??'--'} mB/t</td>
                <td>${fmtRawFE(s.data.output)}/t</td>
                <td>${s.data.bladeEfficiency?.toFixed(0)??'--'}%</td>
                <td class="${s.data.inductorEngaged?'ok':'warn'}">${s.data.inductorEngaged?'ON':'OFF'}</td></tr>`;
        }
        html += '</table>';
    }

    document.getElementById('state').innerHTML = html;

    // Command log
    let chtml = '<table><tr><th>Time</th><th>Slave</th><th>Action</th><th>Reason</th></tr>';
    for (const c of cmds) {
        const t = new Date(c.timestamp * 1000).toLocaleTimeString();
        chtml += `<tr><td>${t}</td><td>${c.slave_name}</td><td>${c.action}</td><td>${c.reason}</td></tr>`;
    }
    document.getElementById('cmds').innerHTML = chtml + '</table>';
}

function fmtFE(j, ptype) {
    if (j == null) return '?';
    const fe = Math.abs(j) / ((ptype||'').includes('induction') ? 2.5 : 1);
    if (fe >= 1e12) return (fe/1e12).toFixed(2)+' TFE';
    if (fe >= 1e9)  return (fe/1e9).toFixed(2)+' GFE';
    if (fe >= 1e6)  return (fe/1e6).toFixed(2)+' MFE';
    if (fe >= 1e3)  return (fe/1e3).toFixed(2)+' kFE';
    return fe.toFixed(0)+' FE';
}

function fmtRawFE(fe) {
    if (fe == null) return '?';
    fe = Math.abs(fe);
    if (fe >= 1e12) return (fe/1e12).toFixed(2)+' TFE';
    if (fe >= 1e9)  return (fe/1e9).toFixed(2)+' GFE';
    if (fe >= 1e6)  return (fe/1e6).toFixed(2)+' MFE';
    if (fe >= 1e3)  return (fe/1e3).toFixed(2)+' kFE';
    return fe.toFixed(0)+' FE';
}

refresh();
setInterval(refresh, 2000);
</script>
</body>
</html>""")
