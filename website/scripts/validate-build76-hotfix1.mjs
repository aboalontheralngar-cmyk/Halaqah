import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const assert = (condition, message) => {
  if (!condition) {
    console.error(`Build 76 Hotfix 1 validation failed: ${message}`);
    process.exit(1);
  }
};

const peer = read("lib/screens/competition/peer_level_groups_screen.dart");
assert(
  peer.includes("final total = _ayahCount(ranges.values);"),
  "peer-group memorized total must stay int-safe",
);
assert(
  !peer.includes("void _regroup(value)"),
  "peer-group dropdown callback contains invalid Dart syntax",
);
assert(
  peer.includes("if (value != null) {\n                                  _regroup(value);"),
  "peer-group dropdown no longer calls regroup safely",
);

const memorization = read("lib/screens/memorization/memorization_screen.dart");
assert(
  memorization.includes("import '../../app/theme.dart';"),
  "memorization screen is missing AppSemanticColors theme import",
);

console.log("Build 76 Hotfix 1 Flutter compile-regression validation passed.");
