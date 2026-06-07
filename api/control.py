from database import Database, Slave

# ──────────────────────────────────────────────────────────────────────────────
# RPM band constants (battle-tested from extremereactorcontrol)
#
#   < 98% target  → coils OFF   (spin-up: no generator drag, let RPM climb)
#   98–102% target → coils ON   (stable generating zone)
#   > 102% target  → coils OFF  (overspeed: remove drag, back-pressure drops)
#   > 110% target  → cut steam  (hard safety)
#
# Turbines are NEVER stopped in SMART or ON mode.
# They stay active=True so they can respond the instant steam returns.
# Only inductors toggle to control power generation.
# Hard stops only happen in Mode=OFF or emergency scram.
# ──────────────────────────────────────────────────────────────────────────────

RPM_LOW_PCT   = 0.98
RPM_HIGH_PCT  = 1.02
OVERSPEED_PCT = 1.10

# Auto-tune thresholds
TUNE_STABLE_RPM    = 15    # RPM delta below this = "no longer moving"
TUNE_STABLE_TICKS  = 5     # consecutive ticks stable before acting
TUNE_BRAKE_TICKS   = 8     # ticks to wait for coil braking to settle
TUNE_STALL_THRESH  = 1750  # RPM plateau below this during racing = stalled, target 900 instead
TUNE_SEEK_BAND     = 5     # ±RPM tolerance for "locked on" target
TUNE_SEEK_TICKS    = 5     # consecutive ticks within band before saving calibration
TUNE_VERIFY_TICKS  = 3     # ticks to verify calibration on restart
TUNE_VERIFY_BAND   = 50    # ±RPM tolerance for verification pass
TUNE_STEP_GAIN     = 0.5   # proportional gain for steam trim (err × gain)
TUNE_STEP_MAX      = 50    # max steam change per tick (mB/t)


