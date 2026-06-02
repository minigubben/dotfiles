#!/usr/bin/env bash

configure_hyprland_copr_repositories() {
  local distro="$1"
  shift

  [[ "$distro" == "fedora" ]] || return 0

  if ! (( INSTALL_THIRD_PARTY )); then
    warn "Skipping Hyprland Copr repository because --no-third-party was used."
    return 0
  fi

  install_repo_package fedora dnf-plugins-core || true
  sudo_cmd dnf copr enable -y nett00n/hyprland
}

install_hyprland_copr_packages() {
  local distro="$1"
  shift

  [[ "$distro" == "fedora" ]] || return 0
}
