# CI budget and build selection

Native CI uses fresh GitHub-hosted runners. Do not start all six native jobs after every small change.

## During development

The lightweight browser smoke workflow runs on relevant PR changes (and relevant pushes to main/master); native CI does **not** run automatically on PR synchronization.

To test a native target, create/apply the corresponding label to the pull request. The **labeled** event selects exactly one target, except `ci:all`.

| PR label | Native build |
| --- | --- |
| `ci:windows-x64` | Windows x64 |
| `ci:windows-arm64` | Windows ARM64 |
| `ci:macos-arm64` | Apple Silicon |
| `ci:macos-x86_64` | Intel macOS |
| `ci:linux-x64` | Linux x64 |
| `ci:linux-arm64` | Linux ARM64 |
| `ci:all` | All six |

Remove and reapply a label to run a fresh check after a new commit. A successful job for an older commit is not evidence that a newer commit passed. For a transient failure on the **same commit**, use GitHub's **Re-run failed jobs** or re-run the specific job instead.

Once the workflow definition is present on the default branch, Actions → GenyDL CI → Run workflow also accepts a target selector. Do not use `all` unless a full validation is needed. A draft PR can use the label mechanism without merging the workflow to main.

## Build caching

- Windows/macOS retain the Qt installer action's SDK cache. Linux caches its exact Qt version and architecture independently and saves the SDK immediately after installation, before compilation/packaging.
- Clang builds on Linux/macOS use sccache with a bounded 256 MiB local cache, restored by OS/architecture/Qt version and saved after compilation even if packaging subsequently fails. A previous cache may seed a new commit. The compiler cache hashes the actual inputs; unsupported C++20 module operations bypass the cache. It does not restore entire potentially incompatible CMake/Ninja build trees or BMI files blindly.
- MSVC/Visual Studio named modules are not reliably supported by sccache; Windows native builds still compile on a fresh runner. Use targeted jobs or a trusted persistent runner for genuine Windows incremental builds.
- Caches are best-effort and scoped by GitHub's cache rules; eviction, changes in compiler/SDK or cache misses can still require recompilation. Do not treat a cache hit as a passing test. Cancelled jobs may not save a cache.
- The first cache-enabled build must populate the cache. No cache hit ratio or time reduction is asserted before measuring it.

## Release gate

Pushes to main/master and version tags retain the full six-platform native matrix. Only a pushed version tag can publish a release, and it requires all native build jobs to succeed. Selecting a partial build on a PR never publishes a release. Complete `ci:all` validation on the final candidate before merging; targeted checks are for economical iteration, not a substitute for the final release gate.
