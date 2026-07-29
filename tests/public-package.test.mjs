import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, readdirSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { extname, join, relative, resolve } from "node:path";
import test from "node:test";

const root = resolve(import.meta.dirname, "..");

function walk(directory) {
  return readdirSync(directory).flatMap((name) => {
    const path = join(directory, name);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });
}

test("Java core compiles and behavioral contracts pass", () => {
  const build = mkdtempSync(join(tmpdir(), "speedplus-public-"));
  try {
    const sources = walk(join(root, "src", "main", "java"))
      .filter((path) => path.endsWith(".java"));
    execFileSync("javac", ["-source", "8", "-target", "8", "-d", build, ...sources,
      join(root, "tests", "CoreContractTest.java")], { stdio: "pipe" });
    const output = execFileSync("java", ["-cp", build, "CoreContractTest"], {
      encoding: "utf8"
    });
    assert.match(output, /PASS/);
  } finally {
    rmSync(build, { recursive: true, force: true });
  }
});

test("all JSON schemas and examples parse", () => {
  const files = [
    ...walk(join(root, "schemas")),
    ...walk(join(root, "examples")).filter((path) => path.endsWith(".json"))
  ];
  for (const file of files) {
    assert.doesNotThrow(() => JSON.parse(readFileSync(file, "utf8")),
      `${relative(root, file)} must be valid JSON`);
  }
});

test("public tree excludes binaries, local paths, and common secrets", () => {
  const forbiddenExtensions = new Set([
    ".apk", ".aab", ".ipa", ".dex", ".jar", ".jks", ".keystore", ".p12",
    ".mobileprovision", ".so", ".class"
  ]);
  const textExtensions = new Set([
    ".java", ".json", ".md", ".yaml", ".yml", ".txt", ".xml", ".properties"
  ]);
  const forbiddenPatterns = [
    /(?:C:\\|C:\/)Users[\\/]/i,
    /\/Users\/[^/]+\//,
    /\/home\/[^/]+\//,
    /BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY/,
    /(?:password|passwd|token|api[_-]?key|client[_-]?secret)\s*[:=]\s*["'][^"']{6,}["']/i,
    /ssh-(?:rsa|ed25519)\s+[A-Za-z0-9+/]{80,}/
  ];

  for (const file of walk(root)) {
    const rel = relative(root, file).replaceAll("\\", "/");
    if (rel.startsWith(".git/") || rel.startsWith(".build/")) continue;
    assert.ok(!forbiddenExtensions.has(extname(file).toLowerCase()),
      `${rel} is a forbidden binary type`);
    if (textExtensions.has(extname(file).toLowerCase()) || !extname(file)) {
      const text = readFileSync(file, "utf8");
      for (const pattern of forbiddenPatterns) {
        assert.ok(!pattern.test(text), `${rel} matched forbidden pattern ${pattern}`);
      }
    }
  }
});

test("third-party package namespaces are absent from source", () => {
  const sourceText = walk(join(root, "src"))
    .map((path) => readFileSync(path, "utf8"))
    .join("\n");
  assert.doesNotMatch(sourceText, /\bcom\.ookla\b/i);
});
