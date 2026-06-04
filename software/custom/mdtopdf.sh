#!/usr/bin/env bash

run_mdtopdf_cmd_in_dir() {
  local dir="$1"
  shift

  if (( DRY_RUN )); then
    printf '+ cd %q &&' "$dir"
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi

  (cd "$dir" && "$@")
}

find_mdtopdf_first_file() {
  local root="$1"
  local pattern="$2"
  local found

  while IFS= read -r found; do
    printf '%s' "$found"
    return 0
  done < <(find "$root" -path "$pattern" -type f | sort)

  return 1
}

install_mdtopdf_vendor_dependencies() {
  local tool_dir="$SCRIPT_DIR/vendor/mdToPdf"
  local puppeteer_install_script=""

  if [[ ! -f "$tool_dir/package.json" ]]; then
    warn "Cannot install mdToPdf dependencies because $tool_dir/package.json was not found."
    return 1
  fi

  if ! (( DRY_RUN )) && ! command_exists pnpm; then
    warn "Cannot install mdToPdf dependencies because pnpm is not available."
    return 1
  fi

  if ! (( DRY_RUN )) && ! command_exists node; then
    warn "Cannot install mdToPdf Puppeteer browser cache because node is not available."
    return 1
  fi

  log "Installing mdToPdf vendored dependencies."
  if ! run_mdtopdf_cmd_in_dir "$tool_dir" pnpm install --store-dir .pnpm-store; then
    warn "Failed to install mdToPdf pnpm dependencies."
    return 1
  fi

  if [[ -d "$tool_dir/node_modules/.pnpm" ]]; then
    puppeteer_install_script="$(
      find_mdtopdf_first_file "$tool_dir/node_modules/.pnpm" '*/node_modules/puppeteer/install.mjs'
    )"
  fi

  if [[ -z "$puppeteer_install_script" ]]; then
    if (( DRY_RUN )); then
      log "Installing mdToPdf Puppeteer browser cache."
      run_mdtopdf_cmd_in_dir "$tool_dir" env "PUPPETEER_CACHE_DIR=$tool_dir/.cache/puppeteer" node 'node_modules/.pnpm/<puppeteer>/node_modules/puppeteer/install.mjs'
      return 0
    fi

    warn "Cannot find Puppeteer install script under $tool_dir/node_modules/.pnpm."
    return 1
  fi

  log "Installing mdToPdf Puppeteer browser cache."
  if ! run_mdtopdf_cmd_in_dir "$tool_dir" env "PUPPETEER_CACHE_DIR=$tool_dir/.cache/puppeteer" node "$puppeteer_install_script"; then
    warn "Failed to install mdToPdf Puppeteer browser cache."
    return 1
  fi
}

install_mdtopdf_packages() {
  local distro="$1"
  shift

  local package
  for package in "$@"; do
    case "$package" in
      vendor-mdtopdf)
        install_mdtopdf_vendor_dependencies
        ;;
      *)
        warn "Unsupported mdToPdf custom package: $package"
        ;;
    esac
  done
}
