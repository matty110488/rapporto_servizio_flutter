import 'dart:convert';
import 'dart:io';

int calculateTestBuildNumber({
  required int runId,
  required int runAttempt,
}) {
  if (runId <= 0) {
    throw ArgumentError.value(runId, 'runId', 'must be positive');
  }
  if (runAttempt <= 0 || runAttempt >= 1000) {
    throw ArgumentError.value(
      runAttempt,
      'runAttempt',
      'must be between 1 and 999',
    );
  }
  return 100000 + runId * 1000 + runAttempt;
}

Map<String, String> buildTestVersionMetadata({
  required String version,
  required String buildNumber,
  required String gitSha,
}) {
  if (version.trim().isEmpty) {
    throw ArgumentError.value(version, 'version', 'must not be empty');
  }
  final numericBuild = int.tryParse(buildNumber);
  if (numericBuild == null || numericBuild <= 29) {
    throw ArgumentError.value(
      buildNumber,
      'buildNumber',
      'must be numeric and greater than 29',
    );
  }
  if (gitSha.trim().isEmpty) {
    throw ArgumentError.value(gitSha, 'gitSha', 'must not be empty');
  }
  return {
    'version': version.trim(),
    'build_number': buildNumber,
    'git_sha': gitSha.trim(),
  };
}

String cacheBustFlutterBootstrap(String indexHtml, String buildNumber) {
  final bootstrapPattern = RegExp(
    r'flutter_bootstrap\.js(?:\?v=[^"\s<]*)?',
  );
  if (!bootstrapPattern.hasMatch(indexHtml)) {
    throw StateError('flutter_bootstrap.js reference not found in index.html');
  }
  return indexHtml.replaceFirst(
    bootstrapPattern,
    'flutter_bootstrap.js?v=$buildNumber',
  );
}

void main(List<String> arguments) {
  if (arguments.length == 3 && arguments.first == '--build-number') {
    final runId = int.tryParse(arguments[1]);
    final runAttempt = int.tryParse(arguments[2]);
    if (runId == null || runAttempt == null) {
      stderr.writeln('GitHub run ID and attempt must be numeric.');
      exitCode = 64;
      return;
    }
    stdout.writeln(
      calculateTestBuildNumber(runId: runId, runAttempt: runAttempt),
    );
    return;
  }

  if (arguments.length != 4) {
    stderr.writeln(
      'Usage: dart run tool/write_test_web_metadata.dart '
      '<build-web-dir> <version> <build-number> <git-sha>\n'
      '   or: dart run tool/write_test_web_metadata.dart '
      '--build-number <github-run-id> <github-run-attempt>',
    );
    exitCode = 64;
    return;
  }

  final buildDirectory = Directory(arguments[0]);
  if (!buildDirectory.existsSync()) {
    stderr.writeln('Build directory not found: ${buildDirectory.path}');
    exitCode = 66;
    return;
  }

  final metadata = buildTestVersionMetadata(
    version: arguments[1],
    buildNumber: arguments[2],
    gitSha: arguments[3],
  );
  final versionFile = File('${buildDirectory.path}/version.json');
  versionFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(metadata)}\n',
  );

  final indexFile = File('${buildDirectory.path}/index.html');
  if (!indexFile.existsSync()) {
    stderr.writeln('Web index not found: ${indexFile.path}');
    exitCode = 66;
    return;
  }
  indexFile.writeAsStringSync(
    cacheBustFlutterBootstrap(indexFile.readAsStringSync(), arguments[2]),
  );
}
