# Build 79 Validation Report

## Identity

- P1.27 Build 79
- `4.3.0-alpha.25+79`
- SQLite 26 unchanged
- no new Supabase SQL

## Static and contract validation

- 67/67 project release validators passed after Build 79 changes.
- Build 79 validator covers the eight Flutter compile regressions reported by the owner, release-size configuration, split APK/AAB packaging, unused dependency removal, and suspension-sync timeout/retry behavior.
- `tools/build_lean_android.sh` passes Bash syntax validation.
- new JSON configuration files parse successfully.
- GitHub Android workflow parses as YAML.
- Build 79 Node validator passes syntax/runtime execution.

## Android optimization state

Already present before Build 79:

- R8 minification;
- Android resource shrinking;
- optimized ProGuard defaults;
- manual split-per-ABI helper.

Added or completed in Build 79:

- AGP 8.7 optimized resource shrinking;
- split APK + AAB in the official GitHub release workflow;
- automated size report and baseline candidate;
- SHA-256 for all release artifacts;
- removal of unused `cupertino_icons`, `image_picker`, and `flutter_slidable` direct dependencies;
- analyze/test gates inside the lean Android release helpers.

## Runtime acceptance not executed here

The packaging environment does not contain Flutter/Dart SDK or the owner's Android signing keys, so this report does not claim that Build 79 has passed the owner's real:

- `flutter analyze`;
- `flutter test`;
- Android release build;
- device installation;
- exact APK size measurement.

Those are required before release acceptance.

## Package verification

- full source package: 736 files;
- modified-files-only package: 60 files;
- both ZIP archives pass `unzip -t`;
- all 60 modified-package files match the Build 79 working tree byte-for-byte;
- no `node_modules`, build outputs, environment secrets, private keys, or database files are intentionally included.
