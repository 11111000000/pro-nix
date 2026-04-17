set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
need curl
need nix-prefetch-url

# GitHub API can be rate-limited without token.
# If you hit rate limits: export GITHUB_TOKEN=... (classic token with public read is enough).
AUTH=()
if [ "${GITHUB_TOKEN:-}" != "" ]; then
  AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

get_sha() {
  local repo="$1" ref="$2"
  curl -fsSL "${AUTH[@]}" "https://api.github.com/repos/${repo}/commits/${ref}" \
    | sed -n 's/^[[:space:]]*"sha":[[:space:]]*"\([0-9a-f]\{40\}\)".*/\1/p' \
    | head -n1
}

prefetch_tar_sha256() {
  local url="$1"
  # nix-prefetch-url prints hash to stdout
  nix-prefetch-url --unpack "$url" 2>/dev/null
}

echo "== Resolve refs to commit SHA =="
NIXPKGS_SHA="$(get_sha 'NixOS/nixpkgs' 'nixos-unstable')"
HM_SHA="$(get_sha 'nix-community/home-manager' 'release-23.11')"

echo "nixpkgs nixos-unstable HEAD:  $NIXPKGS_SHA"
echo "home-manager release-23.11: $HM_SHA"
echo

echo "== Prefetch tarballs and compute sha256 =="
NIXPKGS_URL="https://github.com/NixOS/nixpkgs/archive/${NIXPKGS_SHA}.tar.gz"
HM_URL="https://github.com/nix-community/home-manager/archive/${HM_SHA}.tar.gz"

echo "Prefetch nixpkgs:      $NIXPKGS_URL"
NIXPKGS_SRI="$(prefetch_tar_sha256 "$NIXPKGS_URL")"
echo "sha256 (base32): $NIXPKGS_SRI"
echo

echo "Prefetch home-manager: $HM_URL"
HM_SRI="$(prefetch_tar_sha256 "$HM_URL")"
echo "sha256 (base32): $HM_SRI"
echo

cat <<EOF
== Paste into configuration.nix ==

  home-manager = builtins.fetchTarball {
    url = "${HM_URL}";
    sha256 = "${HM_SRI}";
  };

  nixpkgs-unstable = builtins.fetchTarball {
    url = "${NIXPKGS_URL}";
    sha256 = "${NIXPKGS_SRI}";
  };

EOF
