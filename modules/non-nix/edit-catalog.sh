#!/usr/bin/env bash
# Flag-first catalog editor for modules/non-nix/catalog.toml and catalog.local.toml.
# Invoked by devenv scripts/tasks non-nix:add{,-local} / non-nix:remove{,-local}.
set -euo pipefail

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../update/pin-lib.sh"

usage_add() {
  local cmd=$1 catalog=$2
  cat <<EOF
Usage: ${cmd} --name NAME --kind KIND --scope SCOPE --pin PIN --docs TEXT [options]

Add a [[tool]] entry to ${catalog}.

Required:
  --name NAME              Tool name (unique)
  --kind KIND              cli | docker-image | vscode-extension
  --scope SCOPE            user | project
  --pin PIN                Version / tag pin
  --docs TEXT              One-line comment text (without leading #)

Kind-specific (required for that kind):
  --mise SPEC              cli (e.g. ubi:owner/repo, npm:pkg, pipx:pkg)
  --image IMAGE            docker-image (e.g. owner/name)
  --publisher ID           vscode-extension
  --extension NAME         vscode-extension

Optional:
  --bin NAME               Binary name override (cli)
  --nix-attr ATTR          Nix attr path segment(s); repeat or comma-separate
  --homepage-contains STR  Homepage identity substring for Nix promotion
  --registry ID            vscode-extension: marketplace (default) or open-vsx
  --sha256 HASH            vscode-extension: nix32 hash (required for open-vsx)
  --dry-run                Print the block; do not write
  -h, --help               Show this help

Examples:
  ${cmd} --name example-cli --kind cli --scope project --pin 1.0.0 \\
    --mise ubi:owner/example-cli \\
    --docs 'Example CLI. Docs: https://example.com'
  ${cmd} --name my-image --kind docker-image --scope user --pin 0.1.0 \\
    --image owner/my-image --docs 'My image. Docs: https://example.com/img'
  ${cmd} --name my-ext --kind vscode-extension --scope user --pin 1.2.3 \\
    --publisher acme --extension my-ext \\
    --docs 'Acme extension. Docs: https://marketplace.visualstudio.com/items?itemName=acme.my-ext'
  ${cmd} --name navi --kind cli --scope user --pin 2.24.0 \\
    --mise ubi:denisidoro/navi --nix-attr navi \\
    --homepage-contains denisidoro/navi --dry-run \\
    --docs 'Interactive cheatsheets. Docs: https://github.com/denisidoro/navi'
EOF
}

usage_remove() {
  local cmd=$1 catalog=$2
  cat <<EOF
Usage: ${cmd} --name NAME [--dry-run]

Remove a [[tool]] block (and its preceding docs # comment) from ${catalog}.

Required:
  --name NAME     Tool name to remove

Optional:
  --dry-run       Print what would be removed; do not write
  -h, --help      Show this help

Examples:
  ${cmd} --name example-cli
  ${cmd} --name example-cli --dry-run
EOF
}

die() {
  echo "$*" >&2
  exit 1
}

need_arg() {
  local flag=$1
  [[ $# -ge 2 && -n ${2:-} && $2 != -* ]] || die "Error: ${flag} requires a value."
}

catalog_example_path() {
  local root
  root=$(update_repo_root)
  if [[ -f $root/catalog.local.toml.example ]]; then
    printf '%s\n' "$root/catalog.local.toml.example"
  elif [[ -f $root/modules/non-nix/catalog.local.toml.example ]]; then
    printf '%s\n' "$root/modules/non-nix/catalog.local.toml.example"
  else
    die "Error: catalog.local.toml.example not found (tried repo root and modules/non-nix/)."
  fi
}

ensure_local_catalog() {
  local path example
  path=$(catalog_local_path)
  if [[ -f $path ]]; then
    printf '%s\n' "$path"
    return 0
  fi
  example=$(catalog_example_path)
  mkdir -p "$(dirname "$path")"
  if [[ ${DRY_RUN:-0} == 1 ]]; then
    echo "dry-run: would create $path from $example" >&2
    printf '%s\n' "$path"
    return 0
  fi
  cp "$example" "$path"
  echo "created $path from $(basename "$example")" >&2
  printf '%s\n' "$path"
}

require_template() {
  local cmd=$1
  local root
  root=$(update_repo_root)
  if [[ ! -d $root/includes/update ]]; then
    die "Error: ${cmd} only works in the template checkout (includes/update/ missing).
Monorepo users: use non-nix:add-local / non-nix:remove-local instead."
  fi
}

catalog_has_name() {
  local name=$1 path=$2
  [[ -f $path ]] || return 1
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
        raise SystemExit(0)
raise SystemExit(1)
PY
}

toml_quote() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

format_tool_block() {
  local docs=$1
  local out="# ${docs}"$'\n'"[[tool]]"$'\n'
  out+="name = $(toml_quote "$NAME")"$'\n'
  out+="kind = $(toml_quote "$KIND")"$'\n'
  out+="scope = $(toml_quote "$SCOPE")"$'\n'
  out+="pin = $(toml_quote "$PIN")"$'\n'
  case $KIND in
    cli)
      out+="mise = $(toml_quote "$MISE")"$'\n'
      ;;
    docker-image)
      out+="image = $(toml_quote "$IMAGE")"$'\n'
      ;;
    vscode-extension)
      out+="publisher = $(toml_quote "$PUBLISHER")"$'\n'
      out+="extension = $(toml_quote "$EXTENSION")"$'\n'
      if [[ -n ${REGISTRY:-} && $REGISTRY != marketplace ]]; then
        out+="registry = $(toml_quote "$REGISTRY")"$'\n'
      fi
      if [[ -n ${SHA256:-} ]]; then
        out+="sha256 = $(toml_quote "$SHA256")"$'\n'
      fi
      ;;
  esac
  if [[ -n ${BIN:-} ]]; then
    out+="bin = $(toml_quote "$BIN")"$'\n'
  fi
  if [[ ${#NIX_ATTRS[@]} -gt 0 ]]; then
    local parts=() a
    for a in "${NIX_ATTRS[@]}"; do
      parts+=("$(toml_quote "$a")")
    done
    local IFS=', '
    out+="nixAttr = [${parts[*]}]"$'\n'
  fi
  if [[ -n ${HOMEPAGE_CONTAINS:-} ]]; then
    out+="homepageContains = $(toml_quote "$HOMEPAGE_CONTAINS")"$'\n'
  fi
  printf '%s' "$out"
}

append_tool() {
  local path=$1 block=$2
  python3 - "$path" "$block" "${DRY_RUN:-0}" <<'PY'
import pathlib, sys

path = pathlib.Path(sys.argv[1])
block = sys.argv[2]
dry = sys.argv[3] == "1"
text = path.read_text() if path.is_file() else ""
if text and not text.endswith("\n"):
    text += "\n"
if text and not text.endswith("\n\n"):
    if text.endswith("\n"):
        text += "\n"
    else:
        text += "\n\n"
new_text = text + block
if not new_text.endswith("\n"):
    new_text += "\n"
if dry:
    print(block, end="" if block.endswith("\n") else "\n")
    raise SystemExit(0)
path.write_text(new_text)
print(f"added {path}")
PY
}

remove_tool() {
  local path=$1 name=$2
  python3 - "$path" "$name" "${DRY_RUN:-0}" <<'PY'
import pathlib, re, sys

path = pathlib.Path(sys.argv[1])
name = sys.argv[2]
dry = sys.argv[3] == "1"
if not path.is_file():
    raise SystemExit(f"Error: catalog not found: {path}")
text = path.read_text()
# Span from [[tool]] up to (not including) the next [[tool]]. Trailing
# "# …" lines in that span belong to the *next* tool — peel them off.
blocks = list(re.finditer(r"(?ms)^\[\[tool\]\].*?(?=^\[\[tool\]\]|\Z)", text))
for match in blocks:
    block = match.group(0)
    if not re.search(rf'(?m)^\s*name\s*=\s*"{re.escape(name)}"\s*$', block):
        continue
    body = re.sub(r"(?:\n[ \t]*#[^\n]*)+\n*\Z", "\n", block)
    end = match.start() + len(body)
    start = match.start()
    prefix = text[:start]
    docs = re.search(r"(#[^\n]*\n)\Z", prefix)
    if docs:
        start = docs.start(1)
    removed = text[start:end]
    new_text = text[:start] + text[end:]
    new_text = re.sub(r"\n{3,}", "\n\n", new_text)
    if dry:
        print(removed, end="" if removed.endswith("\n") else "\n")
        raise SystemExit(0)
    path.write_text(new_text)
    print(f"removed {name} from {path}")
    raise SystemExit(0)
raise SystemExit(f"Error: tool {name!r} not found in {path}")
PY
}

parse_nix_attr_value() {
  local raw=$1
  local IFS=','
  local part
  # shellcheck disable=SC2086
  for part in $raw; do
    part=${part#"${part%%[![:space:]]*}"}
    part=${part%"${part##*[![:space:]]}"}
    [[ -n $part ]] || continue
    NIX_ATTRS+=("$part")
  done
}

cmd_add() {
  local task=$1 catalog_kind=$2
  shift 2 || true

  NAME='' KIND='' SCOPE='' PIN='' DOCS=''
  MISE='' IMAGE='' PUBLISHER='' EXTENSION='' BIN='' HOMEPAGE_CONTAINS=''
  REGISTRY='' SHA256=''
  NIX_ATTRS=()
  DRY_RUN=0
  SHOW_HELP=0

  while [[ $# -gt 0 ]]; do
    case $1 in
      -h | --help)
        SHOW_HELP=1
        shift
        ;;
      --name)
        need_arg "$@"
        NAME=$2
        shift 2
        ;;
      --kind)
        need_arg "$@"
        KIND=$2
        shift 2
        ;;
      --scope)
        need_arg "$@"
        SCOPE=$2
        shift 2
        ;;
      --pin)
        need_arg "$@"
        PIN=$2
        shift 2
        ;;
      --docs)
        need_arg "$@"
        DOCS=$2
        shift 2
        ;;
      --mise)
        need_arg "$@"
        MISE=$2
        shift 2
        ;;
      --image)
        need_arg "$@"
        IMAGE=$2
        shift 2
        ;;
      --publisher)
        need_arg "$@"
        PUBLISHER=$2
        shift 2
        ;;
      --extension)
        need_arg "$@"
        EXTENSION=$2
        shift 2
        ;;
      --bin)
        need_arg "$@"
        BIN=$2
        shift 2
        ;;
      --nix-attr)
        need_arg "$@"
        parse_nix_attr_value "$2"
        shift 2
        ;;
      --homepage-contains)
        need_arg "$@"
        HOMEPAGE_CONTAINS=$2
        shift 2
        ;;
      --registry)
        need_arg "$@"
        REGISTRY=$2
        shift 2
        ;;
      --sha256)
        need_arg "$@"
        SHA256=$2
        shift 2
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      *)
        die "Error: unknown option: $1
