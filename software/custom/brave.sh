#!/usr/bin/env bash

add_brave_apt_repository() {
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
}

add_brave_rpm_repository() {
  log "Adding Brave rpm repository."
  install_repo_package fedora dnf-plugins-core || true

  if [[ -r /etc/yum.repos.d/brave-browser.repo ]]; then
    log "Brave rpm repository is already configured."
    return 0
  fi

  if ! sudo_cmd dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo; then
    warn "Failed to add Brave Fedora repository."
    return 1
  fi

  sudo_cmd rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
}

install_brave_packages() {
  local distro="$1"
  shift

  local package
  local -a packages=("$@")

  (( ${#packages[@]} > 0 )) || return

  if ! (( INSTALL_THIRD_PARTY )); then
    for package in "${packages[@]}"; do
      warn "Skipping third-party Brave package because --no-third-party was used: $package"
    done
    return
  fi

  case "$distro" in
    arch)
      for package in "${packages[@]}"; do
        if ! install_aur_package "$package"; then
          warn "Failed to install Brave AUR package: $package"
        fi
      done
      ;;
    fedora)
      if add_brave_rpm_repository; then
        for package in "${packages[@]}"; do
          if ! install_repo_package fedora "$package"; then
            warn "Failed to install Brave Fedora package: $package"
          fi
        done
      else
        warn "Failed to add Brave Fedora repository."
      fi
      ;;
    ubuntu)
      if add_brave_apt_repository; then
        for package in "${packages[@]}"; do
          if ! install_repo_package ubuntu "$package"; then
            warn "Failed to install Brave Ubuntu package: $package"
          fi
        done
      else
        warn "Failed to add Brave Ubuntu repository."
      fi
      ;;
  esac
}
