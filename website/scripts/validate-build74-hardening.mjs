import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const webRoot = process.cwd();

function read(relative) {
  return fs.readFileSync(path.join(root, relative), "utf8");
}

function walk(dir, extensions) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (["node_modules", ".next", "build", ".git"].includes(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(full, extensions));
    else if (extensions.some((ext) => entry.name.endsWith(ext))) out.push(full);
  }
  return out;
}

function assert(condition, message) {
  if (!condition) {
    console.error(`Build 74 validation failed: ${message}`);
    process.exit(1);
  }
}

const pubspec = read("pubspec.yaml");
assert(pubspec.includes("version: 4.3.0-alpha.26+83"), "Flutter version must be Build 74");
assert(!/^\s*[A-Za-z0-9_]+:\s*\^/m.test(pubspec), "direct Flutter dependencies must not use caret ranges");

const buildInfo = read("lib/app/build_info.dart");
const constants = read("lib/utils/constants.dart");
assert(buildInfo.includes("versionName = '4.3.0-alpha.26'") && buildInfo.includes("buildNumber = 83"), "AppBuildInfo must match Build 74");
assert(constants.includes("appVersion = '4.3.0-alpha.26'"), "appVersion must match Build 74");
const analyzerOptions = read("analysis_options.yaml");
assert(analyzerOptions.includes("avoid_print: error"), "Flutter analyzer must reject raw print logging");
assert(!analyzerOptions.includes("avoid_relative_lib_imports"), "hotfix lint baseline must not invalidate existing relative imports");
assert(read("lib/screens/settings/whats_new_screen.dart").includes("v4.3.0-alpha.20 · P1.26 Build 74"), "What's New must expose Build 74");

const gitignore = read(".gitignore");
assert(!/^\*\.lock\s*$/m.test(gitignore), "*.lock must not be ignored");
assert(fs.existsSync(path.join(root, "tools/verify_source_prerequisites.sh")), "source prerequisite shell check missing");
assert(fs.existsSync(path.join(root, "tools/verify_source_prerequisites.ps1")), "source prerequisite PowerShell check missing");

