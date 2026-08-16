import 'dart:convert';
import 'dart:io';

const _mib = 1024 * 1024;

void main(List<String> args) {
  final outputDirectory = Directory('build/release-artifacts');
  outputDirectory.createSync(recursive: true);

  final baselinePath = _argValue(args, '--baseline') ??
      'tools/android_size_baseline.json';
  final maxGrowthPercent = double.tryParse(
    _argValue(args, '--max-growth-percent') ??
        Platform.environment['HALAQAH_MAX_SIZE_GROWTH_PERCENT'] ??
        '5',
  ) ?? 5;
  final enforceBudget = args.contains('--enforce-budget') ||
      Platform.environment['HALAQAH_ENFORCE_SIZE_BUDGET'] == 'true';

  final artifacts = <File>[];
  for (final rootPath in [
    'build/app/outputs/flutter-apk',
    'build/app/outputs/bundle/release',
  ]) {
    final root = Directory(rootPath);
    if (!root.existsSync()) continue;
    artifacts.addAll(
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.apk') || file.path.endsWith('.aab')),
    );
  }

  if (artifacts.isEmpty) {
    stderr.writeln('No Android release APK/AAB artifacts were found.');
    exitCode = 2;
    return;
  }

  artifacts.sort((a, b) => a.path.compareTo(b.path));
  final baseline = _readBaseline(File(baselinePath));
  final rows = <Map<String, Object?>>[];
  var budgetFailed = false;

  for (final artifact in artifacts) {
    final name = artifact.uri.pathSegments.last;
    final bytes = artifact.lengthSync();
    final sizeMiB = bytes / _mib;
    final baselineBytes = baseline[name];
    double? changePercent;
    if (baselineBytes != null && baselineBytes > 0) {
      changePercent = ((bytes - baselineBytes) / baselineBytes) * 100;
      if (changePercent > maxGrowthPercent) budgetFailed = true;
    }
    rows.add({
      'name': name,
      'bytes': bytes,
      'mib': double.parse(sizeMiB.toStringAsFixed(2)),
      if (baselineBytes != null) 'baseline_bytes': baselineBytes,
      if (changePercent != null)
        'change_percent': double.parse(changePercent.toStringAsFixed(2)),
    });
  }

  final report = <String, Object?>{
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'baseline_file': baselinePath,
    'baseline_present': baseline.isNotEmpty,
    'max_growth_percent': maxGrowthPercent,
    'artifacts': rows,
  };

  File('${outputDirectory.path}/android-size-report.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  File('${outputDirectory.path}/android-size-report.md')
      .writeAsStringSync(_markdown(rows, baseline.isNotEmpty, maxGrowthPercent));

  // A baseline candidate is emitted on every build. Commit it only after a
  // real production release is accepted; later CI runs can then detect bloat.
  final candidate = {
    for (final row in rows) row['name'] as String: row['bytes'] as int,
  };
  File('${outputDirectory.path}/android-size-baseline-candidate.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(candidate));

  stdout.writeln(_markdown(rows, baseline.isNotEmpty, maxGrowthPercent));
  if (enforceBudget && baseline.isNotEmpty && budgetFailed) {
    stderr.writeln(
      'Android artifact size grew by more than $maxGrowthPercent% versus the committed baseline.',
    );
    exitCode = 3;
  }
}

String? _argValue(List<String> args, String name) {
  final prefix = '$name=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  return null;
}

Map<String, int> _readBaseline(File file) {
  if (!file.existsSync()) return const {};
  try {
    final raw = jsonDecode(file.readAsStringSync());
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value is num) entry.key.toString(): (entry.value as num).toInt(),
    };
  } catch (_) {
    return const {};
  }
}

String _markdown(
  List<Map<String, Object?>> rows,
  bool hasBaseline,
  double maxGrowthPercent,
) {
  final buffer = StringBuffer()
    ..writeln('# Android release size report')
    ..writeln()
    ..writeln('| Artifact | Size (MiB) | Change vs baseline |')
    ..writeln('|---|---:|---:|');
  for (final row in rows) {
    final change = row['change_percent'];
    buffer.writeln(
      '| `${row['name']}` | ${row['mib']} | '
      '${change == null ? '—' : '${(change as double) >= 0 ? '+' : ''}$change%'} |',
    );
  }
  buffer
    ..writeln()
    ..writeln(
      hasBaseline
          ? 'Growth guard: +$maxGrowthPercent% maximum when enforcement is enabled.'
          : 'No committed baseline yet. Accept one real production release, then commit `tools/android_size_baseline.json`.',
    );
  return buffer.toString();
}
