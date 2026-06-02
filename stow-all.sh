#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}"
DRY_RUN=0

usage() {
  cat <<EOF
Usage: $0 [options]

Runs GNU Stow for every top-level dotfiles package in this repo.

Options:
  -n, --dry-run      Show what stow would do without changing files.
  -t, --target DIR   Stow packages into DIR instead of \$HOME.
  -h, --help         Show this help.
EOF
}

log() {
  printf '[stow] %s\n' "$*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -t|--target)
      if [[ $# -lt 2 ]]; then
        printf 'Missing target directory after %s\n' "$1" >&2
        exit 1
      fi
      TARGET_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v stow >/dev/null 2>&1; then
  printf 'GNU Stow is not installed or not available in PATH.\n' >&2
  exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  printf 'Target directory does not exist: %s\n' "$TARGET_DIR" >&2
  exit 1
fi

declare -a STOW_ARGS=(
  --dir "$SCRIPT_DIR"
  --target "$TARGET_DIR"
  --verbose
)

if (( DRY_RUN )); then
  STOW_ARGS+=(--simulate)
fi

declare -a PACKAGES=()

while IFS= read -r -d '' package_dir; do
  PACKAGES+=("$(basename "$package_dir")")
done < <(
  find "$SCRIPT_DIR" -mindepth 1 -maxdepth 1 -type d \
    ! -name '.git' \
    ! -name 'software' \
    -print0 | sort -z
)

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  printf 'No stow packages found in %s\n' "$SCRIPT_DIR" >&2
  exit 1
fi

log "target: $TARGET_DIR"
for package in "${PACKAGES[@]}"; do
  log "stowing $package"
  stow "${STOW_ARGS[@]}" "$package"
done
