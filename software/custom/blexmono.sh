#!/usr/bin/env bash

install_blexmono_from_nerd_fonts() {
  local font_name="$1"
  local font_dir="$HOME/.local/share/fonts/${font_name}NerdFont"
  local repo_dir font_source_dir installed_count

  if ! (( INSTALL_THIRD_PARTY )); then
    warn "Skipping Nerd Fonts download because --no-third-party was used: $font_name"
    return 0
  fi

  if (( DRY_RUN )); then
    printf '+ mkdir -p %q\n' "$font_dir"
    printf '+ git clone --depth 1 --filter=blob:none --sparse https://github.com/ryanoasis/nerd-fonts.git /tmp/nerd-fonts\n'
    printf '+ git -C /tmp/nerd-fonts sparse-checkout set patched-fonts/IBMPlexMono/Mono\n'
    printf '+ cp /tmp/nerd-fonts/patched-fonts/IBMPlexMono/Mono/BlexMonoNerdFont*.ttf %q\n' "$font_dir"
    printf '+ fc-cache -f %q\n' "$font_dir"
    return 0
  fi

  repo_dir="$(mktemp -d)"
  font_source_dir="$repo_dir/patched-fonts/IBMPlexMono/Mono"

  if ! git clone --depth 1 --filter=blob:none --sparse https://github.com/ryanoasis/nerd-fonts.git "$repo_dir"; then
    rm -rf "$repo_dir"
    return 1
  fi

  if ! git -C "$repo_dir" sparse-checkout set patched-fonts/IBMPlexMono/Mono; then
    rm -rf "$repo_dir"
    return 1
  fi

  mkdir -p "$font_dir"
  installed_count=0
  while IFS= read -r font_file; do
    cp "$font_file" "$font_dir/"
    installed_count=$((installed_count + 1))
  done < <(find "$font_source_dir" -type f -name 'BlexMonoNerdFont*.ttf')

  rm -rf "$repo_dir"

  if (( installed_count == 0 )); then
    warn "No BlexMono Nerd Font files were found in the Nerd Fonts repository."
    return 1
  fi

  if command_exists fc-cache; then
    fc-cache -f "$font_dir"
  else
    warn "fc-cache was not found; font cache was not refreshed for $font_name."
  fi
}

install_blexmono_packages() {
  local _distro="$1"
  shift

  local package
  for package in "$@"; do
    case "$package" in
      BlexMono|blexmono)
        if ! install_blexmono_from_nerd_fonts BlexMono; then
          warn "Failed to install BlexMono Nerd Font."
        fi
        ;;
      *)
        warn "Unsupported BlexMono custom package: $package"
        ;;
    esac
  done
}
