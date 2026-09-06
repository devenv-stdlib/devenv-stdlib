#!/usr/bin/env bash
# Shared helpers for includes/update/*.sh. Source only.
# Network uses curl; hashes use nix-prefetch-url. Mock PATH or set
# UPDATE_DRY_RUN=1 so BATS never hits live registries.

update_repo_root() {
  local root=${UPDATE_ROOT:-${DEVENV_ROOT:-}}
  if [[ -z $root ]]; then
    echo "update: set DEVENV_ROOT or UPDATE_ROOT" >&2
    return 1
  fi
  printf '%s\n' "$root"
}

update_dry_run() {
  [[ ${UPDATE_DRY_RUN:-} == 1 ]]
}

http_get() {
  local extra=()
  if [[ -n ${GITHUB_TOKEN:-${GH_TOKEN:-}} && "$*" == *api.github.com* ]]; then
    extra+=(-H "Authorization: Bearer ${GITHUB_TOKEN:-$GH_TOKEN}")
  fi
  curl -fsSL -A "devenv4monorepo-update" "${extra[@]}" "$@"
}

github_latest_tag() {
  local owner=$1 repo=$2
  http_get "https://api.github.com/repos/${owner}/${repo}/releases/latest" \
    | jq -er '.tag_name'
}

github_latest_version() {
  local tag
  tag=$(github_latest_tag "$1" "$2")
  printf '%s\n' "${tag#v}"
}

npm_registry_path() {
  local pkg=$1
  if [[ $pkg == @*/* ]]; then
    printf '%s%%2f%s\n' "${pkg%%/*}" "${pkg#*/}"
  else
    printf '%s\n' "$pkg"
  fi
}

npm_latest() {
  local pkg=$1 path
  path=$(npm_registry_path "$pkg")
  http_get "https://registry.npmjs.org/${path}/latest" | jq -er '.version'
}

pypi_latest() {
  local pkg=$1
  http_get "https://pypi.org/pypi/${pkg}/json" | jq -er '.info.version'
}

docker_hub_tag_names() {
  local image=$1
  local url="https://hub.docker.com/v2/repositories/${image}/tags?page_size=100"
  local json
  while [[ -n $url && $url != null ]]; do
    json=$(http_get "$url")
    jq -er '.results[].name' <<<"$json"
    url=$(jq -r '.next // empty' <<<"$json")
  done
}

docker_hub_latest_semver() {
  local image=$1
  docker_hub_tag_names "$image" | python3 -c '
import re, sys
pat = re.compile(r"^\d+(?:\.\d+)*$")
vers = [line.strip() for line in sys.stdin if pat.match(line.strip())]
if not vers:
    raise SystemExit("docker_hub_latest_semver: no semver tags")
print(max(vers, key=lambda v: tuple(int(p) for p in v.split("."))))
'
}

docker_hub_tag_digest() {
  local image=$1 tag=$2
  http_get "https://hub.docker.com/v2/repositories/${image}/tags/${tag}" \
    | jq -er '.digest'
}

vs_marketplace_latest() {
  local publisher=$1 name=$2
  local body
  body=$(jq -n --arg id "${publisher}.${name}" '{
    filters: [{
      criteria: [{filterType: 7, value: $id}],
      pageNumber: 1,
      pageSize: 1
    }],
    flags: 914
  }')
  curl -fsSL -A "devenv4monorepo-update" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json;api-version=7.1-preview.1" \
    -d "$body" \
    "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery?api-version=7.1-preview.1" \
    | jq -er '.results[0].extensions[0].versions[0].version'
}

vs_marketplace_vsix_url() {
  local publisher=$1 name=$2 version=$3
  printf '%s\n' \
    "https://${publisher}.gallery.vsassets.io/_apis/public/gallery/publisher/${publisher}/extension/${name}/${version}/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage"
}

prefetch_url_hash() {
  local url=$1
  local fmt=${2:-nix32}
  local unpack=${3:-}
  local args=()
  local raw
  if [[ $unpack == unpack ]]; then
    args+=(--unpack)
  fi
  raw=$(nix-prefetch-url "${args[@]}" "$url")
  case $fmt in
    nix32)
      printf '%s\n' "$raw"
      ;;
    hex)
      nix hash convert --from nix32 --to base16 --hash-algo sha256 "$raw"
      ;;
    sri)
      nix hash convert --from nix32 --to sri --hash-algo sha256 "$raw"
      ;;
    *)
      echo "prefetch_url_hash: unknown format $fmt" >&2
      return 1
      ;;
  esac
}

read_nix_string_assign() {
  local file=$1 name=$2
  python3 - "$file" "$name" <<'PY'
import pathlib, re, sys

text = pathlib.Path(sys.argv[1]).read_text()
name = sys.argv[2]
match = re.search(rf'^\s*{re.escape(name)}\s*=\s*"([^"]*)"\s*;', text, re.M)
if not match:
    raise SystemExit(f"read_nix_string_assign: {name} not found in {sys.argv[1]}")
print(match.group(1))
PY
}

replace_nix_string_assign() {
  local file=$1 name=$2 value=$3
  if update_dry_run; then
    echo "dry-run: $file: $name = \"$value\""
    return 0
  fi
  python3 - "$file" "$name" "$value" <<'PY'
import pathlib, re, sys

path = pathlib.Path(sys.argv[1])
name = sys.argv[2]
value = sys.argv[3]
text = path.read_text()
pat = re.compile(rf'^(\s*{re.escape(name)}\s*=\s*")[^"]*("\s*;)', re.M)
new, count = pat.subn(rf"\g<1>{value}\2", text, count=1)
if count != 1:
    raise SystemExit(
        f"replace_nix_string_assign: expected 1 match for {name} in {path}, got {count}"
    )
path.write_text(new)
PY
}

replace_attr_sha256() {
  local file=$1 attr=$2 value=$3
  if update_dry_run; then
    echo "dry-run: $file: $attr.sha256 = \"$value\""
    return 0
  fi
  python3 - "$file" "$attr" "$value" <<'PY'
import pathlib, re, sys

path = pathlib.Path(sys.argv[1])
attr = sys.argv[2]
value = sys.argv[3]
text = path.read_text()
pat = re.compile(
    rf"({re.escape(attr)}\s*=\s*\{{(?:[^{{}}]|\n)*?sha256\s*=\s*\")[^\"]*(\")",
    re.M,
)
new, count = pat.subn(rf"\g<1>{value}\2", text, count=1)
if count != 1:
    raise SystemExit(
        f"replace_attr_sha256: expected 1 match for {attr} in {path}, got {count}"
    )
path.write_text(new)
PY
}

replace_ninerouter_image() {
  local file=$1 image=$2
  if update_dry_run; then
    echo "dry-run: $file: NINEROUTER_IMAGE default $image"
    return 0
  fi
  python3 - "$file" "$image" <<'PY'
import pathlib, re, sys

path = pathlib.Path(sys.argv[1])
image = sys.argv[2]
text = path.read_text()
pat = re.compile(r"(image=\$\{NINEROUTER_IMAGE:-)[^}]+(\})")
new, count = pat.subn(rf"\g<1>{image}\2", text, count=1)
if count != 1:
    raise SystemExit(f"replace_ninerouter_image: expected 1 match in {path}, got {count}")
path.write_text(new)
PY
}
