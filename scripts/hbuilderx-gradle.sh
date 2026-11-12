#!/usr/bin/env bash
set -euo pipefail
# HBuilderX 5.33/5.34 settings repositories hide plugin project.repositories.
# Restrict this workaround to HBuilderX temporary dependency-resolution projects.
if [[ "$PWD" == */.uts-development-android/gradle/* && -f settings.gradle ]]; then
  python3 - <<'PYTHON'
from pathlib import Path
p = Path("settings.gradle")
s = p.read_text()
p.write_text(s.replace("RepositoriesMode.PREFER_SETTINGS", "RepositoriesMode.PREFER_PROJECT"))
PYTHON
fi
gradle_executable="${MESHSTREAM_GRADLE_EXECUTABLE:-}"
gradle_config="${MESHSTREAM_HBUILDERX_GRADLE_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/meshstream/hbuilderx-gradle.json}"
if [[ -z "$gradle_executable" && -f "$gradle_config" ]]; then
  gradle_executable="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["gradleExecutable"])' "$gradle_config")"
fi
gradle_executable="${gradle_executable:-gradle}"
if [[ "$gradle_executable" -ef "${BASH_SOURCE[0]}" ]]; then
  echo "The Gradle executable must not point to this launcher." >&2
  exit 1
fi
exec "$gradle_executable" "$@"
