import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../bin/audit/key_parser.dart';
import '../bin/generate.dart';

void main() {
  group('generate --class-name', () {
    test('accepts Dart identifiers', () {
      expect(isValidClassName('LocaleKeys'), isTrue);
      expect(isValidClassName('MyKeys'), isTrue);
      expect(isValidClassName('_Keys2'), isTrue);
    });

    test('rejects names that would not compile', () {
      expect(isValidClassName(null), isFalse);
      expect(isValidClassName(''), isFalse);
      expect(isValidClassName('1Keys'), isFalse);
      expect(isValidClassName('My Keys'), isFalse);
      expect(isValidClassName('my-keys'), isFalse);
      expect(isValidClassName('class'), isFalse);
      expect(isValidClassName('dynamic'), isFalse);
    });
  });

  group('audit --class-name', () {
    late Directory srcDir;

    setUp(() {
      srcDir = Directory.systemTemp.createTempSync('audit_class_name');
      File('${srcDir.path}/page.dart').writeAsStringSync('''
Text(LocaleKeys.home_title.tr());
Text(MyKeys.settings_title.tr());
Text(OtherMyKeys.other_title.tr());
''');
    });

    tearDown(() => srcDir.deleteSync(recursive: true));

    test('finds keys used through LocaleKeys by default', () {
      final keys = KeyParser().parseKeysInSourceDir(srcDir);

      expect(keys, contains('home.title'));
      expect(keys, isNot(contains('settings.title')));
    });

    test('finds keys used through a custom class name', () {
      final keys =
          KeyParser().parseKeysInSourceDir(srcDir, keysClassName: 'MyKeys');

      expect(keys, contains('settings.title'));
      expect(keys, isNot(contains('home.title')));
    });

    test('does not match a class whose name ends with the custom name', () {
      final keys =
          KeyParser().parseKeysInSourceDir(srcDir, keysClassName: 'MyKeys');

      expect(keys, isNot(contains('other.title')));
    });
  });
}
