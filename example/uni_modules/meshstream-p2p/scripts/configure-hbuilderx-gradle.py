#!/usr/bin/env python3
"""Configure the MeshStream Gradle launcher for HBuilderX on macOS/Linux."""
import argparse
import json
import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile


SETTING = "uts-development-android.gradleHome"


def write_json(path, value, mode=0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def default_settings():
    if sys.platform == "darwin":
        return Path.home() / "Library/Application Support/HBuilder X/user/settings.json"
    return Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "HBuilder X/user/settings.json"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gradle", type=Path, help="Actual Gradle executable or Gradle Wrapper")
    parser.add_argument("--settings", type=Path, default=default_settings())
    parser.add_argument("--config", type=Path, default=Path(os.environ.get(
        "XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "meshstream/hbuilderx-gradle.json")
    parser.add_argument("--restore", action="store_true", help="Restore the previous Gradle setting")
    args = parser.parse_args()
    launcher = Path(__file__).resolve().with_name("hbuilderx-gradle.sh")
    settings_file, config_file = args.settings.expanduser().resolve(), args.config.expanduser().resolve()
    if settings_file == config_file:
        parser.error("Settings and launcher configuration must be different files")
    if not settings_file.is_file():
        parser.error("HBuilderX settings file not found; configure Android tools in HBuilderX first or use --settings")
    try:
        settings = json.loads(settings_file.read_text(encoding="utf-8-sig"))
        saved = json.loads(config_file.read_text()) if config_file.exists() else None
    except (ValueError, OSError) as error:
        parser.error(f"Cannot read existing configuration: {error}")
    if not isinstance(settings, dict) or (saved is not None and not isinstance(saved, dict)):
        parser.error("Expected JSON objects; existing configuration was not changed")
    if saved and saved.get("settingsFile") != str(settings_file):
        parser.error("Configuration belongs to another settings file; use a separate --config")
    settings_mode = stat.S_IMODE(settings_file.stat().st_mode)
    if args.restore:
        if not saved:
            parser.error("No saved configuration to restore")
        if settings.get(SETTING) != saved.get("launcher"):
            parser.error("Gradle setting has changed since setup; refusing to overwrite it")
        if saved["previousGradlePresent"]:
            settings[SETTING] = saved["previousGradle"]
        else:
            settings.pop(SETTING, None)
        write_json(settings_file, settings, settings_mode)
        config_file.unlink()
        print("Previous HBuilderX Gradle setting restored.")
        return
    candidate = args.gradle
    if candidate is None:
        current = settings.get(SETTING)
        if saved and current == saved.get("launcher"):
            candidate = Path(saved["gradleExecutable"])
        elif current and Path(current).expanduser().resolve() != launcher:
            candidate = Path(current)
        elif saved:
            candidate = Path(saved["gradleExecutable"])
        else:
            found = shutil.which("gradle")
            candidate = Path(found) if found else None
    if candidate is None:
        parser.error("No Gradle executable found; pass --gradle /path/to/gradle or /path/to/gradlew")
    executable = candidate.expanduser().resolve()
    if executable == launcher or not executable.is_file() or not os.access(executable, os.X_OK):
        parser.error("--gradle must name a different executable file")
    current = settings.get(SETTING)
    if saved and current == saved.get("launcher"):
        record = dict(saved)
    else:
        record = {"settingsFile": str(settings_file), "launcher": str(launcher),
                  "previousGradlePresent": SETTING in settings, "previousGradle": current}
    record["gradleExecutable"] = str(executable)
    record["launcher"] = str(launcher)
    launcher.chmod(launcher.stat().st_mode | stat.S_IXUSR)
    # The launcher reads this file directly; a GUI launch need not inherit shell exports.
    write_json(config_file, record)
    settings[SETTING] = str(launcher)
    write_json(settings_file, settings, settings_mode)
    print("HBuilderX Gradle launcher configured. Reopen Run if an existing build is active.")


if __name__ == "__main__":
    main()