const dateUtils = read("website/src/utils/dateUtils.ts");
assert(dateUtils.includes("export function localDateKey"), "localDateKey utility missing");
assert(dateUtils.includes("getFullYear()") && dateUtils.includes("getMonth()") && dateUtils.includes("getDate()"), "localDateKey must use local calendar fields");
assert(!/localDateKey[\s\S]{0,800}toISOString\(/.test(dateUtils), "localDateKey must not convert through UTC");

const webSourceFiles = walk(path.join(webRoot, "src"), [".ts", ".tsx"]);
const utcBusinessDate = /toISOString\(\)\s*\.\s*(?:slice\(0\s*,\s*10\)|split\(["']T["']\)\[0\])/;
for (const file of webSourceFiles) {
  const source = fs.readFileSync(file, "utf8");
  assert(!utcBusinessDate.test(source), `UTC business date extraction remains in ${path.relative(webRoot, file)}`);
  assert(!/useStore\(\s*\)/.test(source), `broad Zustand subscription remains in ${path.relative(webRoot, file)}`);
  const rel = path.relative(webRoot, file).replaceAll("\\", "/");
  if (rel !== "src/lib/operationalLog.ts") {
    assert(!/console\.(?:error|warn|log|debug|info)\s*\(/.test(source), `raw browser console logging remains in ${rel}`);
  }
}

const operationalLog = read("website/src/lib/operationalLog.ts");
assert(operationalLog.includes('process.env.NODE_ENV === "production"'), "web production logging must be suppressed");
assert(!operationalLog.includes("shape.message"), "web operational logger must not emit raw error messages");

const cloudConfig = read("lib/services/cloud_config.dart");
const supabaseService = read("lib/services/supabase_service.dart");
assert(cloudConfig.includes("HALAQAH_ENV") && cloudConfig.includes("Production builds cannot fall back"), "strict CloudConfig environment policy missing");
assert(supabaseService.includes("CloudConfig.validate()"), "Supabase initialization must validate CloudConfig");

const dartFiles = walk(path.join(root, "lib"), [".dart"]);
for (const file of dartFiles) {
  const source = fs.readFileSync(file, "utf8");
  assert(!/\bprint\s*\(/.test(source), `print() remains in ${path.relative(root, file)}`);
}
const qrService = read("lib/services/qr_service.dart");
assert(!qrService.includes("HalaqahApp2024!"), "legacy QR secret must not be embedded");
assert(qrService.includes("HALAQAH_LEGACY_QR_SECRET"), "legacy QR must require an explicit migration secret");
assert(qrService.includes("_legacyMaxAge"), "legacy QR age validation missing");

const dbService = read("lib/services/database_service.dart");
const localSchema = read("lib/services/local_database_schema.dart");
assert(dbService.includes("LocalDatabaseSchema.version"), "DatabaseService must delegate schema lifecycle");
assert(localSchema.includes("static const int version = 27"), "SQLite schema version changed unexpectedly");
assert(dbService.split("\n").length < 5200, "DatabaseService modularization regressed");

const parents = read("website/src/app/parents/page.tsx");
for (const rpc of ["delete_family_atomic", "set_family_students_atomic", "save_family_guardian_atomic", "delete_family_guardian_atomic"]) {
  assert(parents.includes(rpc), `parents page is missing atomic RPC ${rpc}`);
}

const supervisionPage = read("website/src/app/supervision/page.tsx");
const onboarding = read("website/src/app/onboarding/page.tsx");
assert(supervisionPage.includes("fetchSupervisionHealth"), "supervision health diagnostic is not used");
assert(!supervisionPage.includes("تأكد من تنفيذ SQL المرحلة 7.3"), "old generic P7.3 error remains");
assert(!onboarding.includes("تأكد من تنفيذ SQL المرحلة P7.3"), "old onboarding P7.3 error remains");

const supervisionSql = read("website/supabase/migrations/20260812000100_build74_supervision_hardening.sql");
for (const contract of ["uq_supervisor_members_supervisor_user", "get_supervision_health", "ensure_supervisor_owner_membership", "supervision_visits"]) {
  assert(supervisionSql.includes(contract), `supervision repair contract missing: ${contract}`);
}
const atomicSql = read("website/supabase/migrations/20260812000200_build74_atomic_family_operations.sql");
for (const rpc of ["delete_family_atomic", "set_family_students_atomic", "save_family_guardian_atomic", "delete_family_guardian_atomic"]) {
  assert(atomicSql.includes(`FUNCTION public.${rpc}`), `atomic SQL function missing: ${rpc}`);
}
assert(atomicSql.includes("REVOKE ALL ON FUNCTION public.delete_family_atomic"), "atomic RPC privileges are not hardened");

// Every SECURITY DEFINER function in shipped Supabase SQL must pin a search_path
// that includes pg_temp. This is a source-level guard; Build 74 also ships a
// database-level read-only verifier for the deployed instance.
const sqlFiles = walk(path.join(webRoot, "supabase"), [".sql"]);
for (const file of sqlFiles) {
  const source = fs.readFileSync(file, "utf8");
  const functionStart = /CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\b/gi;
  for (const match of source.matchAll(functionStart)) {
    const tail = source.slice(match.index);
    const marker = tail.indexOf("AS $$");
    const header = tail.slice(0, marker >= 0 ? marker : Math.min(tail.length, 3000));
    if (/SECURITY\s+DEFINER/i.test(header)) {
      const searchPath = header.match(/SET\s+search_path\s*=([^\n]+)/i)?.[1] ?? "";
      assert(searchPath.toLowerCase().includes("pg_temp"), `SECURITY DEFINER without pg_temp search_path in ${path.relative(webRoot, file)}`);
    }
  }
}

assert(fs.existsSync(path.join(root, "docs/supported_platforms.md")), "supported platform policy missing");
assert(fs.existsSync(path.join(root, "P1.26_BUILD74_INSTALL_NOTE.md")), "Build 74 install note missing");
assert(fs.existsSync(path.join(webRoot, "scripts/test-build74-runtime.mjs")), "Build 74 runtime test missing");
assert(fs.existsSync(path.join(webRoot, "supabase/P1.26_BUILD74_APPLY.sql")), "consolidated Build 74 SQL apply file missing");
assert(fs.existsSync(path.join(webRoot, "supabase/P1.26_BUILD74_VERIFY.sql")), "consolidated Build 74 SQL verify file missing");

console.log("Build 74 hardening validation passed.");
