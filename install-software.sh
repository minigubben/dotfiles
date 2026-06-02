#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOFTWARE_DIR="$SCRIPT_DIR/software"
COMMON_FILE="$SOFTWARE_DIR/common.txt"

DRY_RUN=0
SKIP_REFRESH=0
INSTALL_AUR=1
INSTALL_THIRD_PARTY=1
DISTRO_OVERRIDE=""

declare -a REPO_PACKAGES=()
declare -a AUR_PACKAGES=()
declare -a BRAVE_PACKAGES=()
declare -a MANUAL_ITEMS=()
declare -a WARNINGS=()

usage() {
  cat <<EOF
Usage: $0 [options]

Installs software listed in software/common.txt plus the distro-specific list.

Options:
  --software-dir PATH  Read common.txt and distro lists from a different directory.
  --distro NAME        Override distro detection: arch, fedora, or ubuntu.
  --dry-run           Print what would be installed without changing the system.
  --list              Print the resolved package list and exit.
  --no-refresh        Skip package metadata refresh.
  --no-aur            Do not install Arch AUR packages.
  --no-third-party    Do not add/use third-party repositories such as Brave.
  -h, --help          Show this help.
EOF
}

log() {
  printf '[install] %s\n' "$*"
}

warn() {
  WARNINGS+=("$*")
  printf '[warn] %s\n' "$*" >&2
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

run_cmd() {
  if (( DRY_RUN )); then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

sudo_cmd() {
  if (( EUID == 0 )); then
    run_cmd "$@"
  else
    run_cmd sudo "$@"
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

detect_distro() {
  if [[ ! -r /etc/os-release ]]; then
    printf 'unknown'
    return
  fi

  # shellcheck disable=SC1091
  . /etc/os-release

  case "${ID:-}" in
    arch|endeavouros|manjaro|garuda)
      printf 'arch'
      return
      ;;
    fedora|rhel|centos|rocky|almalinux)
      printf 'fedora'
      return
      ;;
    ubuntu|pop|linuxmint|elementary|zorin)
      printf 'ubuntu'
      return
      ;;
  esac

  case " ${ID_LIKE:-} " in
    *" arch "*)
      printf 'arch'
      ;;
    *" fedora "*|*" rhel "*)
      printf 'fedora'
      ;;
    *" ubuntu "*|*" debian "*)
      printf 'ubuntu'
      ;;
    *)
      printf 'unknown'
      ;;
  esac
}

add_unique() {
  local -n target="$1"
  local item="$2"
  local existing

  [[ -z "$item" || "$item" == "-" ]] && return

  for existing in "${target[@]}"; do
    [[ "$existing" == "$item" ]] && return
  done

  target+=("$item")
}

parse_manifest() {
  local distro="$1"
  local distro_file="$SOFTWARE_DIR/$distro.txt"

  if [[ ! -r "$COMMON_FILE" ]]; then
    printf 'Cannot read common package list: %s\n' "$COMMON_FILE" >&2
    exit 1
  fi

  read_package_file "$COMMON_FILE"

  if [[ -r "$distro_file" ]]; then
    read_package_file "$distro_file"
  else
    warn "No distro package list found for $distro: $distro_file"
  fi
}

read_package_file() {
  local file="$1"
  local line_no=0
  local line package

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    package="$(trim "$line")"

    [[ -z "$package" || "${package:0:1}" == "#" ]] && continue

    if [[ "$package" == *[[:space:]]* && "$package" != manual:* ]]; then
      warn "Ignoring invalid package entry with whitespace in $file line $line_no: $package"
      continue
    fi

    add_package "$package"
  done < "$file"
}

add_package() {
  local package="$1"

  case "$package" in
    repo:*)
      add_unique REPO_PACKAGES "${package#repo:}"
      ;;
    aur:*)
      add_unique AUR_PACKAGES "${package#aur:}"
      ;;
    brave:*)
      add_unique BRAVE_PACKAGES "${package#brave:}"
      ;;
    manual:*)
      add_unique MANUAL_ITEMS "${package#manual:}"
      ;;
    *)
      add_unique REPO_PACKAGES "$package"
      ;;
  esac
}

print_resolved_list() {
  local distro="$1"

  printf 'Distro family: %s\n' "$distro"
  printf 'Common package list: %s\n' "$COMMON_FILE"
  printf 'Distro package list: %s\n\n' "$SOFTWARE_DIR/$distro.txt"

  printf 'Repository packages:\n'
  printf '  %s\n' "${REPO_PACKAGES[@]:-none}"
  printf '\nBrave packages:\n'
  printf '  %s\n' "${BRAVE_PACKAGES[@]:-none}"
  printf '\nAUR packages:\n'
  printf '  %s\n' "${AUR_PACKAGES[@]:-none}"
  printf '\nManual items:\n'
  printf '  %s\n' "${MANUAL_ITEMS[@]:-none}"
}

ensure_package_manager() {
  local distro="$1"

  case "$distro" in
    arch)
      command_exists pacman || { printf 'pacman was not found.\n' >&2; exit 1; }
      ;;
    fedora)
      command_exists dnf || { printf 'dnf was not found.\n' >&2; exit 1; }
      ;;
    ubuntu)
      command_exists apt-get || { printf 'apt-get was not found.\n' >&2; exit 1; }
      ;;
  esac
}

refresh_repositories() {
  local distro="$1"

  (( SKIP_REFRESH )) && return

  case "$distro" in
    arch)
      log "Refreshing Arch package database and applying upgrades."
      sudo_cmd pacman -Syu --noconfirm
      ;;
    fedora)
      log "Refreshing Fedora package metadata."
      sudo_cmd dnf makecache
      ;;
    ubuntu)
      log "Refreshing Ubuntu package metadata."
      sudo_cmd apt-get update
      ;;
  esac
}

