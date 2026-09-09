#!/usr/bin/env bash
# Shared pin/catalog helpers (shipped). Sourced by modules/update and includes/update.
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


catalog_path() {
  printf '%s\n' "$(update_repo_root)/modules/non-nix/catalog.toml"
}

catalog_local_path() {
  printf '%s\n' "$(update_repo_root)/modules/non-nix/catalog.local.toml"
}

# Usage: catalog_read_pin NAME [PATH]
catalog_read_pin() {
  local name=$1 path=${2:-$(catalog_path)}
  python3 - "$name" "$path" <<'PY'
import sys
try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib  # type: ignore

name, path = sys.argv[1], sys.argv[2]
with open(path, "rb") as f:
    data = tomllib.load(f)
for tool in data.get("tool", []):
    if tool.get("name") == name:
        print(tool["pin"])
        raise SystemExit(0)
raise SystemExit(f"catalog_read_pin: {name} not found in {path}")
PY
}

# Replace pin = "…" inside the [[tool]] block for name=; keeps comments intact.
# Usage: catalog_set_pin NAME PIN [PATH]
catalog_set_pin() {
  local name=$1 pin=$2 path=${3:-$(catalog_path)}
  if update_dry_run; then
    echo "dry-run: $path: $name.pin = \"$pin\""
    return 0
  fi
  python3 - "$path" "$name" "$pin" <<'PY'
import pathlib, re, sys

path = pathlib.Path(sys.argv[1])
name = sys.argv[2]
pin = sys.argv[3]
text = path.read_text()
blocks = list(re.finditer(r"(?ms)^\[\[tool\]\].*?(?=^\[\[tool\]\]|\Z)", text))
for match in blocks:
    block = match.group(0)
    if not re.search(rf'(?m)^\s*name\s*=\s*"{re.escape(name)}"\s*$', block):
        continue
    new_block, count = re.subn(
        r'(?m)^(\s*pin\s*=\s*")[^"]*("\s*)$',
        rf"\g<1>{pin}\2",
        block,
        count=1,
    )
    if count != 1:
        raise SystemExit(f"catalog_set_pin: pin line missing for {name}")
    path.write_text(text[: match.start()] + new_block + text[match.end() :])
    raise SystemExit(0)
raise SystemExit(f"catalog_set_pin: {name} not found in {path}")
PY
}

# TSV rows: name kind mise image publisher extension (empty strings when absent)
# Usage: catalog_list_tools [PATH]
catalog_list_tools() {
  local path=${1:-$(catalog_path)}
  python3 - "$path" <<'PY'
import sys
try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib  # type: ignore

with open(sys.argv[1], "rb") as f:
    data = tomllib.load(f)
for tool in data.get("tool", []):
    print(
        "\t".join(
            [
                tool.get("name", ""),
                tool.get("kind", ""),
                tool.get("mise") or "",
                tool.get("image") or "",
                tool.get("publisher") or "",
                tool.get("extension") or "",
            ]
        )
    )
PY
}

# Print "nix" or "mise" (or other via) for a catalog tool name using current nixpkgs.
catalog_tool_via() {
  local name=$1 root
  root=$(update_repo_root)
  nix eval --impure --raw --expr "
    let
      pkgs = import <nixpkgs> { };
      lib = pkgs.lib;
      nonNix = import ${root}/modules/non-nix/lib.nix { inherit lib; };
      e = nonNix.resolvedByName pkgs \"${name}\";
    in
    if e == null then \"missing\" else e.via
  " 2>/dev/null || printf '%s\n' missing
}
