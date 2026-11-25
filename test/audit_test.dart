import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../bin/audit/audit_command.dart';
import '../bin/audit/key_parser.dart';

void main() {
  const translationKeys = {
    'title',
    'reset_locale',
    'money.zero',
    'money.one',
    'money.other',
    'greeting.male',
    'greeting.female',
    'profile.reset_password.label',
    'profile.name',
  };

  LanguageAudit audit(Map<String, Set<KeyUsage>> used) => auditLanguage(translationKeys, used);

  group('audit, keys used as a text', () {
    test('accepts a key leading to a text', () {
      final result = audit({
        'title': {KeyUsage.text}
      });

      expect(result.hasErrors, isFalse);
    });

    test('reports a missing key', () {
      final result = audit({
        'titel': {KeyUsage.text}
      });

      expect(result.missing, ['titel']);
      expect(result.misused, isEmpty);
    });

    test('reports a key holding plural forms', () {
      final result = audit({
        'money': {KeyUsage.text}
      });

      expect(result.missing, isEmpty);
      expect(result.misused.single.toString(), 'money: holds plural forms, use plural()');
    });

    test('reports a key holding gender forms', () {
      final result = audit({
        'greeting': {KeyUsage.text}
      });

      expect(result.misused.single.toString(), 'greeting: holds gender forms, use tr() with a gender');
    });

    test('reports a key leading to nested keys', () {
      final result = audit({
        'profile': {KeyUsage.text}
      });

      expect(result.misused.single.toString(), 'profile: leads to nested keys, use one of them, such as profile.reset_password');
    });
  });

  group('audit, keys used with plural()', () {
    test('accepts a key holding plural forms', () {
      expect(
          audit({
            'money': {KeyUsage.plural}
          }).hasErrors,
          isFalse);
    });

    test('reports a text used with plural()', () {
      final result = audit({
        'title': {KeyUsage.plural}
      });

      expect(result.missing, isEmpty);
      expect(result.misused.single.toString(), 'title: is a text, used with plural(), use tr()');
    });

    test('reports missing plural forms', () {
      expect(
          audit({
            'apples': {KeyUsage.plural}
          }).missing,
          ['apples.other']);
    });
  });

  group('audit, keys used with a gender', () {
    test('accepts a key holding gender forms', () {
      expect(
          audit({
            'greeting': {KeyUsage.gender}
          }).hasErrors,
          isFalse);
    });

    test('reports a text used with a gender', () {
      final result = audit({
        'title': {KeyUsage.gender}
      });

      expect(result.misused.single.toString(), 'title: is a text, used with a gender, remove the gender');
    });

    test('reports missing gender forms', () {
      expect(
          audit({
            'hello': {KeyUsage.gender}
          }).missing,
          ['hello.male', 'hello.female']);
    });
  });

  group('audit, keys used through the keys class', () {
    test('accepts texts, keys with underscores and keys holding nested keys', () {
      final result = audit({
        'title': {KeyUsage.generatedKey},
        'reset_locale': {KeyUsage.generatedKey},
        'profile_reset_password_label': {KeyUsage.generatedKey},
        'money': {KeyUsage.generatedKey},
      });

      expect(result.hasErrors, isFalse);
    });

    test('reports a member naming a plural form, which the generator does not create', () {
      expect(
          audit({
            'money_other': {KeyUsage.generatedKey}
          }).missing,
          ['LocaleKeys.money_other']);
    });

    test('reports an unknown member of the keys class', () {
      expect(
          audit({
            'unknown_key': {KeyUsage.generatedKey}
          }).missing,
          ['LocaleKeys.unknown_key']);
    });
  });

  test('lists the keys built with variables as unverifiable', () {
    final result = audit({
      'errors.\$code': {KeyUsage.text}
    });

    expect(result.hasErrors, isFalse);
    expect(result.withVariables, ['errors.\$code']);
  });

  group('audit source parsing', () {
    late Directory srcDir;

    setUp(() {
      srcDir = Directory.systemTemp.createTempSync('audit_usage');
      File('${srcDir.path}/page.dart').writeAsStringSync('''
Text('single_quoted'.tr());
Text("double_quoted".tr());
Text('apples'.plural(2));
Text(plural('money', 2));
Text(tr('greeting', gender: 'male'));
''');
    });

    tearDown(() => srcDir.deleteSync(recursive: true));

    test('records how each key is used', () {
      final used = KeyParser().parseKeysInSourceDir(srcDir);

      expect(used['single_quoted'], {KeyUsage.text});
      expect(used['double_quoted'], {KeyUsage.text});
      expect(used['apples'], {KeyUsage.plural});
      expect(used['money'], {KeyUsage.plural});
      expect(used['greeting'], {KeyUsage.gender});
    });
  });
}
