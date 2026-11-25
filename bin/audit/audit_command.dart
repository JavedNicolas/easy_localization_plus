import 'dart:io';
import 'key_parser.dart';

const _pluralForms = {'zero', 'one', 'two', 'few', 'many', 'other'};
const _genderForms = {'male', 'female'};

/// A key used in the code that does not lead to what its use expects.
class MisusedKey {
  const MisusedKey(this.key, this.reason);

  final String key;

  /// What is wrong and how to fix it, such as
  /// `holds plural forms, use plural()`.
  final String reason;

  @override
  String toString() => '$key: $reason';
}

/// The audit of one language: [missing] keys do not exist, [misused] keys
/// exist but not in the form their use expects, [withVariables] keys are
/// built at runtime (`'error.$code'`) and cannot be checked.
class LanguageAudit {
  final missing = <String>[];
  final misused = <MisusedKey>[];
  final withVariables = <String>[];

  bool get hasErrors => missing.isNotEmpty || misused.isNotEmpty;
}

/// Checks the keys [used] in the code against the keys of one language,
/// [translationKeys], whose entries are the dotted paths of its texts.
LanguageAudit auditLanguage(
  Set<String> translationKeys,
  Map<String, Set<KeyUsage>> used, {
  String keysClassName = 'LocaleKeys',
}) {
  final audit = LanguageAudit();

  for (final entry in used.entries) {
    final key = entry.key;
    for (final usage in entry.value) {
      if (usage == KeyUsage.generatedKey) {
        if (!_isGeneratedKeyName(key, translationKeys)) {
          audit.missing.add('$keysClassName.$key');
        }
        continue;
      }

      if (key.contains('\$')) {
        if (!translationKeys.contains(key) && _nestedKeysOf(key, translationKeys).isEmpty) {
          audit.withVariables.add(key);
        }
        continue;
      }

      switch (usage) {
        case KeyUsage.text:
          _checkText(key, translationKeys, audit);
          break;
        case KeyUsage.plural:
          _checkPlural(key, translationKeys, audit);
          break;
        case KeyUsage.gender:
          _checkGender(key, translationKeys, audit);
          break;
        case KeyUsage.generatedKey:
          break;
      }
    }
  }

  return audit;
}

void _checkText(String key, Set<String> translationKeys, LanguageAudit audit) {
  if (translationKeys.contains(key)) return;

  final nestedKeys = _nestedKeysOf(key, translationKeys);
  if (nestedKeys.isEmpty) {
    audit.missing.add(key);
  } else if (nestedKeys.every(_pluralForms.contains)) {
    audit.misused.add(MisusedKey(key, 'holds plural forms, use plural()'));
  } else if (nestedKeys.any(_genderForms.contains)) {
    audit.misused.add(MisusedKey(key, 'holds gender forms, use tr() with a gender'));
  } else {
    audit.misused.add(MisusedKey(key, 'leads to nested keys, use one of them, such as $key.${nestedKeys.first}'));
  }
}

void _checkPlural(String key, Set<String> translationKeys, LanguageAudit audit) {
  if (translationKeys.contains('$key.other')) return;

  if (translationKeys.contains(key)) {
    audit.misused.add(MisusedKey(key, 'is a text, used with plural(), use tr()'));
  } else {
    audit.missing.add('$key.other');
  }
}

void _checkGender(String key, Set<String> translationKeys, LanguageAudit audit) {
  if (translationKeys.contains(key)) {
    audit.misused.add(MisusedKey(key, 'is a text, used with a gender, remove the gender'));
    return;
  }

  for (final form in _genderForms) {
    if (!translationKeys.contains('$key.$form')) audit.missing.add('$key.$form');
  }
}

/// The names of the keys nested right under [key], such as `zero`, `one`
/// and `other` for plural forms.
List<String> _nestedKeysOf(String key, Set<String> translationKeys) {
  final prefix = '$key.';
  final nestedKeys = <String>{};
  for (final translationKey in translationKeys) {
    if (translationKey.startsWith(prefix)) {
      nestedKeys.add(translationKey.substring(prefix.length).split('.').first);
    }
  }
  return nestedKeys.toList();
}

/// Whether [name], a member of the generated keys class, names an existing
/// key. The generator names a key after its dotted path with the dots
/// replaced by underscores, for texts and for the keys holding nested keys,
/// but not for the plural and gender forms themselves (`money.other`).
bool _isGeneratedKeyName(String name, Set<String> translationKeys) {
  for (final translationKey in translationKeys) {
    final parts = translationKey.split('.');
    for (var i = 1; i <= parts.length; i++) {
      final isForm = i > 1 && (_pluralForms.contains(parts[i - 1]) || _genderForms.contains(parts[i - 1]));
      if (!isForm && parts.sublist(0, i).join('_') == name) return true;
    }
  }
  return false;
}

class AuditCommand {
  Future<void> run({
    required String transDir,
    required String srcDir,
    required bool showWarnings,
    String keysClassName = 'LocaleKeys',
  }) async {
    try {
      final translationDir = Directory(transDir);
      final sourceDir = Directory(srcDir);

      if (!translationDir.existsSync()) {
        stderr.writeln('Error: Translation directory "$transDir" does not exist.');
        return;
      }

      if (!sourceDir.existsSync()) {
        stderr.writeln('Error: Source directory "$srcDir" does not exist.');
        return;
      }

      final keyParser = KeyParser();
      final allTranslations = await keyParser.parseKeysInTranslationsDir(translationDir);
      final usedKeys = keyParser.parseKeysInSourceDir(sourceDir, keysClassName: keysClassName);

      _report(allTranslations, usedKeys, showWarnings: showWarnings, keysClassName: keysClassName);
    } catch (e) {
      stderr.writeln('Error during audit: $e');
    }
  }

  void _report(
    Map<String, Set<String>> allTranslations,
    Map<String, Set<KeyUsage>> usedKeys, {
    required bool showWarnings,
    required String keysClassName,
  }) {
    stderr.writeln('=== Keys Audit ===');

    var hasErrors = false;
    for (var lang in allTranslations.keys) {
      final audit = auditLanguage(allTranslations[lang]!, usedKeys, keysClassName: keysClassName);
      hasErrors = hasErrors || audit.hasErrors;

      stderr.writeln('\nLanguage: $lang');
      if (!audit.hasErrors && (audit.withVariables.isEmpty || !showWarnings)) {
        stderr.writeln('  ✅ all good!');
      }

      if (audit.missing.isNotEmpty) {
        stderr.writeln('  🔴 Missing (${audit.missing.length}):');
        for (var key in audit.missing) {
          stderr.writeln('    – $key');
        }
      }

      if (audit.misused.isNotEmpty) {
        stderr.writeln('  🟠 Misused (${audit.misused.length}):');
        for (var misusedKey in audit.misused) {
          stderr.writeln('    – $misusedKey');
        }
      }

      if (audit.withVariables.isNotEmpty && showWarnings) {
        stderr.writeln('  🟡 Missing with variables (${audit.withVariables.length}):');
        stderr.writeln('    These keys may not be missing as they contain variables that cannot be verified.');
        for (var key in audit.withVariables) {
          stderr.writeln('    – $key');
        }
      }
    }

    if (hasErrors) {
      stderr.writeln('\n');
      exit(1);
    }
  }
}
