# Upgrading Lean and its dependencies

Lean, Mathlib, and Comparator must be upgraded as one compatible set. In this
repository, “comparator” is the
[`leanprover/comparator`](https://github.com/leanprover/comparator) project. It
builds the `comparator` executable and pins the compatible `lean4export`
dependency in its own `lake-manifest.json`; do not choose a separate
`lean4export` revision here.

## Resolve the revisions

Set the target release and inspect the upstream release tags in temporary
clones. Resolving tags to commits keeps this image reproducible even if the tag
names are used while investigating.

```sh
VERSION=4.34.0
TAG="v${VERSION}"
UPGRADE_DIR=$(mktemp -d)

git clone --filter=blob:none --no-checkout \
  https://github.com/leanprover-community/mathlib4.git \
  "${UPGRADE_DIR}/mathlib4"
git clone --filter=blob:none --no-checkout \
  https://github.com/leanprover/comparator.git \
  "${UPGRADE_DIR}/comparator"

git -C "${UPGRADE_DIR}/mathlib4" rev-parse "${TAG}^{commit}"
git -C "${UPGRADE_DIR}/mathlib4" show "${TAG}:lean-toolchain"
git -C "${UPGRADE_DIR}/comparator" rev-parse "${TAG}^{commit}"
git -C "${UPGRADE_DIR}/comparator" show "${TAG}:lean-toolchain"
```

Both `lean-toolchain` outputs must be `leanprover/lean4:v${VERSION}`. If either
project has not published that tag, stop and wait for a compatible release
instead of mixing versions or selecting an arbitrary commit.

## Update every version surface

Use the full commits printed above for dependency pins, then update:

- `Dockerfile`: `LEAN_VERSION` and `COMPARATOR_REV`.
- `lakefile.toml`: Mathlib's `rev`.
- `.github/workflows/publish.yml`: the versioned image tag, including the
  seven-character Comparator commit suffix.
- `README.md`: the displayed Lean version and pull tag. Remove any immutable
  digest for the previous image; add the new digest only after publication.

Search the tracked files for a stale version, tag, or revision before building:

```sh
git grep -nE 'lean4\.|mathlib4\.|rev = "[0-9a-f]{40}"|COMPARATOR_REV|comparator-[0-9a-f]+'
git diff --check
```

Compare every reported version and revision with the Lean version, Mathlib
commit, and Comparator commit resolved above; no value from the previous
release should remain.

The Ubuntu base digest and `LANDRUN_SHA256_AMD64` pin different artifacts. Audit
them during an upgrade, but change a checksum only when changing its associated
image or release. For a Landrun bump, download the exact architecture-specific
asset and verify its digest with `sha256sum` before editing both `LANDRUN_TAG`
and `LANDRUN_SHA256_AMD64`.

## Validate and publish

Build the same platform used by CI and smoke-test the installed toolchain:

```sh
docker buildx build --platform linux/amd64 --load \
  -t ubuntu-lean-mathlib:test .

docker run --rm ubuntu-lean-mathlib:test sh -ec '
  lean --version
  lake --version
  test -x /usr/local/bin/comparator
  test -x /usr/local/bin/lean4export
  test -x /usr/local/bin/fake-landrun
  printf "import Mathlib\n#check Nat\n" > /tmp/Smoke.lean
  cd /workspace
  lake env lean /tmp/Smoke.lean
  python3 -c "import pytest, pytest_json_ctrf"
'
```

After the changes reach `main`, the publish workflow pushes the versioned tag
and `latest`. Record the registry digest shown by
`docker buildx imagetools inspect ghcr.io/zhihan/ubuntu-lean-mathlib:<tag>` in
the README as the new immutable reference.
