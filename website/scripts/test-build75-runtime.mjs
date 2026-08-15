import fs from "node:fs";
import path from "node:path";
import ts from "typescript";

const root = path.resolve(import.meta.dirname, "../..");

function loadSupervisionWithStub(stub) {
  const filename = path.join(root, "website/src/services/supervisionService.ts");
  const source = fs.readFileSync(filename, "utf8").replace(
    /import\s+\{\s*supabase\s*\}\s+from\s+["']@\/lib\/supabase["'];?\s*/,
    "const supabase: any = globalThis.__build75Supabase;\n",
  );
  const transpiled = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS },
    fileName: filename,
    reportDiagnostics: true,
  });
  const errors = (transpiled.diagnostics ?? []).filter((d) => d.category === ts.DiagnosticCategory.Error);
  if (errors.length) throw new Error(errors.map((d) => ts.flattenDiagnosticMessageText(d.messageText, " ")).join("\n"));
  globalThis.__build75Supabase = stub;
  const module = { exports: {} };
  new Function("exports", "module", "require", transpiled.outputText)(module.exports, module, () => { throw new Error("unexpected import"); });
  return module.exports;
}

function assert(condition, label) {
  if (!condition) throw new Error(label);
}

let called = null;
const service = loadSupervisionWithStub({
  rpc(name, params) {
    called = { name, params };
    return Promise.resolve({ data: { success: true, center: { id: "c1" } }, error: null });
  },
});

const result = await service.createSupervisedCenter({
  supervisorId: "s1",
  name: "مركز اختبار",
  type: "men",
  address: "صنعاء",
  halaqahName: "حلقة الفجر",
  teacherName: "المعلم",
});
assert(result.error === null && result.data?.success === true, "direct center creation result contract");
assert(called?.name === "create_supervised_center", "direct center creation must call create_supervised_center");
assert(called?.params?.p_supervisor_id === "s1" && called?.params?.p_name === "مركز اختبار", "direct center creation parameters");

assert(service.supervisionErrorCode({ message: "supervisor_manager_required" }) === "manager_required", "manager-required error mapping");
assert(service.supervisionErrorCode({ message: "supervisor_not_found" }) === "supervisor_not_found", "supervisor-not-found mapping");
assert(service.supervisionErrorCode({ code: "PGRST202" }) === "rpc_missing", "missing SQL mapping");
const managerMessage = service.supervisionErrorMessage({ message: "supervisor_manager_required" }, null);
assert(managerMessage.includes("مالك") || managerMessage.includes("إداري"), "manager error should be actionable Arabic");

console.log("Build 75 runtime contract tests passed: direct supervision center creation and diagnostics.");
