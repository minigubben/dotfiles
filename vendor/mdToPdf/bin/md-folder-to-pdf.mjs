#!/usr/bin/env node

import path from "node:path";
import fs from "node:fs/promises";
import process from "node:process";
import { fileURLToPath } from "node:url";
import fg from "fast-glob";
import { mdToPdf } from "md-to-pdf";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectDir = path.resolve(scriptDir, "..");
process.env.PUPPETEER_CACHE_DIR ??= path.join(projectDir, ".cache", "puppeteer");
const mermaidScriptPath = path.resolve(scriptDir, "../node_modules/mermaid/dist/mermaid.min.js");
const mermaidCss = `
.mermaid {
  display: flex;
  justify-content: center;
  margin: 1.5rem 0;
}

.mermaid svg {
  height: auto;
  max-width: 100%;
}
`;
const mermaidInitScript = `
if (document.querySelector(".mermaid")) {
  mermaid.initialize({
    startOnLoad: false,
    securityLevel: "loose"
  });

  mermaid.run({
    querySelector: ".mermaid"
  });
}
`;

function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function createMermaidExtension() {
  return {
    renderer: {
      code(token) {
        if (token.lang?.trim().toLowerCase() !== "mermaid") {
          return false;
        }

        return `<pre class="mermaid">${escapeHtml(token.text ?? "")}</pre>`;
      }
    }
  };
}

function printHelp() {
  console.log(`
Usage:
  md-folder-to-pdf --input <dir> [--output <dir>] [--pattern <glob>] [--no-recursive]

Options:
  --input, -i        Input folder containing markdown files (required)
  --output, -o       Output folder for generated PDFs (default: <input>/pdf)
  --pattern, -p      Custom glob pattern for markdown files
  --no-recursive     Disable recursive search (recursive is on by default)
  --help, -h         Show this help

Examples:
  md-folder-to-pdf -i ./docs
  md-folder-to-pdf -i ./docs -o ./pdf
  md-folder-to-pdf -i ./docs --no-recursive
  md-folder-to-pdf -i ./docs -p "**/*.{md,markdown}"
`);
}

function parseArgs(argv) {
  const options = {
    recursive: true,
    input: "",
    output: "",
    pattern: ""
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];

    if (arg === "--help" || arg === "-h") {
      options.help = true;
      continue;
    }

    if (arg === "--no-recursive") {
      options.recursive = false;
      continue;
    }

    if (arg === "--recursive") {
      options.recursive = true;
      continue;
    }

    if (arg === "--input" || arg === "-i") {
      options.input = argv[i + 1] ?? "";
      i += 1;
      continue;
    }

    if (arg === "--output" || arg === "-o") {
      options.output = argv[i + 1] ?? "";
      i += 1;
      continue;
    }

    if (arg === "--pattern" || arg === "-p") {
      options.pattern = argv[i + 1] ?? "";
      i += 1;
      continue;
    }
  }

  return options;
}

function toPosixRelative(fromAbs, toAbs) {
  return path.relative(fromAbs, toAbs).split(path.sep).join(path.posix.sep);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.help) {
    printHelp();
    process.exit(0);
  }

  if (!args.input) {
    console.error("Error: --input is required.");
    printHelp();
    process.exit(1);
  }

  const inputDir = path.resolve(args.input);
  const outputDir = path.resolve(args.output || path.join(inputDir, "pdf"));

  let inputStat;
  try {
    inputStat = await fs.stat(inputDir);
  } catch {
    console.error(`Error: input folder does not exist: ${inputDir}`);
    process.exit(1);
  }

  if (!inputStat.isDirectory()) {
    console.error(`Error: input path is not a directory: ${inputDir}`);
    process.exit(1);
  }

  await fs.mkdir(outputDir, { recursive: true });

  const defaultPattern = args.recursive ? "**/*.md" : "*.md";
  const pattern = args.pattern || defaultPattern;

  const files = await fg(pattern, {
    cwd: inputDir,
    onlyFiles: true,
    absolute: true,
    caseSensitiveMatch: false
  });

  if (files.length === 0) {
    console.log(`No files matched pattern "${pattern}" in ${inputDir}`);
    process.exit(0);
  }

  let success = 0;
  let failed = 0;
  let browserHintShown = false;

  console.log(`Found ${files.length} markdown file(s).`);
  console.log(`Input:  ${inputDir}`);
  console.log(`Output: ${outputDir}`);
  console.log("");

  for (const file of files) {
    const relativePath = toPosixRelative(inputDir, file);
    const pdfRelativePath = relativePath.replace(/\.[^.]+$/, ".pdf");
    const outputFilePath = path.join(outputDir, pdfRelativePath);

    try {
      await fs.mkdir(path.dirname(outputFilePath), { recursive: true });

      const result = await mdToPdf(
        { path: file },
        {
          dest: outputFilePath,
          css: mermaidCss,
          script: [
            { path: mermaidScriptPath },
            { content: mermaidInitScript }
          ],
          marked_extensions: [createMermaidExtension()]
        }
      );

      if (!result) {
        throw new Error("md-to-pdf returned no result");
      }

      success += 1;
      console.log(`OK   ${relativePath} -> ${toPosixRelative(outputDir, outputFilePath)}`);
    } catch (error) {
      failed += 1;
      const message = error instanceof Error ? error.message : String(error);
      console.error(`FAIL ${relativePath}: ${message}`);

      if (!browserHintShown && message.includes("Could not find Chrome")) {
        browserHintShown = true;
        console.error("");
        console.error("Tip: install a browser for Puppeteer and retry:");
        console.error("  pnpm dlx puppeteer browsers install chrome");
      }
    }
  }

  console.log("");
  console.log(`Done. Success: ${success}, Failed: ${failed}`);

  if (failed > 0) {
    process.exit(1);
  }
}

main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`Fatal: ${message}`);
  process.exit(1);
});
