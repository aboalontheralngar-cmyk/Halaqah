import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
function read(relative) {
  return fs.readFileSync(path.join(root, relative), "utf8");
}
function assert(condition, message) {
  if (!condition) {
    console.error(`Build 75 Hotfix 2 validation failed: ${message}`);
    process.exit(1);
  }
}

const pubspec = read("pubspec.yaml");
const requiredPins = [
  "sdk: \">=3.3.0 <4.0.0\"",
  "sqflite: 2.4.2+1",
  "path: 1.9.1",
  "path_provider: 2.1.5",
  "pdf: 3.12.0",
  "printing: 5.14.3",
  "shared_preferences: 2.5.5",
  "uuid: 4.5.3",
  "crypto: 3.0.7",
  "image_picker: 1.2.2",
  "supabase_flutter: 2.14.2",
  "flutter_contacts: 1.1.9+2",
];
for (const pin of requiredPins) assert(pubspec.includes(pin), `missing dependency pin: ${pin}`);

const datePickerFiles = [
  "lib/screens/memorization/add_memorization_screen.dart",
  "lib/screens/memorization/recitation_screen.dart",
  "lib/screens/memorization/revision_screen.dart",
];
for (const file of datePickerFiles) {
  const source = read(file);
  assert(source.includes("confirmText: 'اعتماد'"), `${file} must use showDatePicker confirmText`);
  assert(!source.includes("saveText: 'اعتماد'"), `${file} must not use invalid showDatePicker saveText`);
}

const monthly = read("lib/screens/exam/monthly_plan_exam_screen.dart");
assert(monthly.includes("FontWeight.w900"), "monthly plan exam must use FontWeight.w900");
assert(!monthly.includes("FontWeight.black"), "FontWeight.black must not return");
assert(monthly.includes("initialValue: _plan?.id"), "monthly plan dropdown should use initialValue");

const supabase = read("lib/services/supabase_service.dart");
assert(supabase.includes("publishableKey: publishableKey"), "Supabase must keep publishableKey API with 2.14.2");

const plans = read("lib/screens/plans/plans_screen.dart");
assert(!plans.includes("package:intl/intl.dart' as intl"), "unused plans intl import must stay removed");

const studentForm = read("lib/screens/students/student_form_screen.dart");
assert(!studentForm.includes(".map((num) =>"), "callback parameter named num must stay removed");

console.log("Build 75 Hotfix 2 Flutter compile-regression validation passed.");
