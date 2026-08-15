import fs from "node:fs";
import path from "node:path";
import ts from "typescript";

const root = path.resolve(import.meta.dirname, "../..");

function loadTypescriptModule(relativePath, transform = (source) => source) {
  const filename = path.join(root, relativePath);
  const source = transform(fs.readFileSync(filename, "utf8"));
  const transpiled = ts.transpileModule(source, {
    compilerOptions: {
      target: ts.ScriptTarget.ES2022,
      module: ts.ModuleKind.CommonJS,
      esModuleInterop: true,
    },
    fileName: filename,
    reportDiagnostics: true,
  });
  const syntaxErrors = (transpiled.diagnostics ?? []).filter(
    (diagnostic) => diagnostic.category === ts.DiagnosticCategory.Error,
  );
  if (syntaxErrors.length) {
    const message = syntaxErrors
      .map((diagnostic) => ts.flattenDiagnosticMessageText(diagnostic.messageText, " "))
      .join("\n");
    throw new Error(`${relativePath}: ${message}`);
  }

  const module = { exports: {} };
  const fn = new Function("exports", "module", "require", transpiled.outputText);
  fn(module.exports, module, () => {
    throw new Error(`Unexpected runtime import while testing ${relativePath}`);
  });
  return module.exports;
}

function assertEqual(actual, expected, label) {
  if (actual !== expected) {
    throw new Error(`${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

// A UTC timestamp that is already the next calendar day in Yemen (+03).
process.env.TZ = "Asia/Aden";
const dateUtils = loadTypescriptModule("website/src/utils/dateUtils.ts");
const afterMidnightYemen = new Date("2026-08-11T21:30:00.000Z");
assertEqual(
  dateUtils.localDateKey(afterMidnightYemen),
  "2026-08-12",
  "localDateKey must preserve the Yemen business date across UTC midnight",
);
assertEqual(
  dateUtils.localDateKeyOffset(-1, afterMidnightYemen),
  "2026-08-11",
  "localDateKeyOffset must move calendar days locally",
);
const reconstructed = dateUtils.localDateFromKey("2026-08-12");
assertEqual(dateUtils.localDateKey(reconstructed), "2026-08-12", "local date round-trip");

const supervision = loadTypescriptModule(
  "website/src/services/supervisionService.ts",
  (source) => source.replace(
    /import\s+\{\s*supabase\s*\}\s+from\s+["']@\/lib\/supabase["'];?\s*/,
    "const supabase: any = null;\n",
  ),
);
assertEqual(supervision.supervisionErrorCode({ code: "42501" }), "permission_denied", "permission mapping");
assertEqual(supervision.supervisionErrorCode({ code: "PGRST202" }), "rpc_missing", "missing RPC mapping");
assertEqual(
  supervision.supervisionErrorCode({ message: "invalid_or_expired_member_invitation" }),
  "invalid_invitation",
  "invitation mapping",
);
const missingContractMessage = supervision.supervisionErrorMessage({ code: "PGRST202" }, null);
if (!missingContractMessage.includes("Build 76")) {
  throw new Error("missing-contract supervision message must point to the current Build 76 repair");
}
const membershipMessage = supervision.supervisionErrorMessage(
  { code: "UNCLASSIFIED" },
  { authenticated: true, owned_organizations: 0, active_memberships: 0, ready: false },
);
if (!membershipMessage.includes("عضوًا نشطًا")) {
  throw new Error("unready-account message must distinguish membership from missing SQL");
}

console.log("Runtime behavior tests passed: local business dates and current supervision error diagnostics.");
