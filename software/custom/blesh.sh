#!/usr/bin/env bash

install_blesh_from_nightly() {
  local tmp_dir archive extract_dir

  if ! (( INSTALL_THIRD_PARTY )); then
    warn "Skipping ble.sh download because --no-third-party was used."
    return 0
  fi

  if (( DRY_RUN )); then
    printf '+ curl -fL %q -o /tmp/ble-nightly.tar.xz\n' "https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz"
    printf '+ tar -xJf /tmp/ble-nightly.tar.xz -C /tmp\n'
    printf '+ bash /tmp/ble-nightly/ble.sh --install %q\n' "$HOME/.local/share"
    return 0
  fi

  tmp_dir="$(mktemp -d)"
  archive="$tmp_dir/ble-nightly.tar.xz"

  if ! curl -fL "https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz" -o "$archive"; then
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! tar -xJf "$archive" -C "$tmp_dir"; then
    rm -rf "$tmp_dir"
    return 1
  fi

  extract_dir="$tmp_dir/ble-nightly"
  if ! bash "$extract_dir/ble.sh" --install "$HOME/.local/share"; then
    rm -rf "$tmp_dir"
    return 1
  fi

  rm -rf "$tmp_dir"
}

install_blesh_packages() {
  local distro="$1"
  shift

  local package
  for package in "$@"; do
    case "$package" in
      blesh|ble.sh)
        case "$distro" in
          arch)
            if ! (( INSTALL_THIRD_PARTY )); then
              warn "Skipping ble.sh AUR package because --no-third-party was used: blesh-git"
            else
              install_aur_package blesh-git || warn "Failed to install ble.sh AUR package."
            fi
            ;;
          fedora)
            if (( INSTALL_THIRD_PARTY )); then
              install_repo_package fedora xz || true
              install_blesh_from_nightly || warn "Failed to install ble.sh nightly build."
            else
              install_blesh_from_nightly || warn "Failed to install ble.sh nightly build."
            fi
            ;;
          ubuntu)
            if (( INSTALL_THIRD_PARTY )); then
              install_repo_package ubuntu xz-utils || true
              install_blesh_from_nightly || warn "Failed to install ble.sh nightly build."
            else
              install_blesh_from_nightly || warn "Failed to install ble.sh nightly build."
            fi
            ;;
        esac
        ;;
      *)
        warn "Unsupported ble.sh custom package: $package"
        ;;
    esac
  done
}
