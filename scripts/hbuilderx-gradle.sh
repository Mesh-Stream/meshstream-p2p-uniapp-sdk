#!/usr/bin/env bash
set -euo pipefail
# HBuilderX 5.33 generates settings repositories that hide plugin project.repositories.
# Restrict this workaround to HBuilderX temporary dependency-resolution projects.
if [[ "$PWD" == */.uts-development-android/gradle/* && -f settings.gradle ]]; then
  python3 - <<'PYTHON'
from pathlib import Path
p = Path("settings.gradle")
s = p.read_text()
p.write_text(s.replace("RepositoriesMode.PREFER_SETTINGS", "RepositoriesMode.PREFER_PROJECT"))
PYTHON
fi
exec "${MESHSTREAM_GRADLE_EXECUTABLE:-gradle}" "$@"
