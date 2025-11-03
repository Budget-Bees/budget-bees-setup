#!/usr/bin/env bash
set -Eeuo pipefail

############################
# Config
############################
REPOS=(
  "git@github.com:Budget-Bees/budget-bees-db.git"
  "git@github.com:Budget-Bees/budget-bees-api.git"
  "git@github.com:Budget-Bees/budget-bees-ui.git"
)

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
TARGET_DIR="$SCRIPT_DIR/../budget-bees"
UPDATE=false
BRANCH=""

############################
# Colors & Logging
############################
supports_color() {
  # Disable color if NO_COLOR is set or we’re not on a TTY
  [[ -n "${NO_COLOR:-}" ]] && return 1
  [[ -t 1 ]] || return 1
  return 0
}

if supports_color; then
  CLR_RESET="\033[0m"
  CLR_BOLD="\033[1m"
  CLR_DIM="\033[2m"
  CLR_RED="\033[31m"
  CLR_GREEN="\033[32m"
  CLR_YELLOW="\033[33m"
  CLR_BLUE="\033[34m"
  CLR_CYAN="\033[36m"
else
  CLR_RESET=""; CLR_BOLD=""; CLR_DIM=""
  CLR_RED=""; CLR_GREEN=""; CLR_YELLOW=""
  CLR_BLUE=""; CLR_CYAN=""
fi

ts() { date +"%Y-%m-%d %H:%M:%S"; }

log()   { printf "%b[%s] %s%b\n" "$CLR_DIM" "$(ts)" "$*" "$CLR_RESET"; }
info()  { printf "%b[%s] %bINFO%b  %s%b\n" "$CLR_DIM" "$(ts)" "$CLR_CYAN" "$CLR_DIM" "$*" "$CLR_RESET"; }
ok()    { printf "%b[%s] %bOK%b    %s%b\n" "$CLR_DIM" "$(ts)" "$CLR_GREEN" "$CLR_DIM" "$*" "$CLR_RESET"; }
warn()  { printf "%b[%s] %bWARN%b  %s%b\n" "$CLR_DIM" "$(ts)" "$CLR_YELLOW" "$CLR_DIM" "$*" "$CLR_RESET"; }
error() { printf "%b[%s] %bERROR%b %s%b\n" "$CLR_DIM" "$(ts)" "$CLR_RED" "$CLR_DIM" "$*" "$CLR_RESET"; }

abort() { error "$1"; exit 1; }

trap 'error "An unexpected error occurred (line $LINENO)."; exit 1' ERR

############################
# Usage
############################
usage() {
  cat <<EOF
${CLR_BOLD}Budget Bees setup${CLR_RESET}

Creates ../budget-bees and clones the required repositories there.
If a repo already exists:
  - default: skip
  - with --update: pull latest changes

${CLR_BOLD}Usage:${CLR_RESET}
  $(basename "$0") [--update|-u] [--branch|-b <name>] [--help|-h]

${CLR_BOLD}Options:${CLR_RESET}
  -u, --update         Pull latest changes if the repo exists
  -b, --branch <name>  Clone/pull this branch for all repos
  -h, --help           Show this help

Environment:
  NO_COLOR=1           Disable colored output
EOF
}

############################
# Args
############################
while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--update) UPDATE=true; shift ;;
    -b|--branch) BRANCH="${2:-}"; [[ -z "$BRANCH" ]] && abort "Missing value for --branch"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) abort "Unknown argument: $1 (use --help)" ;;
  esac
done

############################
# Helpers
############################
require_git() {
  command -v git >/dev/null 2>&1 || abort "git is not installed or not on PATH."
}

ensure_target_dir() {
  mkdir -p "$TARGET_DIR"
  ok "Using target directory: $TARGET_DIR"
}

repo_name_from_url() {
  local url="$1"
  basename -s .git "$url"
}

checkout_branch_if_needed() {
  local dir="$1"
  if [[ -n "$BRANCH" ]]; then
    ( cd "$dir" && git fetch --all --prune && git checkout "$BRANCH" && git pull --ff-only ) >/dev/null
    ok "Checked out & updated branch '$BRANCH' in $(basename "$dir")"
  fi
}

clone_repo() {
  local url="$1"
  local name; name="$(repo_name_from_url "$url")"
  local dir="$TARGET_DIR/$name"

  if [[ -d "$dir/.git" ]]; then
    info "Repo '$name' already present."
    if $UPDATE; then
      ( cd "$dir" && git fetch --all --prune && git pull --ff-only ) >/dev/null \
        && ok "Updated '$name'." \
        || abort "Failed to update '$name'."
      checkout_branch_if_needed "$dir"
    else
      [[ -n "$BRANCH" ]] && checkout_branch_if_needed "$dir"
      info "Skipping clone for '$name'."
    fi
  elif [[ -d "$dir" ]]; then
    warn "Directory '$name' exists but is not a git repo. Skipping."
  else
    local clone_cmd=(git clone)
    [[ -n "$BRANCH" ]] && clone_cmd+=(--branch "$BRANCH")
    clone_cmd+=("$url" "$dir")

    info "Cloning '$name'..."
    "${clone_cmd[@]}" >/dev/null \
      && ok "Cloned '$name'." \
      || abort "Failed to clone '$name'."
  fi
}

############################
# Main
############################
main() {
  log "Starting Budget Bees setup"
  require_git
  ensure_target_dir

  for url in "${REPOS[@]}"; do
    clone_repo "$url"
  done

  ok "All repositories processed."
  log "Done."
}

main
