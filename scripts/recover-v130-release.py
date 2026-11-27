"""One-time release recovery for the explicitly approved mixed-build v1.3.0."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

REPO = os.environ.get("GITHUB_REPOSITORY", "genyleap/genydl")
TAG = "v1.3.0"
BASE = "12097d83988e128a903171cb0e28fc664d95f5ee"
FIXED = "2c146a2365369f66b633104ec2e4483656cfa288"
OUT = Path("release-artifacts")
RECOVERY = Path("recovery")
SAVED = [
    ("macos-x86_64", 45960169849, 15181650257, BASE, "macos-x86_64", {".dmg"}),
    ("linux-x86_64", 45960169849, 15180497495, BASE, "linux-x86_64", {".AppImage"}),
    ("windows-x64", 45960169849, 15180428716, BASE, "windows-x86_64", {".exe", ".zip"}),
    ("linux-arm64", 45960169849, 15180353788, BASE, "linux-arm64", {".AppImage"}),
    ("windows-arm64", 45961713430, 15181114926, FIXED, "windows-arm64", {".exe", ".zip"}),
]

def gh(*args):
    return subprocess.check_output(["gh", *args], text=True)

def api(path):
    return json.loads(gh("api", path))

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def download_and_collect():
    require(REPO == "genyleap/genydl", "Wrong repository")
    tag = api(f"repos/{REPO}/git/ref/tags/{TAG}")["object"]
    if tag["type"] == "tag":
        tag = api(f"repos/{REPO}/git/tags/{tag['sha']}")["object"]
    require(tag["sha"] == BASE, "Original release tag changed")
    current_run = int(os.environ["GITHUB_RUN_ID"])
    current_sha = os.environ["GITHUB_SHA"]
    records = SAVED + [
        ("macos-arm64", current_run, None, current_sha, "macos-arm64", {".dmg"})
    ]
    OUT.mkdir(exist_ok=True)
    manifest = []
    for name, run, artifact_id, sha, platform, suffixes in records:
        meta = api(f"repos/{REPO}/actions/runs/{run}")
        require(meta["head_sha"] == sha, f"{name}: wrong source commit")
        artifacts = api(f"repos/{REPO}/actions/runs/{run}/artifacts?per_page=100")["artifacts"]
        candidates = [a for a in artifacts if a["name"] == "GenyDL-" + name and not a["expired"]]
        require(len(candidates) == 1, f"{name}: missing or ambiguous artifact")
        artifact = candidates[0]
        require(artifact_id is None or artifact["id"] == artifact_id, f"{name}: artifact changed")
        jobs = api(f"repos/{REPO}/actions/runs/{run}/jobs?per_page=100")["jobs"]
        matching = [j for j in jobs if j["name"] == "Build GenyDL-" + name]
        require(len(matching) == 1 and matching[0]["conclusion"] == "success", f"{name}: build not successful")
        folder = RECOVERY / ("GenyDL-" + name)
        if artifact_id is not None:
            subprocess.run(["gh", "run", "download", str(run), "--repo", REPO,
                            "--name", "GenyDL-" + name, "--dir", str(folder)], check=True)
        files = sorted(folder.iterdir())
        packages = [p for p in files if p.suffix in suffixes]
        require({p.suffix for p in packages} == suffixes and len(packages) == len(suffixes),
                f"{name}: incomplete or duplicate package types: {files}")
        for p in packages:
            # Windows x64 package filenames may spell the architecture x64 or x86_64.
            expected = {"GenyDL-1.3.0-" + platform + p.suffix}
            if name == "windows-x64":
                expected.add("GenyDL-1.3.0-windows-x64" + p.suffix)
            require(p.name in expected and p.is_file() and not p.is_symlink() and p.stat().st_size > 0,
                    f"Unexpected package: {p}")
            checksum = digest(p)
            if p.suffix == ".AppImage":
                original = p.with_name(p.name + ".sha256")
                require(original.is_file() and original.read_text().split()[0].lower() == checksum,
                        f"{name}: original checksum mismatch")
            dest = OUT / p.name
            require(not dest.exists(), f"Duplicate output: {p.name}")
            p.rename(dest)
            # Keep the existing updater-compatible sidecar naming.
            (OUT / (dest.name + ".sha256")).write_text(f"{checksum}  {dest.name}\n")
            manifest.append({"file": dest.name, "sha256": checksum, "size": dest.stat().st_size,
                             "platform": name, "source_commit": sha, "run_id": run,
                             "artifact_id": artifact["id"]})
    require(len(manifest) == 8, "Expected eight installers/archives across six platforms")
    (OUT / "BUILD-PROVENANCE.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (OUT / "SHA256SUMS").write_text("".join(f"{m['sha256']}  {m['file']}\n" for m in manifest))
    notes = Path("release-notes/v1.3.0.md").read_text()
    notes = notes.replace("once the release build completes", "below")
    notes += "\n## Package build provenance\n\n"
    notes += ("To preserve successful builds, this release reuses the four validated packages "
              "from the original v1.3.0 source tag and uses the LanguageManager compiler workaround "
              "for Windows ARM64 and Apple Silicon. These packages do not all share one source commit. "
              "The tag remains unchanged. SHA-256 checksums and exact source commits are supplied in "
              "BUILD-PROVENANCE.json and SHA256SUMS.\n\n")
    notes += "| Platform | Source commit | Build |\n| --- | --- | --- |\n"
    for name, run, _, sha, _, _ in records:
        notes += f"| {name} | [{sha[:7]}](https://github.com/{REPO}/commit/{sha}) | [Actions run](https://github.com/{REPO}/actions/runs/{run}) |\n"
    notes += "\nmacOS DMGs are ad-hoc signed, not Developer ID notarized.\n"
    Path("recovery-notes.md").write_text(notes)
    print(f"Verified {len(manifest)} packages across six platforms.")

def upload():
    release = json.loads(gh("release", "view", TAG, "--repo", REPO, "--json", "tagName,isDraft,assets"))
    require(release["tagName"] == TAG and release["isDraft"], "Expected an unpublished draft")
    expected = {p.name: p for p in OUT.iterdir() if p.is_file()}
    for a in release["assets"]:
        p = expected.pop(a["name"], None)
        require(p is not None and a["size"] == p.stat().st_size
                and a.get("digest") == "sha256:" + digest(p),
                f"Existing draft asset differs: {a['name']}")
    subprocess.run(["gh", "release", "edit", TAG, "--repo", REPO, "--title", "GenyDL v1.3.0",
                    "--notes-file", "recovery-notes.md"], check=True)
    if expected:
        subprocess.run(["gh", "release", "upload", TAG, "--repo", REPO,
                        *[str(p) for p in expected.values()]], check=True)
    release = json.loads(gh("release", "view", TAG, "--repo", REPO, "--json", "tagName,isDraft,assets"))
    actual = {a["name"]: a for a in release["assets"]}
    expected = {p.name: p for p in OUT.iterdir() if p.is_file()}
    require(release["isDraft"] and actual.keys() == expected.keys(), "Incomplete upload")
    for name, path in expected.items():
        require(actual[name]["size"] == path.stat().st_size, f"Uploaded size differs: {name}")
        # API digest availability depends on GitHub; if supplied, verify it.
        if actual[name].get("digest"):
            require(actual[name]["digest"] == "sha256:" + digest(path), f"Uploaded digest differs: {name}")
    print(f"Verified draft contains all {len(expected)} files.")

if __name__ == "__main__":
    if sys.argv[1:] == ["--upload"]:
        upload()
    else:
        require(not sys.argv[1:], "Unexpected arguments")
        download_and_collect()