Run: ${task} --help"
        ;;
    esac
  done

  local catalog_label
  if [[ $catalog_kind == local ]]; then
    catalog_label="modules/non-nix/catalog.local.toml"
  else
    catalog_label="modules/non-nix/catalog.toml"
  fi

  if [[ $SHOW_HELP == 1 ]]; then
    usage_add "$task" "$catalog_label"
    return 0
  fi

  if [[ $catalog_kind == shipped ]]; then
    require_template "$task"
  fi

  [[ -n $NAME ]] || die "Error: --name is required.
  ${task} --name <name> --kind cli --scope project --pin 1.0.0 --mise ubi:owner/repo --docs '…'"
  [[ -n $KIND ]] || die "Error: --kind is required (cli|docker-image|vscode-extension)."
  [[ -n $SCOPE ]] || die "Error: --scope is required (user|project)."
  [[ -n $PIN ]] || die "Error: --pin is required."
  [[ -n $DOCS ]] || die "Error: --docs is required (one-line text without leading #)."

  case $KIND in
    cli | docker-image | vscode-extension) ;;
    *) die "Error: --kind must be cli, docker-image, or vscode-extension (got: $KIND)." ;;
  esac
  case $SCOPE in
    user | project) ;;
    *) die "Error: --scope must be user or project (got: $SCOPE)." ;;
  esac

  # Strip a leading # if an agent pasted one anyway.
  DOCS=${DOCS#\# }
  DOCS=${DOCS#\#}

  case $KIND in
    cli)
      [[ -n $MISE ]] || die "Error: --mise is required for kind=cli."
      ;;
    docker-image)
      [[ -n $IMAGE ]] || die "Error: --image is required for kind=docker-image."
      ;;
    vscode-extension)
      [[ -n $PUBLISHER ]] || die "Error: --publisher is required for kind=vscode-extension."
      [[ -n $EXTENSION ]] || die "Error: --extension is required for kind=vscode-extension."
      if [[ -n $REGISTRY && $REGISTRY != marketplace && $REGISTRY != open-vsx && $REGISTRY != openvsx ]]; then
        die "Error: --registry must be marketplace or open-vsx (got: $REGISTRY)."
      fi
      if [[ $REGISTRY == open-vsx || $REGISTRY == openvsx ]]; then
        [[ -n $SHA256 ]] || die "Error: --sha256 is required for registry=open-vsx."
      fi
      ;;
  esac

  local path shipped
  if [[ $catalog_kind == local ]]; then
    path=$(ensure_local_catalog)
    shipped=$(catalog_path)
    if catalog_has_name "$NAME" "$shipped"; then
      die "Error: name '$NAME' already exists in shipped modules/non-nix/catalog.toml.
