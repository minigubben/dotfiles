#!/usr/bin/env bash

install_fnm_from_upstream() {
  if ! (( INSTALL_THIRD_PARTY )); then
    warn "Skipping fnm installer because --no-third-party was used."
    return 0
  fi

  if (( DRY_RUN )); then
    printf '+ curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir %q --skip-shell\n' "$HOME/.local/share/fnm"
    return 0
  fi

  curl -fsSL https://fnm.vercel.app/install \
    | bash -s -- --install-dir "$HOME/.local/share/fnm" --skip-shell
}

install_fnm_packages() {
  local distro="$1"
  shift

  local package
  for package in "$@"; do
    case "$package" in
      fnm)
        case "$distro" in
          arch)
            install_repo_package arch fnm || warn "Failed to install fnm Arch package."
            ;;
          fedora|ubuntu)
            install_fnm_from_upstream || warn "Failed to install fnm from upstream installer."
            ;;
        esac
        ;;
      *)
        warn "Unsupported fnm custom package: $package"
        ;;
    esac
  done
}
