#!/usr/bin/env python3
"""Create a clean HBuilderX project for official uni_modules dry-run packaging."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True,
                        help="New staging directory; existing paths are never overwritten")
    parser.add_argument("--zip", type=Path,
                        help="Optional new plugin-only ZIP with deterministic metadata")
    args = parser.parse_args()
    source = Path(__file__).resolve().parent.parent
    target = args.project.resolve()
    if target.exists():
        parser.error("Staging directory already exists; use a new path")
    if args.zip and (args.zip.exists() or Path(str(args.zip) + ".sha256").exists()):
        parser.error("Artifact already exists; use a new path")
    manifest = json.loads((source / "package.json").read_text())
    version = manifest["version"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        parser.error("Expected an explicit semantic release version")
    if manifest["id"] != "meshstream-p2p":
        parser.error("Unexpected plugin ID")
    android = json.loads((source / "utssdk/app-android/config.json").read_text())
    ios = json.loads((source / "utssdk/app-ios/config.json").read_text())
    release = json.loads((source / f"releases/{version}.json").read_text())
    native = release["nativeDependencies"]
    assert android["dependencies"] == [
        f'{native["android"]["maven"]}:{native["android"]["version"]}'
    ], "Android dependency does not match release record"
    assert ios["dependencies-pods"] == [
        {"name": native["ios"]["pod"], "version": native["ios"]["version"]}
    ], "iOS dependency does not match release record"

    files = {
        "package.json": "package.json",
        "README.md": "readme.md",
        "README.zh-CN.md": "README.zh-CN.md",
        "CHANGELOG.md": "changelog.md",
        "LICENSE.md": "LICENSE.md",
        "scripts/hbuilderx-gradle.sh": "scripts/hbuilderx-gradle.sh",
        "javascript.js": "javascript.js",
        "javascript-bridge.js": "javascript-bridge.js",
    }
    allowed = {".uts", ".kt", ".swift", ".json", ".xml", ".plist"}
    for item in sorted((source / "utssdk").rglob("*")):
        if item.is_file():
            relative = item.relative_to(source).as_posix()
            assert item.suffix in allowed, f"Unexpected native file: {relative}"
            assert not item.is_symlink(), f"Symlinks are not allowed: {relative}"
            files[relative] = relative
    # Only UTS bridge source is shipped. Native implementations remain public dependencies.
    for name in files:
        text = (source / name).read_text()
        assert not re.search(r"key_[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{20,}", text), \
            f"Possible credential in {name}"
        assert "/Users/" not in text, f"Local machine path in {name}"

    plugin = target / "uni_modules/meshstream-p2p"
    for src, dst in files.items():
        output = plugin / dst
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / src, output)
    for name in ["App.vue", "main.js", "manifest.json", "pages.json", "pages/index/index.vue"]:
        output = target / name
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / "example" / name, output)
    result = {"project": str(target), "pluginId": manifest["id"],
              "version": version, "pluginFiles": len(files)}
    if args.zip:
        artifact = args.zip.resolve()
        artifact.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(artifact, "x", compression=zipfile.ZIP_DEFLATED) as archive:
            for name in sorted(files.values()):
                entry = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                entry.create_system = 3
                entry.compress_type = zipfile.ZIP_DEFLATED
                entry.external_attr = (0o100755 if name.endswith(".sh") else 0o100644) << 16
                archive.writestr(entry, (plugin / name).read_bytes())
        digest = hashlib.sha256(artifact.read_bytes()).hexdigest()
        Path(str(artifact) + ".sha256").write_text(digest + "  " + artifact.name + "\n")
        result.update({"archive": str(artifact), "sha256": digest,
                       "bytes": artifact.stat().st_size})
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
