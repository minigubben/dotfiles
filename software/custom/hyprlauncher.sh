#!/usr/bin/env bash

install_hyprlauncher_from_source() {
  local distro="$1"
  local source_dir="$HOME/.local/src/hyprlauncher"
  local jobs

  if ! (( INSTALL_THIRD_PARTY )); then
    warn "Skipping hyprlauncher source install because --no-third-party was used."
    return 0
  fi

  case "$distro" in
    fedora)
      install_repo_package fedora git || true
      install_repo_package fedora cmake || true
      install_repo_package fedora gcc-c++ || true
      install_repo_package fedora make || true
      ;;
    ubuntu)
      install_repo_package ubuntu git || true
      install_repo_package ubuntu cmake || true
      install_repo_package ubuntu g++ || true
      install_repo_package ubuntu make || true
      ;;
  esac

  jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')"

  if (( DRY_RUN )); then
    printf '+ git clone --depth 1 https://github.com/hyprwm/hyprlauncher.git %q\n' "$source_dir"
    printf '+ git -C %q pull --ff-only\n' "$source_dir"
    printf '+ cmake -S %q -B %q -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=%q\n' "$source_dir" "$source_dir/build" "$HOME/.local"
    printf '+ cmake --build %q --parallel %q\n' "$source_dir/build" "$jobs"
    printf '+ cmake --install %q\n' "$source_dir/build"
    return 0
  fi

  mkdir -p "$HOME/.local/src"
  if [[ -d "$source_dir/.git" ]]; then
    git -C "$source_dir" pull --ff-only
  else
    git clone --depth 1 https://github.com/hyprwm/hyprlauncher.git "$source_dir"
  fi

  cmake -S "$source_dir" -B "$source_dir/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$HOME/.local"
  cmake --build "$source_dir/build" --parallel "$jobs"
  cmake --install "$source_dir/build"
}

install_hyprlauncher_from_copr() {
  if ! (( INSTALL_THIRD_PARTY )); then
    warn "Skipping hyprlauncher Copr repository because --no-third-party was used."
    return 0
  fi

  install_repo_package fedora hyprlauncher
}

install_hyprlauncher_packages() {
  local distro="$1"
  shift

  local package
  for package in "$@"; do
    case "$package" in
      hyprlauncher)
        case "$distro" in
          arch)
            install_repo_package arch hyprlauncher || warn "Failed to install hyprlauncher Arch package."
            ;;
          fedora)
            install_hyprlauncher_from_copr || warn "Failed to install hyprlauncher from Fedora Copr."
            ;;
          ubuntu)
            install_hyprlauncher_from_source "$distro" || warn "Failed to install hyprlauncher from source. Install Hyprland development dependencies and retry."
            ;;
        esac
        ;;
      *)
        warn "Unsupported hyprlauncher custom package: $package"
        ;;
    esac
  done
}