install_repo_package() {
  local distro="$1"
  local package="$2"

  log "Installing $package"
  case "$distro" in
    arch)
      sudo_cmd pacman -S --needed --noconfirm "$package"
      ;;
    fedora)
      sudo_cmd dnf install -y "$package"
      ;;
    ubuntu)
      sudo_cmd apt-get install -y "$package"
      ;;
  esac
}

install_repo_packages() {
  local distro="$1"
  local package

  for package in "${REPO_PACKAGES[@]}"; do
    if ! install_repo_package "$distro" "$package"; then
      warn "Failed to install repository package: $package"
    fi
  done
}

find_aur_helper() {
  if command_exists yay; then
    printf 'yay'
  elif command_exists paru; then
    printf 'paru'
  else
    printf ''
  fi
}

install_aur_package() {
  local package="$1"
  local helper

  if ! (( INSTALL_AUR )); then
    warn "Skipping AUR package because --no-aur was used: $package"
    return 1
  fi

  helper="$(find_aur_helper)"
  if [[ -z "$helper" ]]; then
    warn "Cannot install AUR package without yay or paru: $package"
    return 1
  fi

  log "Installing AUR package $package with $helper"
  run_cmd "$helper" -S --needed --noconfirm "$package"
}

install_aur_packages() {
  local distro="$1"
  local package

  [[ "$distro" == "arch" ]] || return

  for package in "${AUR_PACKAGES[@]}"; do
    if ! install_aur_package "$package"; then
      warn "Failed to install AUR package: $package"
    fi
  done
}

install_brave_ubuntu() {
  log "Adding Brave apt repository."
  sudo_cmd install -d -m 0755 /etc/apt/keyrings

  if (( DRY_RUN )); then
    printf '+ curl -fsS https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg | sudo tee /etc/apt/keyrings/brave-browser-archive-keyring.gpg >/dev/null\n'
    printf '+ echo "deb [signed-by=/etc/apt/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null\n'
  else
    curl -fsS https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
      | sudo tee /etc/apt/keyrings/brave-browser-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
      | sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null
  fi

  sudo_cmd apt-get update
  sudo_cmd apt-get install -y brave-browser
}

install_brave_fedora() {
  log "Adding Brave rpm repository."
  install_repo_package fedora dnf-plugins-core || true

  if ! sudo_cmd dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo; then
    sudo_cmd dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
  fi

  sudo_cmd rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
  sudo_cmd dnf install -y brave-browser
}

install_brave_packages() {
  local distro="$1"
  local package

  (( ${#BRAVE_PACKAGES[@]} > 0 )) || return

  if ! (( INSTALL_THIRD_PARTY )); then
    for package in "${BRAVE_PACKAGES[@]}"; do
      warn "Skipping third-party Brave package because --no-third-party was used: $package"
    done
    return
  fi

  case "$distro" in
    arch)
      for package in "${BRAVE_PACKAGES[@]}"; do
        if ! install_aur_package "$package"; then
          warn "Failed to install Brave AUR package: $package"
        fi
      done
      ;;
    fedora)
      if ! install_brave_fedora; then
        warn "Failed to install Brave from its Fedora repository."
      fi
      ;;
    ubuntu)
      if ! install_brave_ubuntu; then
        warn "Failed to install Brave from its Ubuntu repository."
      fi
      ;;
  esac
}

print_manual_items() {
  local item

  (( ${#MANUAL_ITEMS[@]} > 0 )) || return 0

  printf '\nManual follow-up items:\n'
  for item in "${MANUAL_ITEMS[@]}"; do
    printf '  - %s\n' "$item"
  done
}

print_warnings() {
  local warning

  (( ${#WARNINGS[@]} > 0 )) || return 0

  printf '\nWarnings:\n' >&2
  for warning in "${WARNINGS[@]}"; do
    printf '  - %s\n' "$warning" >&2
  done
}

main() {
  local distro list_only=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --software-dir)
        [[ $# -ge 2 ]] || { printf '--software-dir requires a path.\n' >&2; exit 1; }
        SOFTWARE_DIR="$2"
        COMMON_FILE="$SOFTWARE_DIR/common.txt"
        shift 2
        ;;
      --distro)
        [[ $# -ge 2 ]] || { printf '--distro requires arch, fedora, or ubuntu.\n' >&2; exit 1; }
        case "$2" in
          arch|fedora|ubuntu)
            DISTRO_OVERRIDE="$2"
            ;;
          *)
            printf 'Unsupported --distro value: %s\n' "$2" >&2
            exit 1
            ;;
        esac
        shift 2
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --list)
        list_only=1
        shift
        ;;
      --no-refresh)
        SKIP_REFRESH=1
        shift
        ;;
      --no-aur)
        INSTALL_AUR=0
        shift
        ;;
      --no-third-party)
        INSTALL_THIRD_PARTY=0
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        printf 'Unknown option: %s\n\n' "$1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

  distro="${DISTRO_OVERRIDE:-$(detect_distro)}"
  if [[ "$distro" == "unknown" ]]; then
    printf 'Unsupported distro. Expected Arch, Fedora, or Ubuntu-like /etc/os-release.\n' >&2
    exit 1
  fi

  parse_manifest "$distro"

  if (( list_only )); then
    print_resolved_list "$distro"
    exit 0
  fi

  if ! (( DRY_RUN )); then
    ensure_package_manager "$distro"
  fi
  refresh_repositories "$distro"
  install_repo_packages "$distro"
  install_brave_packages "$distro"
  install_aur_packages "$distro"
  print_manual_items
  print_warnings
}

main "$@"
