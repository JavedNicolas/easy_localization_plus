class Translations {
  final Map<String, dynamic>? _translations;
  final Map<String?, dynamic> _nestedKeysCache;

  Translations(this._translations) : _nestedKeysCache = {};

  /// The text of [key], or null when [key] is missing or leads to nested
  /// keys (such as plural or gender forms) instead of a text.
  String? get(String key) {
    String? returnValue;

    /// Try to look it up as a nested key
    if (isNestedKey(key)) {
      returnValue = getNested(key);
    }

    /// If we failed to find the key as a nested key, then fall back
    /// to looking it up like normal.
    if (returnValue == null) {
      var maybeValue = _translations?[key];
      if (maybeValue is String) returnValue = maybeValue;
    }

    return returnValue;
  }

  String? getNested(String key) {
    if (isNestedCached(key)) return _nestedKeysCache[key];

    final value = _getNestedValue(key);

    /// Only a text is cached and returned: a missing key or a key leading
    /// to nested keys gives null.
    if (value is! String) return null;

    cacheNestedKey(key, value);
    return value;
  }

  /// Whether [key] leads to nested keys instead of a text.
  bool hasNestedKeys(String key) {
    final nestedValue = isNestedKey(key) ? _getNestedValue(key) : null;
    return (nestedValue ?? _translations?[key]) is Map;
  }

  /// The value at the dotted path [key], or null when a part of the path is
  /// missing or is a text, as `title` in `title.foo`.
  dynamic _getNestedValue(String key) {
    final keys = key.split('.');
    dynamic value = _translations![keys.first];

    for (var i = 1; i < keys.length; i++) {
      if (value is! Map<String, dynamic>) return null;
      value = value[keys[i]];
    }

    return value;
  }

  // bool has(String key) => isNestedKey(key)
  //     ? getNested(key) != null
  //     : _translations.containsKey(key);

  bool isNestedCached(String key) => _nestedKeysCache.containsKey(key);

  void cacheNestedKey(String key, String value) {
    if (!isNestedKey(key)) {
      throw Exception('Cannot cache a key that is not nested.');
    }

    _nestedKeysCache[key] = value;
  }

  bool isNestedKey(String key) =>
      !_translations!.containsKey(key) && key.contains('.');
}
