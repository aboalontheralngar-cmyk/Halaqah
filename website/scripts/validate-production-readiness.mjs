import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");

const assertIncludes = (source, values, label) => {
  for (const value of values) {
    if (!source.includes(value)) throw new Error(`${label}: missing ${value}`);
  }
};

const nextConfig = read("website/next.config.ts");
assertIncludes(
  nextConfig,
  [
    "poweredByHeader: false",
    "Content-Security-Policy",
    "frame-ancestors 'none'",
    "X-Content-Type-Options",
    "Permissions-Policy",
    "Strict-Transport-Security",
    "wss://*.supabase.co",
  ],
  "Next security headers",
);

const supabaseClient = read("website/src/lib/supabase.ts");
assertIncludes(
  supabaseClient,
  ["isSafeSupabaseUrl", "persistSession: true", "autoRefreshToken: true", "supabaseConfiguration"],
  "Supabase client hardening",
);
if (/service[_-]?role/i.test(supabaseClient)) {
  throw new Error("Supabase client must never reference a service-role key");
}

const envExample = read("website/.env.example");
assertIncludes(envExample, ["NEXT_PUBLIC_SUPABASE_URL", "NEXT_PUBLIC_SUPABASE_ANON_KEY"], "Environment example");

const packageJson = JSON.parse(read("website/package.json"));
if (packageJson.dependencies.next !== "16.2.10") throw new Error("Next.js security patch is not pinned");
if (packageJson.dependencies["@supabase/supabase-js"] !== "2.110.2") {
  throw new Error("Supabase JS security patch is not pinned");
}
assertIncludes(
  JSON.stringify(packageJson.scripts),
  ["audit:production", "--audit-level=high", "--max-warnings 23"],
  "Release scripts",
);

for (const file of ["error.tsx", "global-error.tsx", "not-found.tsx"]) {
  const source = read(`website/src/app/${file}`);
  assertIncludes(source, ["dir=\"rtl\""], `Resilience page ${file}`);
}

const qualityWorkflow = read(".github/workflows/quality.yml");
assertIncludes(
  qualityWorkflow,
  ["permissions:", "contents: read", "npm ci", "npm run quality:ci", "flutter analyze", "flutter test"],
  "Quality workflow",
);

const releaseWorkflow = read(".github/workflows/build-apk.yml");
assertIncludes(releaseWorkflow, ["java-version: '17'", "channel: stable", "actions/upload-artifact@v4"], "APK workflow");

console.log("P6.1 production-readiness contract passed.");
