#!/usr/bin/env bash
set -euo pipefail
# Smoke test: download the official x86_64 opencode release, extract and run --version
# Meant to be run in CI (x86_64) or locally on a compatible host.

TMPBASE=${TMPDIR:-/tmp}
[ -d "$TMPBASE" ] || TMPBASE="$HOME/.cache/tmp"
mkdir -p "$TMPBASE"

tmpdir=$(mktemp -d "${TMPBASE}/opencode-test.XXXXXX" 2>/dev/null || mktemp -d 2>/dev/null || printf "%s" "${TMPBASE}/opencode-test.$(date +%s).$$")
trap 'rm -rf "$tmpdir"' EXIT

arch=$(uname -m)
echo "Detected arch: $arch"
if [ "$arch" != "x86_64" ]; then
  echo "Skipping opencode launch test: prebuilt test uses x86_64 binary (arch=$arch)"
  exit 0
fi

tmpball="$tmpdir/opencode.tar.gz"
url="https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-x64.tar.gz"

echo "Downloading $url to $tmpball"
if command -v curl >/dev/null 2>&1; then
  curl -fSL -o "$tmpball" "$url"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$tmpball" "$url"
else
  echo "Neither curl nor wget available" >&2
  exit 2
fi

echo "Extracting archive"
tar xzf "$tmpball" -C "$tmpdir"
if [ ! -x "$tmpdir/opencode" ]; then
  echo "Extracted archive does not contain executable 'opencode'" >&2
  ls -l "$tmpdir"
  exit 3
fi

echo "Running opencode --version"
set +e
"$tmpdir/opencode" --version > "$tmpdir/version.out" 2>&1
rc=$?
set -e

if [ $rc -ne 0 ]; then
  echo "opencode failed to run (exit $rc). Output:" >&2
  sed -n '1,200p' "$tmpdir/version.out" || true
  exit 4
fi

echo "opencode ran successfully. Output:"
sed -n '1,200p' "$tmpdir/version.out" || true
echo "OK"
