import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

/// Runs `generate -f json` on the i18n fixtures and checks that the generated
/// CodegenLoader compiles against the current package.
void main() {
  late Directory outputDir;

  setUp(() {
    // Inside the package, so that the generated file resolves
    // package:easy_localization_plus imports.
    final buildDir = Directory('build')..createSync(recursive: true);
    outputDir = buildDir.createTempSync('generate_codegen_loader_test_');
  });

  tearDown(() => outputDir.deleteSync(recursive: true));

  test(
    'generate -f json writes a CodegenLoader that compiles',
    () async {
      final generate = await Process.run('dart', [
        'run',
        'easy_localization_plus:generate',
        '--source-dir',
        'i18n',
        '--output-dir',
        outputDir.path,
        '--output-file',
        'codegen_loader.g.dart',
        '--format',
        'json',
      ]);
      expect(generate.exitCode, 0,
          reason: '${generate.stdout}${generate.stderr}');

      final generatedFile = path.join(outputDir.path, 'codegen_loader.g.dart');
      expect(File(generatedFile).existsSync(), isTrue,
          reason: '${generate.stdout}${generate.stderr}');

      // Uses the generated class the way the README tells apps to.
      File(path.join(outputDir.path, 'consumer.dart')).writeAsStringSync('''
import 'package:easy_localization_plus/easy_localization_plus.dart';

import 'codegen_loader.g.dart';

const AssetLoader loader = CodegenLoader();
''');

      final analyze = await Process.run('dart', ['analyze', outputDir.path]);
      expect(analyze.exitCode, 0, reason: '${analyze.stdout}${analyze.stderr}');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
