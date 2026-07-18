import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const requireText = (source, values, label) => {
  for (const value of values) {
    if (!source.includes(value)) {
      throw new Error(`${label}: missing ${value}`);
    }
  }
};

const verifier = read("tools/verify_release_checksum.ps1");
requireText(
  verifier,
  [
    "Get-FileHash",
    "-Algorithm SHA256",
    "Use either -ChecksumPath or -ExpectedHash",
    "The checksum belongs to",
    "Do not extract or install this file",
    "SHA-256 verification passed",
  ],
  "Windows SHA-256 verifier",
);

const preflight = read("tools/staging_preflight.ps1");
requireText(
  preflight,
  [
    "build\\release-artifacts",
    "halaqah-rc2-$safeVersion.apk",
    "$artifactPath.sha256",
    "Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256",
    "P6.5 RC2 staging preflight passed",
  ],
  "RC2 preflight artifacts",
);

const guide = read("docs/release_checksum_guide_ar.md");
requireText(
  guide,
  [
    "لا تستبدل",
    "Get-FileHash",
    "verify_release_checksum.ps1",
    "إذا اختلفت البصمتان",
    "أرشيف الإصدارات",
  ],
  "Arabic checksum guide",
);

console.log("P6.5 release-integrity and checksum contract passed.");