class ControlEngine:
    def __init__(self, db: Database):
        self.db = db

    def reset_desired_state(self):
        self.db.set_config("desired_reactor_state", "")

    def emergency_stop(self):
        self.db.set_config("mode", "OFF")
        self.db.set_config("desired_reactor_state", "false")
        for s in self.db.get_slaves_by_role("reactor") + self.db.get_slaves_by_role("turbine"):
            if s.online:
                self.db.log_command(s.uuid, "scram", {}, "Emergency stop triggered by user", "user")

    def get_command(self, uuid: str) -> dict | None:
        slave = self.db.get_slave(uuid)
        if not slave or not slave.online:
            return None
        if slave.role == "reactor":
            return self._reactor_command(slave)
        if slave.role == "turbine":
            return self._turbine_command(slave)
        return None

    # ──────────────────────────────────────────────────────────────────────────
    # System desired state
    # ──────────────────────────────────────────────────────────────────────────
    def _compute_desired_state(self) -> tuple[bool | None, str]:
        """
        True  → produce power (reactors on, inductors follow RPM band)
        False → idle (reactors off, turbines coast warm, inductors off)
        None  → no data, hold current
        """
        config = self.db.get_config()
        mode   = config["mode"]

        if mode == "ON":
            return True, "Mode=ON: always producing"
        if mode == "OFF":
            return False, "Mode=OFF: full shutdown"

        battery = self.db.get_battery()
        if not battery:
            return None, "SMART: no battery online, holding current state"

        pct     = battery.data.get("fillPercent", 0) or 0
        on_t    = float(config["turn_on_percent"])
        off_t   = float(config["turn_off_percent"])
        current = config["desired_reactor_state"]

        if pct < on_t:
            new    = True
            reason = f"SMART: battery {pct:.1f}% < {on_t:.0f}% ON threshold — starting reactors"
        elif pct > off_t:
            new    = False
            reason = f"SMART: battery {pct:.1f}% > {off_t:.0f}% OFF threshold — idling reactors (turbines stay warm)"
        else:
            new    = current
            label  = "ON" if current else "OFF" if current is False else "undecided"
            reason = f"SMART: battery {pct:.1f}% in dead band ({on_t:.0f}%–{off_t:.0f}%), holding {label}"

        if new is not None and new != current:
            self.db.set_config("desired_reactor_state", "true" if new else "false")

        return new, reason

    # ──────────────────────────────────────────────────────────────────────────
    # Reactor
    # ──────────────────────────────────────────────────────────────────────────
    def _reactor_command(self, slave: Slave) -> dict | None:
        desired, reason = self._compute_desired_state()
        if desired is None:
            return None
        if slave.data.get("active") == desired:
            return None
        return {"action": "set_reactor", "params": {"state": desired}, "reason": reason}

    # ──────────────────────────────────────────────────────────────────────────
    # Turbine — entry point
    # ──────────────────────────────────────────────────────────────────────────
    def _turbine_command(self, slave: Slave) -> dict | None:
        rpm       = slave.data.get("rpm") or 0
        target    = slave.target_rpm or 1800
        engaged   = slave.data.get("inductorEngaged")
        active    = slave.data.get("active", False)
        assembled = slave.data.get("assembled", True)
        steam_in  = slave.data.get("steamIn") or 0
        steam_max = slave.data.get("steamMaxMax") or 0

        desired, reason = self._compute_desired_state()

        # ── Hard overspeed safety (always checked, even during tuning) ─────
        if rpm > target * OVERSPEED_PCT:
            # Engage coils first — they're a faster brake than cutting steam
            if engaged is not True:
                # Also snap tune phase to braking so racing doesn't re-open steam
                if slave.tune_phase in ("racing", "needs_tune"):
                    self.db.set_tune_state(slave.uuid, "braking", rpm=rpm, stable=0)
                return {
                    "action": "set_inductor",
                    "params": {"state": True},
                    "reason": f"OVERSPEED: {rpm:.0f} RPM > {target * OVERSPEED_PCT:.0f} — engaging coils",
                }
            if steam_in > 0 and steam_max > 0:
                return {
                    "action": "set_flow_rate",
                    "params": {"rate": 0},
                    "reason": f"OVERSPEED: {rpm:.0f} RPM > {target * OVERSPEED_PCT:.0f} — cutting steam (coils already on)",
                }

        # ── Mode=OFF: controlled shutdown ──────────────────────────────────
        if desired is False and self.db.get_config_value("mode") == "OFF":
            if engaged is True:
                return {
                    "action": "set_inductor",
                    "params": {"state": False},
                    "reason": "Mode=OFF: disengaging inductor before shutdown",
                }
            if active:
                return {
                    "action": "set_turbine",
                    "params": {"state": False},
                    "reason": "Mode=OFF: stopping turbine",
                }
            return None

        # ── Start turbine if it's stopped (always keep warm in SMART/ON) ──
        if not active and assembled:
            return {
                "action": "set_turbine",
                "params": {"state": True, "inductor": False},
                "reason": "Starting turbine — coils off, auto-tune will race to 1800",
            }

        if not active:
            return None

        # ── Auto-tune state machine ────────────────────────────────────────
        tune_cmd = self._turbine_tune(slave, rpm, steam_in, steam_max, engaged)
        if tune_cmd is not None:
            return tune_cmd

        # ── Normal operation (only reached when tune_phase == "calibrated") ─
        return self._turbine_normal(slave, rpm, target, steam_in, steam_max, engaged, desired, reason)

    # ──────────────────────────────────────────────────────────────────────────
    # Auto-tune state machine
    #
    # Phases:
    #   needs_tune  → max steam, coils OFF, → racing
    #   racing      → hands off, coils OFF, let RPM climb freely toward 1800
    #                   RPM >= 1800     → engage coils (PRIMARY brake) → braking
    #                   RPM stalls < 1750 → engage coils → seeking_900
    #   braking     → coils ON, hold steam, wait for RPM to settle
    #                   settled ≈ 1800  → calibrated
    #                   settled ≠ 1800  → trim steam (SECONDARY) → trimming
    #   trimming    → coils ON, proportional steam trim to lock 1800 ±5
    #   seeking_900 → coils ON, proportional steam trim to lock 900 ±5, target_rpm=900
    #   verifying   → restart check: replay saved steam, confirm RPM ±50
    #   calibrated  → normal operation handoff
    # ──────────────────────────────────────────────────────────────────────────
    def _turbine_tune(
        self, slave: Slave,
        rpm: float, steam_in: float, steam_max: float, engaged: bool | None
    ) -> dict | None:
        phase = slave.tune_phase

        if phase == "calibrated":
            return None

        if steam_max == 0:
            return None

        # ── needs_tune: open max steam, coils OFF, start racing ───────────
        if phase == "needs_tune":
            self.db.set_tune_state(slave.uuid, "racing", rpm=rpm, stable=0)
            if engaged is not False:
                return {
                    "action": "set_inductor",
                    "params": {"state": False},
                    "reason": "Auto-tune: disengaging coils — racing to 1800 RPM",
                }
            if abs(steam_in - steam_max) > 1:
                return {
                    "action": "set_flow_rate",
                    "params": {"rate": int(steam_max)},
                    "reason": "Auto-tune: opening max steam — racing to 1800 RPM",
                }
            return None

        # ── racing: coils OFF, full steam, watch RPM climb ────────────────
        if phase == "racing":
            # Check RPM threshold FIRST — don't let coil enforcement block the transition
            if rpm >= 1800:
                self.db.set_tune_state(slave.uuid, "braking", rpm=rpm, stable=0)
                return {
                    "action": "set_inductor",
                    "params": {"state": True},
                    "reason": f"Auto-tune: RPM {rpm:.0f} reached 1800 — engaging coils as primary brake",
                }

            # Coils must be off during climb — only force if we KNOW they're on
            if engaged is True:
                return {
                    "action": "set_inductor",
                    "params": {"state": False},
                    "reason": f"Auto-tune racing: coils must be off during climb, RPM {rpm:.0f}",
                }
            # Hold max steam
            if abs(steam_in - steam_max) > 1:
                return {
                    "action": "set_flow_rate",
                    "params": {"rate": int(steam_max)},
                    "reason": f"Auto-tune racing: holding max steam, RPM {rpm:.0f}",
                }

            # Stall detection: track if RPM stopped moving below threshold
            delta  = abs(rpm - slave.tune_rpm)
            stable = slave.tune_stable_count + 1 if delta < TUNE_STABLE_RPM else 0
            self.db.set_tune_state(slave.uuid, "racing",
                                   rpm=rpm if delta >= TUNE_STABLE_RPM else slave.tune_rpm,
                                   stable=stable)

            if stable >= TUNE_STABLE_TICKS and rpm < TUNE_STALL_THRESH:
                # Can't reach 1800 — engage coils and tune for 900
                self.db.set_target_rpm(slave.uuid, 900)
                self.db.set_tune_state(slave.uuid, "seeking_900",
                                       steam=steam_in, rpm=rpm, stable=0)
                self.db.log_command(
                    slave.uuid, "tune_fallback",
                    {"stall_rpm": rpm, "steam_mbt": steam_in},
                    f"Auto-tune: stalled at {rpm:.0f} RPM (< {TUNE_STALL_THRESH}) — engaging coils, targeting 900 RPM",
                    "auto_tune",
                )
                return {
                    "action": "set_inductor",
                    "params": {"state": True},
                    "reason": f"Auto-tune stall: {rpm:.0f} RPM plateau, engaging coils to seek 900",
                }

            return None  # still climbing, hands off

        # ── braking: coils ON, hold steam, wait for RPM to settle ─────────
        if phase == "braking":
            if engaged is not True:
                return {
                    "action": "set_inductor",
                    "params": {"state": True},
                    "reason": f"Auto-tune braking: coils must be on, RPM {rpm:.0f}",
                }

            delta  = abs(rpm - slave.tune_rpm)
            stable = slave.tune_stable_count + 1 if delta < TUNE_STABLE_RPM else 0
            self.db.set_tune_state(slave.uuid, "braking",
                                   rpm=rpm if delta >= TUNE_STABLE_RPM else slave.tune_rpm,
                                   stable=stable)

            if stable < TUNE_BRAKE_TICKS:
                return None  # still settling, hold steam and wait

            # RPM has settled — check where it landed
            if abs(rpm - 1800) <= TUNE_SEEK_BAND:
                # Coils braked it perfectly to 1800
                self.db.set_tune_state(slave.uuid, "calibrated",
                                       steam=steam_in, rpm=rpm, stable=0)
                self.db.log_command(
                    slave.uuid, "tune_complete",
                    {"target_rpm": 1800, "steam_mbt": steam_in, "actual_rpm": rpm},
                    f"Auto-tune complete: coils alone held 1800 RPM @ {steam_in:.0f} mB/t",
                    "auto_tune",
                )
            else:
                # Coils moved it but not exactly to 1800 — trim steam as secondary
                self.db.set_tune_state(slave.uuid, "trimming",
                                       steam=steam_in, rpm=rpm, stable=0)
                self.db.log_command(
                    slave.uuid, "tune_trimming",
                    {"braked_rpm": rpm, "steam_mbt": steam_in},
                    f"Auto-tune: braked to {rpm:.0f} RPM — trimming steam to lock 1800",
                    "auto_tune",
                )
            return None

        # ── trimming: coils ON, proportional steam to lock 1800 ±5 ──────
        if phase == "trimming":
            # Turbine stalled during trim — full retune
            if rpm < 50:
                self.db.set_tune_state(slave.uuid, "needs_tune", steam=0, rpm=0, stable=0)
                self.db.log_command(
                    slave.uuid, "tune_reset",
                    {"rpm": rpm, "steam_mbt": steam_in},
                    f"Auto-tune: turbine stalled during trim ({rpm:.0f} RPM) — retuning",
                    "auto_tune",
                )
                return None

            if engaged is not True:
                return {
                    "action": "set_inductor",
                    "params": {"state": True},
                    "reason": f"Auto-tune trimming: coils must be on, RPM {rpm:.0f}",
                }

            err    = 1800 - rpm
            stable = slave.tune_stable_count

            if abs(err) <= TUNE_SEEK_BAND:
                stable += 1
                self.db.set_tune_state(slave.uuid, "trimming",
                                       steam=steam_in, rpm=rpm, stable=stable)
                if stable >= TUNE_SEEK_TICKS:
                    self.db.set_tune_state(slave.uuid, "calibrated",
                                           steam=steam_in, rpm=rpm, stable=0)
                    self.db.log_command(
                        slave.uuid, "tune_complete",
                        {"target_rpm": 1800, "steam_mbt": steam_in, "actual_rpm": rpm},
                        f"Auto-tune complete: 1800 RPM @ {steam_in:.0f} mB/t (steam trimmed)",
                        "auto_tune",
                    )
                return None

            step     = min(TUNE_STEP_MAX, max(1, abs(err) * TUNE_STEP_GAIN))
            new_rate = steam_in + (step if err > 0 else -step)
            new_rate = max(0, min(steam_max, new_rate))
            self.db.set_tune_state(slave.uuid, "trimming",
                                   steam=new_rate, rpm=rpm, stable=0)
            return {
                "action": "set_flow_rate",
                "params": {"rate": int(new_rate)},
                "reason": f"Auto-tune trim 1800: {rpm:.0f} RPM (err={err:+.0f}), steam {steam_in:.0f}→{new_rate:.0f} mB/t",
            }

        # ── seeking_900: coils ON, proportional steam to lock 900 ±5 ──────
        if phase == "seeking_900":
            if engaged is not True:
                return {
                    "action": "set_inductor",
                    "params": {"state": True},
                    "reason": f"Auto-tune seeking 900: engaging coils, RPM {rpm:.0f}",
                }

            err    = 900 - rpm
            stable = slave.tune_stable_count

            if abs(err) <= TUNE_SEEK_BAND:
                stable += 1
                self.db.set_tune_state(slave.uuid, "seeking_900",
                                       steam=steam_in, rpm=rpm, stable=stable)
                if stable >= TUNE_SEEK_TICKS:
                    self.db.set_tune_state(slave.uuid, "calibrated",
                                           steam=steam_in, rpm=rpm, stable=0)
                    self.db.log_command(
                        slave.uuid, "tune_complete",
                        {"target_rpm": 900, "steam_mbt": steam_in, "actual_rpm": rpm},
                        f"Auto-tune complete: 900 RPM @ {steam_in:.0f} mB/t",
                        "auto_tune",
                    )
                return None

            step     = min(TUNE_STEP_MAX, max(1, abs(err) * TUNE_STEP_GAIN))
            new_rate = steam_in + (step if err > 0 else -step)
            new_rate = max(0, min(steam_max, new_rate))
            self.db.set_tune_state(slave.uuid, "seeking_900",
                                   steam=new_rate, rpm=rpm, stable=0)
            return {
                "action": "set_flow_rate",
                "params": {"rate": int(new_rate)},
                "reason": f"Auto-tune 900: {rpm:.0f} RPM (err={err:+.0f}), steam {steam_in:.0f}→{new_rate:.0f} mB/t",
            }

        # ── verifying: restart check — replay saved steam, confirm RPM ────
        if phase == "verifying":
            cal_steam = slave.tune_steam
            cal_rpm   = slave.tune_rpm
            stable    = slave.tune_stable_count

            # Ensure coils are on (calibrated state always has coils managing load)
            if engaged is not True:
                return {
                    "action": "set_inductor",
                    "params": {"state": True},
                    "reason": "Auto-tune verify: engaging coils for calibration replay",
                }

            if abs(steam_in - cal_steam) > 5:
                return {
                    "action": "set_flow_rate",
                    "params": {"rate": int(cal_steam)},
                    "reason": f"Auto-tune verify: replaying {cal_steam:.0f} mB/t",
                }

            stable += 1
            self.db.set_tune_state(slave.uuid, "verifying", rpm=rpm, stable=stable)

            if stable >= TUNE_VERIFY_TICKS:
                if abs(rpm - cal_rpm) <= TUNE_VERIFY_BAND:
                    self.db.set_tune_state(slave.uuid, "calibrated", stable=0)
                    self.db.log_command(
                        slave.uuid, "tune_verified",
                        {"cal_rpm": cal_rpm, "actual_rpm": rpm, "steam_mbt": cal_steam},
                        f"Auto-tune verified: {rpm:.0f} RPM at {cal_steam:.0f} mB/t (expected {cal_rpm:.0f})",
                        "auto_tune",
                    )
                else:
                    self.db.set_tune_state(slave.uuid, "needs_tune",
                                           steam=0, rpm=0, stable=0)
                    self.db.log_command(
                        slave.uuid, "tune_reset",
                        {"cal_rpm": cal_rpm, "actual_rpm": rpm, "steam_mbt": cal_steam},
                        f"Auto-tune mismatch: got {rpm:.0f} RPM, expected {cal_rpm:.0f} — retuning",
                        "auto_tune",
                    )
            return None

        return None

    # ──────────────────────────────────────────────────────────────────────────
    # Normal operation (tune_phase == "calibrated")
    # ──────────────────────────────────────────────────────────────────────────
    def _turbine_normal(
        self, slave: Slave,
        rpm: float, target: int,
        steam_in: float, steam_max: float,
        engaged: bool | None,
        desired: bool | None, idle_reason: str
    ) -> dict | None:
        low_rpm  = target * RPM_LOW_PCT
        high_rpm = target * RPM_HIGH_PCT

        # System idle (SMART: battery full) — disengage inductor, stay warm
        if desired is False:
            if engaged is True:
                return {
                    "action": "set_inductor",
                    "params": {"state": False},
                    "reason": f"System idle: disengaging inductor — turbine stays warm at {rpm:.0f} RPM",
                }
            return None

        # Spin-up zone: disengage coils so RPM can climb freely
        if rpm < low_rpm:
            if engaged is True:
                return {
                    "action": "set_inductor",
                    "params": {"state": False},
                    "reason": f"Spin-up: {rpm:.0f} RPM < {low_rpm:.0f} (98% target) — disengaging inductor",
                }
            return None

        # Over target: engage coils to add generator drag and pull RPM down
        if rpm > high_rpm:
            if engaged is False:
                return {
                    "action": "set_inductor",
                    "params": {"state": True},
                    "reason": f"Over target: {rpm:.0f} RPM > {high_rpm:.0f} (102%) — engaging inductor",
                }
            return None

        # Stable zone 98–102%: ensure coils are on
        if engaged is False:
            return {
                "action": "set_inductor",
                "params": {"state": True},
                "reason": f"At speed: {rpm:.0f} RPM in stable zone — engaging inductor",
            }

        # Fine-tune flow rate to hold target (small corrections only)
        if steam_max > 0:
            err = target - rpm
            if abs(err) > 10:
                step     = min(100, max(1, abs(err) * 0.5))
                new_rate = steam_in + (step if err > 0 else -step)
                new_rate = max(0, min(steam_max, new_rate))
                if abs(new_rate - steam_in) >= 1:
                    return {
                        "action": "set_flow_rate",
                        "params": {"rate": int(new_rate)},
                        "reason": f"RPM trim: {rpm:.0f}/{target} RPM, flow {steam_in:.0f}→{new_rate:.0f} mB/t",
                    }

        return None
