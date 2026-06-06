# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Nerdtropy Power Control** — A CC:Tweaked Lua + Docker system for managing distributed Minecraft power networks on a NeoForge 1.21.1 ATM10 server. No modems required — all communication is HTTP to the Docker API.

One Lua file runs on every node:
- **`startup.lua`** — Auto-detects role on boot. Monitor on right → Display mode. Any other peripheral → Slave/worker mode.

The Docker stack handles all control logic:
- **`api/`** — FastAPI on port 8000. Receives telemetry, issues commands with reasons, stores history.
- **Gitea** (`10.10.0.10:30008`) — OTA source. `startup.lua` fetches `version.txt` on every boot and self-updates if behind.
- **InfluxDB** (port 8086) — Time-series metrics (battery %, RPM, FE/t).
- **Loki** (port 3100) — Structured decision log (why each command was sent).
- **Grafana** (port 30037, standalone) — Dashboards for metrics and decision log.

## Deployment

No build step. Copy `startup.lua` to every CC:Tweaked computer as `/startup`. Reboot to start.

```
startup.lua  →  /startup  (all nodes — role auto-detected from peripherals)
```

**Hardware wiring convention:** peripheral=back (or any side), redstone output=right, monitor=right (display-only computers).

Display computer requires an Advanced Monitor (6-wide × 4-tall array) on the right. All other computers become slave workers.

Spin up the Docker stack on `10.10.0.10`:
```
docker compose up -d
```

## Architecture

### Passive Worker Pattern

Slaves collect and report peripheral telemetry but **never modify peripheral state on their own**. State changes happen only when the master sends an explicit `COMMAND` message. There is no watchdog, no auto-shutdown, no self-correction on slaves. This design was the result of debugging a rapid-cycling problem where reactive slave logic conflicted with master commands.

### Command Tracking

To avoid re-commanding slaves every poll cycle, the master uses `desiredReactorState` + a `commandedSlaves{}` table. When desired state changes, `commandedSlaves` resets to empty. Each slave is commanded exactly once per state change, then `commandedSlaves[uuid] = true` is set and the slave is left alone. If the "Cmds" counter on the dashboard climbs rapidly, something is resetting `commandedSlaves` incorrectly.

### Cached Commands on Reboot

Slaves persist their last received command to `/pwr_slave/state.dat`. On reboot, the cached command is replayed once before connecting to master — reactors stay in their last state across server restarts without waiting for master to re-command them.

### Network Protocol (`nerdtropy_power`)

Master hostname: `power_master`. All messages are Lua tables sent via `rednet.send()`.

**Slave → Master:**
```
HELLO         { type, role, ptype, uuid, version, cachedCommand }
REPORT        { type, uuid, data }
ACK           { type, uuid, command }
PONG          { type, uuid, version }
UPDATE_RESULT { type, uuid, ok, err }
```

**Master → Slave:**
```
WELCOME  { type, uuid, name }
COMMAND  { type, action, params }   -- action: "set_reactor"|"set_turbine"|"scram"
PING     { type }
UPDATE   { type, content }          -- full file content as string
```

### Slave Roles (auto-detected from peripheral type)

These are the exact CC-reported type strings (case-sensitive — verify with `peripheral.getType("back")` in the Lua REPL):

| Peripheral type string | Role |
|---|---|
| `inductionPort` | `battery` |
| `fissionReactorLogicAdapter`, `fusionReactorLogicAdapter` | `reactor` |
| `BigReactors-Reactor` | `reactor` |
| `BigReactors-Turbine` | `turbine` |
| `energyDetector` | `energy_detector` |

**Mekanism Induction Casing vs Port:** The computer must be adjacent to an Induction **Port** block, not a generic Casing. The casing does not expose energy methods. Only the Port exposes `getEnergy`, `getMaxEnergy`, `getLastInput`, `getLastOutput`.

### Unit Conversion (Critical)

**Mekanism stores energy in Joules. 2.5 J = 1 FE.** `formatFE()` divides by 2.5 and is used for all Mekanism Induction Matrix values (energy, maxEnergy, lastInput, lastOutput).

**BigReactors reports in FE directly — no conversion.** `formatRawFE()` handles reactor and turbine output values without dividing. Mixing these up causes turbine output to display at ~40% of real value (e.g. 495 kFE shows as 197 kFE).

Rule: battery data → `formatFE()`. Reactor/turbine data → `formatRawFE()`.

### Control Modes

- **SMART** — Reactors ON when battery drops to `TURN_ON_PERCENT` (default 30%), OFF at `TURN_OFF_PERCENT` (default 90%)
- **ON** — Reactors always active
- **OFF** — Reactors always inactive

