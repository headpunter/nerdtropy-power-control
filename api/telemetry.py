import os
import time
import requests
from database import Slave

LOKI_URL = os.environ.get("LOKI_URL", "http://loki:3100")
INFLUXDB_URL = os.environ.get("INFLUXDB_URL", "http://influxdb:8086")
INFLUXDB_TOKEN = os.environ.get("INFLUXDB_TOKEN", "nerdtropy-admin-token")
INFLUXDB_ORG = os.environ.get("INFLUXDB_ORG", "nerdtropy")
INFLUXDB_BUCKET = os.environ.get("INFLUXDB_BUCKET", "power")

_session = requests.Session()


def log_event(slave_name: str, message: str, labels: dict = None):
    """Push a structured log line to Loki."""
    stream = {"job": "power-api", "slave": slave_name}
    if labels:
        stream.update(labels)
    payload = {
        "streams": [{
            "stream": stream,
            "values": [[str(int(time.time() * 1e9)), message]],
        }]
    }
    try:
        _session.post(f"{LOKI_URL}/loki/api/v1/push", json=payload, timeout=2)
    except Exception:
        pass


def push_metrics(slave: Slave):
    """Push time-series data to InfluxDB line protocol."""
    if not slave or not slave.data:
        return

    tag_name = slave.name.replace(" ", "_")
    tags = f"slave={tag_name},role={slave.role},uuid={slave.uuid}"
    ts = int(time.time() * 1e9)
    d = slave.data
    lines = []

    if slave.role == "battery":
        # Mekanism stores J; 2.5 J = 1 FE
        factor = 2.5 if "induction" in slave.ptype.lower() else 1.0
        fields = []
        if d.get("fillPercent") is not None:
            fields.append(f"fill_pct={d['fillPercent']:.4f}")
        if d.get("energy") is not None:
            fields.append(f"energy_fe={d['energy'] / factor:.2f}")
        if d.get("maxEnergy") is not None:
            fields.append(f"max_energy_fe={d['maxEnergy'] / factor:.2f}")
        if d.get("lastInput") is not None:
            fields.append(f"input_fe={d['lastInput'] / factor:.4f}")
        if d.get("lastOutput") is not None:
            fields.append(f"output_fe={d['lastOutput'] / factor:.4f}")
        if d.get("lastInput") is not None and d.get("lastOutput") is not None:
            fields.append(f"net_fe={(d['lastInput'] - d['lastOutput']) / factor:.4f}")
        if fields:
            lines.append(f"battery,{tags} {','.join(fields)} {ts}")

    elif slave.role == "reactor":
        fields = []
        if d.get("active") is not None:
            fields.append(f"active={1 if d['active'] else 0}i")
        if d.get("casingTemp") is not None:
            fields.append(f"casing_temp={d['casingTemp']:.2f}")
        if d.get("fuelTemp") is not None:
            fields.append(f"fuel_temp={d['fuelTemp']:.2f}")
        if d.get("output") is not None:
            fields.append(f"output_fe={d['output']:.4f}")
        if d.get("fuel") and d.get("fuelMax") and d["fuelMax"] > 0:
            fields.append(f"fuel_pct={d['fuel'] / d['fuelMax'] * 100:.2f}")
        if d.get("steamOutput") is not None:
            fields.append(f"steam_output={d['steamOutput']:.2f}")
        if fields:
            lines.append(f"reactor,{tags} {','.join(fields)} {ts}")

    elif slave.role == "turbine":
        fields = []
        if d.get("active") is not None:
            fields.append(f"active={1 if d['active'] else 0}i")
        if d.get("rpm") is not None:
            fields.append(f"rpm={d['rpm']:.2f}")
        if d.get("steamIn") is not None:
            fields.append(f"steam_in={d['steamIn']:.2f}")
        if d.get("output") is not None:
            fields.append(f"output_fe={d['output']:.4f}")
        if d.get("bladeEfficiency") is not None:
            fields.append(f"blade_eff={d['bladeEfficiency']:.2f}")
        if d.get("inductorEngaged") is not None:
            fields.append(f"inductor={1 if d['inductorEngaged'] else 0}i")
        if fields:
            lines.append(f"turbine,{tags} {','.join(fields)} {ts}")

    if not lines:
        return

    try:
        _session.post(
            f"{INFLUXDB_URL}/api/v2/write"
            f"?org={INFLUXDB_ORG}&bucket={INFLUXDB_BUCKET}&precision=ns",
            data="\n".join(lines),
            headers={
                "Authorization": f"Token {INFLUXDB_TOKEN}",
                "Content-Type": "text/plain; charset=utf-8",
            },
            timeout=2,
        )
    except Exception:
        pass
