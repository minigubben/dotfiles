#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <input-dir> [output-dir] [extra-cli-options...]"
  echo ""
  echo "Examples:"
  echo "  $0 ./docs"
  echo "  $0 ./docs ./pdf"
  echo "  $0 ./docs ./pdf --pattern \"**/*.{md,markdown}\""
  exit 1
fi

input_dir="$1"
shift

if [[ $# -gt 0 && "$1" != --* ]]; then
  output_dir="$1"
  shift
  pnpm run convert -- --input "$input_dir" --output "$output_dir" "$@"
else
  pnpm run convert -- --input "$input_dir" "$@"
fi
