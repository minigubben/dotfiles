#!/usr/bin/env bash

install_starship_from_upstream() {
  if ! (( INSTALL_THIRD_PARTY )); then
    warn "Skipping Starship installer because --no-third-party was used."
    return 0
  fi

  if (( DRY_RUN )); then
    printf '+ mkdir -p %q\n' "$HOME/.local/bin"
    printf '+ curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b %q\n' "$HOME/.local/bin"
    return 0
  fi

  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://starship.rs/install.sh \
    | sh -s -- -y -b "$HOME/.local/bin"
}

install_starship_packages() {
  local distro="$1"
  shift

  local package
  for package in "$@"; do
    case "$package" in
      starship)
        case "$distro" in
          arch)
            install_repo_package arch starship || warn "Failed to install Starship Arch package."
            ;;
          fedora|ubuntu)
            install_starship_from_upstream || warn "Failed to install Starship from upstream installer."
            ;;
        esac
        ;;
      *)
        warn "Unsupported Starship custom package: $package"
        ;;
    esac
  done
}
