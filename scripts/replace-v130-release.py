"""One-time replacement of v1.3.0 after all six native builds succeed."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

REPO = "genyleap/genydl"
TAG = "v1.3.0"
OLD_TAG = "cf50936016923d3f1cc55632980bce65edcbb4e8"
OLD_RELEASE = 460322979
RUN = int(os.environ["GITHUB_RUN_ID"])
SHA = os.environ["GITHUB_SHA"]
OUT = Path("release-artifacts")
SPECS = {
    "windows-x64": ("windows-x86_64", ("exe", "zip")),
    "windows-arm64": ("windows-arm64", ("exe", "zip")),
    "macos-arm64": ("macos-arm64", ("dmg",)),
    "macos-x86_64": ("macos-x86_64", ("dmg",)),
    "linux-x86_64": ("linux-x86_64", ("AppImage",)),
    "linux-arm64": ("linux-arm64", ("AppImage",)),
}

def require(ok, message):
    if not ok:
        raise RuntimeError(message)

def gh(*args):
    return subprocess.check_output(["gh", *args], text=True)

def api(path, *args):
    return json.loads(gh("api", path, *args))

def digest(path):
    with path.open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()

require(os.environ["GITHUB_REPOSITORY"] == REPO, "Wrong repository")
meta = api(f"repos/{REPO}/actions/runs/{RUN}")
require(meta["head_sha"] == SHA, "Unexpected source commit")
jobs = api(f"repos/{REPO}/actions/runs/{RUN}/jobs?per_page=100")["jobs"]
artifacts = api(f"repos/{REPO}/actions/runs/{RUN}/artifacts?per_page=100")["artifacts"]
OUT.mkdir()
manifest = []
for target, (platform, extensions) in SPECS.items():
    name = "GenyDL-" + target
    matching_jobs = [j for j in jobs if j["name"] == "Build " + name]
    require(len(matching_jobs) == 1 and matching_jobs[0]["conclusion"] == "success", f"{target}: unsuccessful build")
    matches = [a for a in artifacts if a["name"] == name and not a["expired"]]
    require(len(matches) == 1, f"{target}: missing artifact")
    folder = Path("replacement-artifacts") / name
    require(folder.is_dir(), f"Missing folder: {folder}")
    for ext in extensions:
        filename = f"GenyDL-1.3.0-{platform}.{ext}"
        candidates = [folder / filename]
        if target == "windows-x64":
            candidates.append(folder / f"GenyDL-1.3.0-windows-x64.{ext}")
        candidates = [p for p in candidates if p.is_file() and not p.is_symlink()]
        require(len(candidates) == 1, f"{target}: missing/ambiguous {ext}")
        source = candidates[0]
        require(source.stat().st_size > 0, f"Empty {source}")
        sha256 = digest(source)
        if ext == "AppImage":
            sidecar = source.with_name(source.name + ".sha256")
            require(sidecar.is_file() and sidecar.read_text().split()[0].lower() == sha256, f"Invalid Linux checksum: {source}")
        dest = OUT / filename
        shutil.copyfile(source, dest)
        (OUT / (filename + ".sha256")).write_text(f"{sha256}  {filename}\n")
        manifest.append({"file": filename, "sha256": sha256, "size": dest.stat().st_size,
                         "platform": target, "source_commit": SHA, "run_id": RUN, "artifact_id": matches[0]["id"]})
require(len(manifest) == 8, "Expected eight packages")
(OUT / "BUILD-PROVENANCE.json").write_text(json.dumps(manifest, indent=2) + "\n")
(OUT / "SHA256SUMS").write_text("".join(f"{x['sha256']}  {x['file']}\n" for x in manifest))
expected = {p.name: p for p in OUT.iterdir()}
require(len(expected) == 18, "Expected 18 release assets")
notes = Path("release-notes/v1.3.0.md").read_text().replace("once the release build completes", "below")
notes += f"\n## Replacement build provenance\n\nAll six targets were built from [{SHA[:12]}](https://github.com/{REPO}/commit/{SHA}) in [Actions run {RUN}](https://github.com/{REPO}/actions/runs/{RUN}). macOS packages are ad-hoc signed, not Developer ID notarized.\n"
Path("replacement-notes.md").write_text(notes)
ref = api(f"repos/{REPO}/git/ref/tags/{TAG}")["object"]
require(ref["sha"] == OLD_TAG, "Original tag changed; refuse replacement")
old = api(f"repos/{REPO}/releases/tags/{TAG}")
require(old["id"] == OLD_RELEASE and not old["draft"], "Original release changed; refuse replacement")
# Preserve the verified old release until every new package is ready.
# Move the annotated tag to the corrected commit without retriggering CI.
tag = api(f"repos/{REPO}/git/tags", "--method", "POST", "-f", f"tag={TAG}",
          "-f", "message=GenyDL v1.3.0 corrected updater release", "-f", f"object={SHA}", "-f", "type=commit")
api(f"repos/{REPO}/git/refs/tags/{TAG}", "--method", "PATCH", "-f", f"sha={tag['sha']}", "-F", "force=true")
gh("release", "delete", TAG, "--repo", REPO, "--cleanup-tag=false", "--yes")
gh("release", "create", TAG, "--repo", REPO, "--verify-tag", "--draft", "--title", "GenyDL v1.3.0",
   "--notes-file", "replacement-notes.md")
gh("release", "upload", TAG, "--repo", REPO, *[str(p) for p in expected.values()])
release = json.loads(gh("release", "view", TAG, "--repo", REPO, "--json", "isDraft,assets"))
actual = {a["name"]: a for a in release["assets"]}
require(release["isDraft"] and actual.keys() == expected.keys(), "Incomplete draft")
for name, path in expected.items():
    require(actual[name]["size"] == path.stat().st_size, f"Size mismatch {name}")
    require(actual[name].get("digest") == "sha256:" + digest(path), f"Digest mismatch {name}")
gh("release", "edit", TAG, "--repo", REPO, "--draft=false", "--latest")
published = api(f"repos/{REPO}/releases/latest")
require(published["tag_name"] == TAG and not published["draft"] and len(published["assets"]) == 18, "Publication check failed")
print(f"Published {TAG}: 18 files from {SHA}")