Mode and thresholds persist to `/pwr/config.dat`. Slave registry persists to `/pwr/registry.dat`.

### Concurrency

Master runs four loops via `parallel.waitForAny()`:
1. `rednetListener` — inbound network messages
2. `controlLoop` — applies mode logic, redraws dashboard, saves state (1-second tick)
3. `touchLoop` — monitor touch events (mode/threshold buttons, emergency stop)
4. `terminalLoop` — keypress opens admin terminal (press any key; Q to close)

### REPORT Data Fields

Battery: `energy`, `maxEnergy`, `fillPercent`, `lastInput`, `lastOutput`, `transferCap`, `cells`

Reactor: `active`, `assembled`, `activelyCooled`, `casingTemp`, `fuelTemp`, `fuel`, `fuelMax`, `fuelReactivity`, `fuelBurnRate`, `waste`, `energy`, `energyMax`, `output`, `numRods`, `rodLevel`, and if actively cooled: `coolant`, `coolantMax`, `hotFluid`, `hotFluidMax`, `steamOutput`

Turbine: `active`, `assembled`, `rpm`, `steamIn`, `steamMax`, `steamMaxMax`, `bladeEfficiency`, `numBlades`, `rotorMass`, `inductorEngaged`, `energy`, `energyMax`, `output`, `inputAmount`, `outputAmount`, `fluidAmountMax`

All fields use `safeCall()` (pcall wrapper returning nil on failure) so missing peripheral methods don't crash the slave.

### OTA Update System

Three constants at the top of `master.lua` must point to GitHub raw URLs:
```lua
local GITHUB_SLAVE_URL   = "https://raw.githubusercontent.com/..."
local GITHUB_MASTER_URL  = "https://raw.githubusercontent.com/..."
local GITHUB_VERSION_URL = "https://raw.githubusercontent.com/..."
```

`version.txt` in the repo holds the version string matching `VERSION` in both scripts. Terminal console shows per-node green/yellow version status. Press `C` to check, `U` to push updates. Updates are validated with `load()` for syntax before writing. Master updates itself by writing `startup` then calling `os.reboot()`.

Requires HTTP enabled in `config/computercraft-server.toml`:
```toml
[http]
    enabled = true
[[http.rules]]
    host = "raw.githubusercontent.com"
    action = "allow"
```

### Dashboard Layout (Advanced Monitor)

1. Header bar — mode indicator, title
2. Battery bar — % fill, capacity, net flow, threshold markers
3. Generation / Consumption / Projections — 3-column, rolling 1-min averages, time-to-full/empty
4. Reactors table — name, status, output (mB/t steam or FE passive), fuel %, temp, last seen
5. Turbines table — name, RPM (color-coded, 1800 RPM target), steam in/max, output kFE/t, blade efficiency %, inductor ON/OFF
6. Steam balance — prod vs cons mB/t, surplus/deficit
7. Nodes + warnings — online count, auto-generated alert list
8. Controls row — ON/OFF/SMART buttons, threshold ±5% buttons, EMERGENCY STOP
9. Footer — master version, uptime, command count, clock

Dashboard uses absolute `term.setCursorPos` coordinates sized for 6×4. Colors: green=good, yellow=warn, red=critical, gray=offline. Offline nodes display `--`.

## Key Code Conventions

- All peripheral calls wrapped in `safeCall()` — never assume a method exists
- `formatFE()` for Mekanism values (÷2.5), `formatRawFE()` for BigReactors values
- History: 60-sample rolling window via `addToHistory()` / `avgHistory()`
- Actively-cooled reactor temperature thresholds: warn=100,000°C, crit=120,000°C (normal operating range is 60,000–95,000°C)

## Hard-Won Debugging Notes

1. **Peripheral type strings differ from documentation** — always verify with `peripheral.getType("back")` or `peripheral.getMethods("back")` at the Lua REPL before coding against a new peripheral.
2. **Rapid cycling** — caused by `applyMode()` re-sending commands every poll cycle. Fixed by `commandedSlaves{}` tracking. If the Cmds counter climbs fast, something is clearing `commandedSlaves` incorrectly.
3. **Old watchdog slave** — v1.x slaves had a 30-second watchdog that force-killed reactors if master went silent. v2.0+ has no watchdog. If a reactor keeps shutting off unexpectedly, check the slave's `VERSION` — an old script may still be deployed.
4. **Mekanism Casing vs Port** — computer must be adjacent to an Induction Port, not a Casing block.
5. **BigReactors FE vs Mekanism Joules** — never apply the ÷2.5 conversion to BigReactors values. The two `format*` functions exist precisely to keep this straight.
