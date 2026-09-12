#!/usr/bin/env python3
"""
Cadence iOS Simulator automation for agents.

Screenshots, taps (by label or coordinates), navigation, and scripted flows.
Uses simctl + idb (Facebook iOS Development Bridge) when available.

Examples:
  ./scripts/cadence_sim doctor
  ./scripts/cadence_sim build install launch
  ./scripts/cadence_sim navigate tab today
  ./scripts/cadence_sim screenshot --name today
  ./scripts/cadence_sim describe --json
  ./scripts/cadence_sim tap-label "Open sidebar"
  ./scripts/cadence_sim run spot_check
  ./scripts/cadence_sim spot-check
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
FLOWS_DIR = Path(__file__).resolve().parent / "cadence_sim_flows"
DEFAULT_UDID = "E06A7FB1-24AB-4F46-BEB9-9A0CFFEB83F0"
DEFAULT_DEVICE = "iPhone 16 Pro Max (no Watch)"
DEFAULT_BUNDLE = "com.musclemeal.app"
DEFAULT_DERIVED = "/tmp/CadenceDerived"
DEFAULT_APP = f"{DEFAULT_DERIVED}/Build/Products/Debug-iphonesimulator/MealPlannerApp.app"
DEFAULT_SHOTS = "/tmp/cadence-spot-check"


@dataclass
class Config:
    udid: str
    bundle: str
    app_path: str
    shot_dir: str
    device_name: str
    project: str
    json_output: bool

    @classmethod
    def from_env(cls, json_output: bool = False) -> Config:
        return cls(
            udid=os.environ.get("CADENCE_SIM_UDID", DEFAULT_UDID),
            bundle=os.environ.get("CADENCE_BUNDLE", DEFAULT_BUNDLE),
            app_path=os.environ.get("CADENCE_APP_PATH", DEFAULT_APP),
            shot_dir=os.environ.get("CADENCE_SHOT_DIR", DEFAULT_SHOTS),
            device_name=os.environ.get("CADENCE_DEVICE", DEFAULT_DEVICE),
            project=str(ROOT / "MealPlannerApp/MealPlannerApp.xcodeproj"),
            json_output=json_output,
        )


class CadenceSimError(Exception):
    pass


def emit(cfg: Config, ok: bool, command: str, **payload: Any) -> None:
    payload = {"ok": ok, "command": command, **payload}
    if cfg.json_output:
        print(json.dumps(payload, indent=2))
    elif ok:
        summary = payload.get("message") or payload.get("path") or command
        print(f"cadence_sim {command}: {summary}")
    else:
        err = payload.get("error", "unknown error")
        print(f"cadence_sim {command} failed: {err}", file=sys.stderr)


def run(cmd: list[str], *, check: bool = True, capture: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        check=check,
        text=True,
        capture_output=capture,
    )


def find_idb() -> str | None:
    for candidate in (
        shutil.which("idb"),
        "/opt/homebrew/bin/idb",
        os.path.expanduser("~/Library/Python/3.9/bin/idb"),
        os.path.expanduser("~/Library/Python/3.11/bin/idb"),
        os.path.expanduser("~/Library/Python/3.12/bin/idb"),
    ):
        if candidate and Path(candidate).is_file():
            return candidate
    return None


def simctl(cfg: Config, *args: str, check: bool = True, capture: bool = False) -> subprocess.CompletedProcess[str]:
    return run(["xcrun", "simctl", *args], check=check, capture=capture)


def idb(cfg: Config, *args: str, check: bool = True, capture: bool = False) -> subprocess.CompletedProcess[str]:
    binary = find_idb()
    if not binary:
        raise CadenceSimError("idb not found. Run: brew install facebook/fb/idb")
    env = os.environ.copy()
    env["IDB_UDID"] = cfg.udid
    cmd = [binary, *args]
    needs_udid = args and args[0] in {
        "ui", "screenshot", "launch", "terminate", "install", "open", "describe", "file", "log",
    }
    if needs_udid:
        cmd.extend(["--udid", cfg.udid])
    return subprocess.run(
        cmd,
        check=check,
        text=True,
        capture_output=capture,
        env=env,
    )


def ensure_booted(cfg: Config) -> None:
    # Only boot when needed — `simctl boot` errors loudly if already Booted.
    try:
        proc = run(
            ["xcrun", "simctl", "list", "devices", "booted", "-j"],
            check=False,
            capture=True,
        )
        data = json.loads(proc.stdout or "{}")
        booted = any(
            d.get("udid") == cfg.udid
            for devices in (data.get("devices") or {}).values()
            for d in devices
            if isinstance(d, dict)
        )
    except Exception:
        booted = False
    if not booted:
        simctl(cfg, "boot", cfg.udid, check=False, capture=True)
    run(["open", "-a", "Simulator"], check=False)
    time.sleep(0.3)


def normalize_elements(raw: Any) -> list[dict[str, Any]]:
    if isinstance(raw, dict):
        return [raw]
    if not isinstance(raw, list):
        return []
    out: list[dict[str, Any]] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        label = item.get("AXLabel") or item.get("label") or ""
        ident = item.get("AXUniqueId") or item.get("identifier") or item.get("id") or ""
        frame = item.get("frame") or item.get("AXFrame") or {}
        role = item.get("role") or item.get("AXRole") or ""
        out.append(
            {
                "label": label,
                "identifier": ident,
                "role": role,
                "frame": frame,
                "raw": item,
            }
        )
    return out


TAB_INDEX = {"today": 0, "calendar": 1, "meals": 2, "matrix": 3, "habits": 4}
# Wheel destinations beyond the legacy 5-tab indices (launch via -openWheel).
WHEEL_DESTINATIONS = {
    "today",
    "calendar",
    "meals",
    "matrix",
    "habits",
    "shop",
    "inbox",
    "browse",
    "workout",
    "spend",
    "health",
    "news",
    "focus",
    "settings",
}
TAB_COORDS = [(44, 915), (132, 915), (220, 915), (308, 915), (396, 915)]


def launch_with_args(cfg: Config, extra_args: list[str]) -> str:
    ensure_booted(cfg)
    args = ["launch", cfg.udid, cfg.bundle, *extra_args]
    proc = simctl(cfg, *args, capture=True)
    return (proc.stdout or "").strip().split(":")[-1].strip()


def relaunch(cfg: Config, *extra_args: str) -> str:
    simctl(cfg, "terminate", cfg.udid, cfg.bundle, check=False)
    time.sleep(0.25)
    launch_args = ["-cadenceSkipOnboarding", *extra_args]
    return launch_with_args(cfg, launch_args)


def cmd_doctor(cfg: Config) -> int:
    checks: dict[str, Any] = {}
    try:
        run(["xcrun", "simctl", "list", "devices", "booted", "-j"], capture=True)
        checks["simctl"] = True
    except subprocess.CalledProcessError:
        checks["simctl"] = False

    idb_path = find_idb()
    checks["idb"] = idb_path or False
    if idb_path:
        try:
            idb(cfg, "list-targets", capture=True)
            checks["idb_companion"] = True
        except subprocess.CalledProcessError as exc:
            checks["idb_companion"] = False
            checks["idb_error"] = (exc.stderr or exc.stdout or str(exc)).strip()

    checks["cliclick"] = bool(shutil.which("cliclick"))
    checks["app_bundle"] = Path(cfg.app_path).is_dir()
    checks["flows_dir"] = str(FLOWS_DIR)
    ok = checks["simctl"] and bool(checks["idb"]) and checks.get("idb_companion", False)
    emit(cfg, ok, "doctor", checks=checks, message="ready" if ok else "missing dependencies")
    return 0 if ok else 1


def cmd_build(cfg: Config) -> int:
    derived = Path(cfg.app_path).parents[3] if "Build/Products" in cfg.app_path else Path(DEFAULT_DERIVED)
    cmd = [
        "xcodebuild",
        "-scheme",
        "MealPlannerApp",
        "-project",
        cfg.project,
        "-destination",
        f"platform=iOS Simulator,id={cfg.udid}",
        "-derivedDataPath",
        str(derived),
        "build",
    ]
    run(cmd)
    emit(cfg, True, "build", path=cfg.app_path, message="build succeeded")
    return 0


def cmd_boot(cfg: Config) -> int:
    ensure_booted(cfg)
    emit(cfg, True, "boot", udid=cfg.udid)
    return 0


def cmd_install(cfg: Config) -> int:
    if not Path(cfg.app_path).is_dir():
        raise CadenceSimError(f"Missing app bundle: {cfg.app_path}")
    ensure_booted(cfg)
    simctl(cfg, "install", cfg.udid, cfg.app_path)
    emit(cfg, True, "install", path=cfg.app_path)
    return 0


def cmd_launch(cfg: Config, extra_args: list[str] | None = None) -> int:
    pid = launch_with_args(cfg, extra_args or ["-cadenceSkipOnboarding"])
    emit(cfg, True, "launch", pid=pid, args=extra_args or ["-cadenceSkipOnboarding"])
    return 0


def cmd_terminate(cfg: Config) -> int:
    simctl(cfg, "terminate", cfg.udid, cfg.bundle, check=False)
    emit(cfg, True, "terminate")
    return 0


def cmd_open_url(cfg: Config, url: str) -> int:
    simctl(cfg, "openurl", cfg.udid, url)
    emit(cfg, True, "open-url", url=url)
    return 0


def cmd_navigate(cfg: Config, target: str, value: str, in_session: bool = False) -> int:
    target_l = target.lower()
    value_l = value.lower()

    if target_l in ("tab", "wheel"):
        if value_l.isdigit():
            index = int(value_l)
            if in_session and 0 <= index < len(TAB_COORDS):
                x, y = TAB_COORDS[index]
                cmd_tap(cfg, x, y)
                emit(cfg, True, "navigate", target="tab", value=value_l, mode="tap")
                return 0
            pid = relaunch(cfg, "-openMainTab", str(index))
            time.sleep(0.8)
            emit(cfg, True, "navigate", target="tab", value=value_l, mode="launch", pid=pid)
            return 0

        if value_l in TAB_INDEX and target_l == "tab":
            index = TAB_INDEX[value_l]
            if in_session and 0 <= index < len(TAB_COORDS):
                x, y = TAB_COORDS[index]
                cmd_tap(cfg, x, y)
                emit(cfg, True, "navigate", target="tab", value=value_l, mode="tap")
                return 0
            pid = relaunch(cfg, "-openMainTab", str(index))
            time.sleep(0.8)
            emit(cfg, True, "navigate", target="tab", value=value_l, mode="launch", pid=pid)
            return 0

        if value_l in WHEEL_DESTINATIONS:
            if in_session:
                # Prefer accessibility id on the dial/grid when already running.
                try:
                    cmd_tap_label(cfg, f"wheel-app-{value_l}", match_key="AXUniqueId")
                    emit(cfg, True, "navigate", target="wheel", value=value_l, mode="tap-label")
                    return 0
                except Exception:
                    pass
            pid = relaunch(cfg, "-openWheel", value_l)
            time.sleep(0.8)
            emit(cfg, True, "navigate", target="wheel", value=value_l, mode="launch", pid=pid)
            return 0

        raise CadenceSimError(f"Unknown tab/wheel destination: {value}")

    launch_flags = {
        ("open", "settings"): ["-openSettings"],
        ("open", "search"): ["-openGlobalSearch"],
        ("open", "shop"): ["-openShop"],
        ("open", "spend"): ["-openWheel", "spend"],
        ("open", "focus"): ["-openWheel", "focus"],
        ("open", "news"): ["-openWheel", "news"],
        ("open", "health"): ["-openWheel", "health"],
        ("open", "inbox"): ["-openWheel", "inbox"],
        ("open", "browse"): ["-openWheel", "browse"],
        ("open", "workout"): ["-openWheel", "workout"],
    }
    key = (target_l, value_l)
    if key in launch_flags:
        pid = relaunch(cfg, *launch_flags[key])
        time.sleep(0.8)
        emit(cfg, True, "navigate", target=target_l, value=value_l, mode="launch", pid=pid)
        return 0

    if key == ("open", "drawer"):
        cmd_tap_label(cfg, "Open sidebar")
        emit(cfg, True, "navigate", target="open", value="drawer", mode="tap-label")
        return 0

    if target_l == "close":
        if value_l == "all":
            for step in ("settings", "search", "drawer"):
                try:
                    cmd_navigate(cfg, "close", step, in_session=True)
                except Exception:
                    pass
            emit(cfg, True, "navigate", target="close", value="all")
            return 0
        if value_l == "settings":
            # Swipe sheet down — tap near top outside or use key. Relaunching main tab is safer.
            pid = relaunch(cfg, "-openMainTab", "0")
            emit(cfg, True, "navigate", target="close", value="settings", mode="launch", pid=pid)
            return 0
        if value_l == "search":
            # idb has no escape button — dismiss via relaunch to Today.
            pid = relaunch(cfg, "-openMainTab", "0")
            emit(cfg, True, "navigate", target="close", value="search", mode="launch", pid=pid)
            return 0
        if value_l == "drawer":
            try:
                cmd_tap_label(cfg, "Close sidebar")
                emit(cfg, True, "navigate", target="close", value="drawer", mode="tap-label")
            except Exception:
                pid = relaunch(cfg, "-openMainTab", "0")
                emit(cfg, True, "navigate", target="close", value="drawer", mode="launch", pid=pid)
            return 0

    raise CadenceSimError(f"Unknown navigation: {target} {value}")


def cmd_wait(cfg: Config, seconds: float) -> int:
    time.sleep(seconds)
    emit(cfg, True, "wait", seconds=seconds)
    return 0


def cmd_ui_appearance(cfg: Config, mode: str) -> int:
    simctl(cfg, "ui", cfg.udid, "appearance", mode)
    emit(cfg, True, "ui-appearance", mode=mode)
    return 0


def screenshot_path(cfg: Config, name: str | None) -> Path:
    Path(cfg.shot_dir).mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    filename = f"{name or 'screen'}-{stamp}.png" if name else f"screen-{stamp}.png"
    if name and not name.endswith(".png"):
        filename = f"{name}.png"
    return Path(cfg.shot_dir) / filename


def cmd_screenshot(cfg: Config, name: str | None = None, out: str | None = None) -> int:
    path = Path(out) if out else screenshot_path(cfg, name)
    path.parent.mkdir(parents=True, exist_ok=True)
    if find_idb():
        try:
            idb(cfg, "screenshot", str(path), "--format", "png")
        except subprocess.CalledProcessError:
            simctl(cfg, "io", cfg.udid, "screenshot", str(path))
    else:
        simctl(cfg, "io", cfg.udid, "screenshot", str(path))
    emit(cfg, True, "screenshot", path=str(path), name=name)
    return 0


def cmd_describe(cfg: Config, query: str | None = None) -> int:
    proc = idb(cfg, "ui", "describe-all", "--json", capture=True)
    raw = json.loads(proc.stdout or "[]")
    elements = normalize_elements(raw)
    if query:
        q = query.lower()
        elements = [
            el
            for el in elements
            if q in (el.get("label") or "").lower() or q in (el.get("identifier") or "").lower()
        ]
    payload = {"count": len(elements), "elements": elements}
    if cfg.json_output:
        emit(cfg, True, "describe", **payload)
    else:
        for el in elements:
            label = el.get("label") or "(no label)"
            ident = el.get("identifier") or ""
            frame = el.get("frame") or {}
            print(f"{label}\tid={ident}\tframe={frame}")
        emit(cfg, True, "describe", count=len(elements))
    return 0


def cmd_tap(cfg: Config, x: float, y: float, duration: float | None = None) -> int:
    tx, ty = int(round(x)), int(round(y))
    args = ["ui", "tap", f"{tx}", f"{ty}", "--api", "hid"]
    if duration is not None:
        args.extend(["--duration", str(duration)])
    idb(cfg, *args)
    emit(cfg, True, "tap", x=tx, y=ty)
    return 0


def cmd_tap_label(cfg: Config, label: str, match_key: str = "AXLabel") -> int:
    idb(cfg, "ui", "tap", label, "--match-key", match_key, "--api", "ax")
    emit(cfg, True, "tap-label", label=label, match_key=match_key)
    return 0


def cmd_swipe(cfg: Config, x1: float, y1: float, x2: float, y2: float) -> int:
    # idb requires integer pixel coordinates
    sx1, sy1, sx2, sy2 = int(round(x1)), int(round(y1)), int(round(x2)), int(round(y2))
    idb(cfg, "ui", "swipe", f"{sx1}", f"{sy1}", f"{sx2}", f"{sy2}")
    emit(cfg, True, "swipe", from_=[sx1, sy1], to=[sx2, sy2])
    return 0


def cmd_type(cfg: Config, text: str) -> int:
    idb(cfg, "ui", "text", text)
    emit(cfg, True, "type", text=text)
    return 0


def load_flow(name: str) -> dict[str, Any]:
    path = FLOWS_DIR / f"{name}.json"
    if not path.is_file():
        raise CadenceSimError(f"Flow not found: {path}")
    return json.loads(path.read_text())


def run_step(cfg: Config, step: dict[str, Any]) -> None:
    action = step["action"]
    in_session = bool(step.get("in_session", False))
    if action == "boot":
        cmd_boot(cfg)
    elif action == "build":
        cmd_build(cfg)
    elif action == "install":
        cmd_install(cfg)
    elif action == "launch":
        cmd_launch(cfg, step.get("args"))
    elif action == "terminate":
        cmd_terminate(cfg)
    elif action == "wait":
        cmd_wait(cfg, float(step.get("seconds", 1)))
    elif action == "navigate":
        cmd_navigate(cfg, step["target"], step["value"], in_session=in_session)
    elif action == "open-url":
        cmd_open_url(cfg, step["url"])
    elif action == "screenshot":
        cmd_screenshot(cfg, name=step.get("name"), out=step.get("out"))
    elif action == "tap-label":
        cmd_tap_label(cfg, step["label"], step.get("match_key", "AXLabel"))
    elif action == "tap":
        cmd_tap(cfg, float(step["x"]), float(step["y"]))
    elif action == "swipe":
        cmd_swipe(cfg, float(step["x1"]), float(step["y1"]), float(step["x2"]), float(step["y2"]))
    elif action == "type":
        cmd_type(cfg, step["text"])
    elif action == "ui-appearance":
        cmd_ui_appearance(cfg, step["mode"])
    elif action == "describe":
        cmd_describe(cfg, step.get("query"))
    else:
        raise CadenceSimError(f"Unknown flow action: {action}")


def cmd_run_flow(cfg: Config, name: str) -> int:
    flow = load_flow(name)
    steps = flow.get("steps", [])
    emit(cfg, True, "run", flow=name, steps=len(steps))
    for index, step in enumerate(steps):
        if not cfg.json_output:
            print(f"cadence_sim run {name}: step {index + 1}/{len(steps)} {step.get('action')}")
        run_step(cfg, step)
    if flow.get("restore_dark", True):
        cmd_ui_appearance(cfg, "dark")
    emit(cfg, True, "run-complete", flow=name, shots=cfg.shot_dir)
    return 0


def cmd_spot_check(cfg: Config) -> int:
    return cmd_run_flow(cfg, "spot_check")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Cadence iOS Simulator automation")
    parser.add_argument("--json", action="store_true", help="Emit JSON for agents")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("doctor", help="Check simctl, idb, app bundle")
    sub.add_parser("build", help="xcodebuild MealPlannerApp for simulator")
    sub.add_parser("boot", help="Boot simulator and open Simulator.app")
    sub.add_parser("install", help="Install .app on simulator")
    sub.add_parser("terminate", help="Terminate Cadence")

    launch = sub.add_parser("launch", help="Launch Cadence")
    launch.add_argument("args", nargs="*", help="Extra launch arguments")

    nav = sub.add_parser("navigate", help="Navigate tabs/sheets (relaunch or in-session tap)")
    nav.add_argument("target", choices=["tab", "wheel", "open", "close"])
    nav.add_argument("value", help="tab/wheel name/index or open/close target")
    nav.add_argument(
        "--in-session",
        action="store_true",
        help="Tap tab bar / drawer instead of relaunching (keeps state)",
    )

    url = sub.add_parser("open-url", help="Open arbitrary URL on simulator")
    url.add_argument("url")

    wait = sub.add_parser("wait", help="Sleep")
    wait.add_argument("seconds", type=float)

    shot = sub.add_parser("screenshot", help="Capture PNG")
    shot.add_argument("--name", help="Filename stem in shot dir")
    shot.add_argument("--out", help="Absolute output path")

    desc = sub.add_parser("describe", help="Accessibility tree (requires idb)")
    desc.add_argument("--query", help="Filter labels/identifiers")

    tap = sub.add_parser("tap", help="Tap coordinates in device points")
    tap.add_argument("x", type=float)
    tap.add_argument("y", type=float)

    tap_label = sub.add_parser("tap-label", help="Tap element by accessibility label")
    tap_label.add_argument("label")
    tap_label.add_argument("--match-key", default="AXLabel")

    swipe = sub.add_parser("swipe", help="Swipe between coordinates")
    swipe.add_argument("x1", type=float)
    swipe.add_argument("y1", type=float)
    swipe.add_argument("x2", type=float)
    swipe.add_argument("y2", type=float)

    typ = sub.add_parser("type", help="Type text into focused field")
    typ.add_argument("text")

    ui = sub.add_parser("ui-appearance", help="Set light/dark appearance")
    ui.add_argument("mode", choices=["light", "dark"])

    run = sub.add_parser("run", help="Run a JSON flow from scripts/cadence_sim_flows/")
    run.add_argument("name")

    sub.add_parser("spot-check", help="Preset: all tabs + settings + search screenshots")

    return parser


def main(argv: list[str] | None = None) -> int:
    argv = list(argv or sys.argv[1:])
    json_flag = False
    if "--json" in argv:
        json_flag = True
        argv = [a for a in argv if a != "--json"]
    parser = build_parser()
    args = parser.parse_args(argv)
    cfg = Config.from_env(json_output=json_flag)

    try:
        if args.command == "doctor":
            return cmd_doctor(cfg)
        if args.command == "build":
            return cmd_build(cfg)
        if args.command == "boot":
            return cmd_boot(cfg)
        if args.command == "install":
            return cmd_install(cfg)
        if args.command == "launch":
            return cmd_launch(cfg, args.args or None)
        if args.command == "terminate":
            return cmd_terminate(cfg)
        if args.command == "open-url":
            return cmd_open_url(cfg, args.url)
        if args.command == "navigate":
            return cmd_navigate(cfg, args.target, args.value, in_session=args.in_session)
        if args.command == "wait":
            return cmd_wait(cfg, args.seconds)
        if args.command == "screenshot":
            return cmd_screenshot(cfg, name=args.name, out=args.out)
        if args.command == "describe":
            return cmd_describe(cfg, query=args.query)
        if args.command == "tap":
            return cmd_tap(cfg, args.x, args.y)
        if args.command == "tap-label":
            return cmd_tap_label(cfg, args.label, args.match_key)
        if args.command == "swipe":
            return cmd_swipe(cfg, args.x1, args.y1, args.x2, args.y2)
        if args.command == "type":
            return cmd_type(cfg, args.text)
        if args.command == "ui-appearance":
            return cmd_ui_appearance(cfg, args.mode)
        if args.command == "run":
            return cmd_run_flow(cfg, args.name)
        if args.command == "spot-check":
            return cmd_spot_check(cfg)
        parser.error(f"Unknown command: {args.command}")
        return 2
    except CadenceSimError as exc:
        emit(cfg, False, args.command, error=str(exc))
        return 1
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout or str(exc)).strip()
        emit(cfg, False, args.command, error=detail)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
