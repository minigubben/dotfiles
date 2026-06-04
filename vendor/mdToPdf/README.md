# md-folder-to-pdf

Convert a folder of Markdown files to PDF files using Node.js and pnpm.

Mermaid diagrams in fenced code blocks are rendered automatically during PDF generation.

## Requirements

- Node.js 18+
- pnpm

## Install

```bash
pnpm install
```

Install Chrome for Puppeteer (required by `md-to-pdf`):

```bash
pnpm dlx puppeteer browsers install chrome
```

In this dotfiles copy, keep the Puppeteer browser cache local to the vendored tool and install the Chrome revision expected by the locked dependency:

```bash
PUPPETEER_CACHE_DIR="$PWD/.cache/puppeteer" node node_modules/.pnpm/puppeteer@24.37.2/node_modules/puppeteer/install.mjs
```

## Usage

Recursive conversion is enabled by default.

```bash
pnpm run convert -- --input ./docs
```

Output defaults to `./docs/pdf`.

### Bash wrapper

If you prefer a simpler bash command:

```bash
./convert-md-folder.sh ./docs
./convert-md-folder.sh ./docs ./pdf
```

You can pass extra options after the directories:

```bash
./convert-md-folder.sh ./docs ./pdf --pattern "**/*.{md,markdown}"
```

### Common options

```bash
# Set custom output directory
pnpm run convert -- --input ./docs --output ./pdf

# Disable recursive scan
pnpm run convert -- --input ./docs --no-recursive

# Use a custom glob pattern
pnpm run convert -- --input ./docs --pattern "**/*.{md,markdown}"
```

## CLI help

```bash
pnpm run convert -- --help
```

## Notes

- Folder structure is preserved in the output directory.
- If any file fails to convert, the tool continues processing other files and exits with code `1`.
- If you see a "Could not find Chrome" error, run the browser install command above.
- Mermaid fences such as ```` ```mermaid ```` are rendered as diagrams in the generated PDF.