Do not override shipped tools in catalog.local.toml."
    fi
  else
    path=$(catalog_path)
    [[ -f $path ]] || die "Error: missing $path"
  fi

  if [[ -f $path ]] && catalog_has_name "$NAME" "$path"; then
    die "Error: name '$NAME' already exists in $path"
  fi

  local block
  block=$(format_tool_block "$DOCS")
  if [[ $DRY_RUN == 1 ]]; then
    echo "dry-run: would append to $path:"
  fi
  append_tool "$path" "$block"
}

cmd_remove() {
  local task=$1 catalog_kind=$2
  shift 2 || true

  NAME=
  DRY_RUN=0
  SHOW_HELP=0

  while [[ $# -gt 0 ]]; do
    case $1 in
      -h | --help)
        SHOW_HELP=1
        shift
        ;;
      --name)
        need_arg "$@"
        NAME=$2
        shift 2
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      *)
        die "Error: unknown option: $1
Run: ${task} --help"
        ;;
    esac
  done

  local catalog_label
  if [[ $catalog_kind == local ]]; then
    catalog_label="modules/non-nix/catalog.local.toml"
  else
    catalog_label="modules/non-nix/catalog.toml"
  fi

  if [[ $SHOW_HELP == 1 ]]; then
    usage_remove "$task" "$catalog_label"
    return 0
  fi

  if [[ $catalog_kind == shipped ]]; then
    require_template "$task"
  fi

  [[ -n $NAME ]] || die "Error: --name is required.
  ${task} --name <name>"

  local path
  if [[ $catalog_kind == local ]]; then
    path=$(catalog_local_path)
  else
    path=$(catalog_path)
  fi
  [[ -f $path ]] || die "Error: catalog not found: $path"

  if [[ $DRY_RUN == 1 ]]; then
    echo "dry-run: would remove from $path:"
  fi
  remove_tool "$path" "$NAME"
}

main() {
  local action=${1:-}
  shift || true
  case $action in
    add-local)
      cmd_add "non-nix:add-local" local "$@"
      ;;
    remove-local)
      cmd_remove "non-nix:remove-local" local "$@"
      ;;
    add)
      cmd_add "non-nix:add" shipped "$@"
      ;;
    remove)
      cmd_remove "non-nix:remove" shipped "$@"
      ;;
    -h | --help | "")
      cat <<'EOF'
Usage: edit-catalog.sh <add-local|remove-local|add|remove> [flags...]

Edit modules/non-nix catalog files (preserves sibling comments).

Commands:
  add-local / remove-local   modules/non-nix/catalog.local.toml
  add / remove               modules/non-nix/catalog.toml (template only)

Run a command with --help for flags and Examples.
EOF
      [[ -n $action ]] || exit 1
      ;;
    *)
      die "Error: unknown command: $action
Run: edit-catalog.sh --help"
      ;;
  esac
}

main "$@"
