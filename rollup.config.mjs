import { readdirSync, statSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { join, parse, relative, sep, dirname } from "path";
import { execSync } from "child_process";
import typescript from "@rollup/plugin-typescript";
import resolve from "@rollup/plugin-node-resolve";
import commonjs from "@rollup/plugin-commonjs";
import postcss from "rollup-plugin-postcss";
import postcssImport from "postcss-import";
import postcssUrl from "postcss-url";
import copy from "rollup-plugin-copy";
import * as sass from "sass";
import tailwindcss from "tailwindcss";
import autoprefixer from "autoprefixer";
import remToPixel from "postcss-rem-to-pixel";

// Automatically scan all .ts files in the src/entrypoints directory
function getEntryPoints(dir) {
  const entries = [];

  function scanDir(currentDir) {
    const files = readdirSync(currentDir);

    for (const file of files) {
      const fullPath = join(currentDir, file);
      const stat = statSync(fullPath);

      if (stat.isDirectory()) {
        scanDir(fullPath);
      } else if (file.endsWith(".ts") && !file.endsWith(".d.ts")) {
        entries.push(fullPath);
      }
    }
  }

  scanDir(dir);
  return entries;
}

// Generate output filename based on entry file path
function getOutputFileName(entryPath) {
  const relativePath = relative("src/entrypoints", entryPath);
  const parsed = parse(relativePath);

  // Handle path separators and convert path to filename
  const pathParts = parsed.dir.split(sep).filter(Boolean);

  if (pathParts.length > 0) {
    // If in a subdirectory, use directory name as filename
    // Example: friends/index.ts -> friends.custom.js
    return pathParts[pathParts.length - 1];
  } else {
    // If in root directory, use filename
    // Example: libraryroot.ts -> libraryroot.custom.js
    return parsed.name;
  }
}

// Ensure CSS file exists plugin
function ensureCssFile(cssFileName) {
  return {
    name: "ensure-css-file",
    writeBundle() {
      const cssPath = join("dist", cssFileName);
      if (!existsSync(cssPath)) {
        const distDir = dirname(cssPath);
        if (!existsSync(distDir)) {
          mkdirSync(distDir, { recursive: true });
        }
        writeFileSync(cssPath, "", "utf-8");
        console.log(`[ensure-css-file] Created empty CSS file: ${cssFileName}`);
      }
    },
  };
}

// Auto relink plugin
function autoRelink() {
  return {
    name: "auto-relink",
    writeBundle() {
      console.log("\n[auto-relink] Build complete, executing relink...");
      try {
        execSync(
          "powershell -ExecutionPolicy Bypass -File ./scripts/symlink.ps1 -Action relink",
          {
            stdio: "inherit",
            cwd: process.cwd(),
          }
        );
        console.log("[auto-relink] Relink completed successfully\n");
      } catch (error) {
        console.error("[auto-relink] Relink failed:", error.message);
      }
    },
  };
}

const entryPoints = getEntryPoints("src/entrypoints");

// Create a configuration for each entry file
const configs = entryPoints.map((entry, index) => {
  const outputName = getOutputFileName(entry);

  return {
    input: entry,
    output: {
      file: `dist/${outputName}.custom.js`,
      format: "iife",
      sourcemap: true,
    },
    plugins: [
      resolve({
        browser: true,
      }),
      commonjs(),
      typescript({
        tsconfig: "./tsconfig.json",
        sourceMap: true,
      }),
      postcss({
        extract: `${outputName}.custom.css`,
        minimize: process.env.NODE_ENV === "production",
        sourceMap: true,
        use: {
          sass: {
            implementation: sass,
            silenceDeprecations: ['legacy-js-api'],
          },
        },
        plugins: [
          postcssImport(),
          tailwindcss(),
          autoprefixer(),
          remToPixel({
            propList: ['*'],
          }),
          postcssUrl({
            url: "inline",
          }),
        ],
      }),
      ensureCssFile(`${outputName}.custom.css`),
      autoRelink(),
      copy({
        targets: [{ src: "skin.json", dest: "dist" }],
        hook: "writeBundle",
      }),
    ],
  };
});

export default configs;
