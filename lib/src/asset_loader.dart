import 'dart:convert';
import 'dart:ui';
import 'package:easy_localization_plus/easy_localization_plus.dart';
import 'package:easy_localization_plus/src/file_loaders/io_file_loader.dart';

/// abstract class used to building your Custom AssetLoader
/// Example:
/// ```
///class FileAssetLoader extends AssetLoader {
///  @override
///  Future<Map<String, dynamic>> load(String path, Locale locale) async {
///    final file = File(path);
///    return json.decode(await file.readAsString());
///  }
///}
/// ```
abstract class AssetLoader {
  const AssetLoader();

  Future<Map<String, dynamic>?> load(String path, Locale locale);
}

///
/// default used is RootBundleAssetLoader which uses flutter's assetloader
///
class RootBundleAssetLoader extends AssetLoader {
  /// Reads the translation files: from the Flutter assets by default.
  final FileLoader fileLoader;

  final LinkedFileResolver? _linkedFileResolver;

  /// Replaces the `":/file.json"` values with the content of the linked
  /// files. By default, a [JsonLinkedFileResolver] that reads the linked
  /// files with [fileLoader].
  LinkedFileResolver get linkedFileResolver =>
      _linkedFileResolver ?? JsonLinkedFileResolver(fileLoader: fileLoader);

  const RootBundleAssetLoader({
    this.fileLoader = const RootBundleFileLoader(),
    LinkedFileResolver? linkedFileResolver,
  }) : _linkedFileResolver = linkedFileResolver;

  factory RootBundleAssetLoader.fromRootBundle() {
    return const RootBundleAssetLoader(
      linkedFileResolver: JsonLinkedFileResolver(fileLoader: RootBundleFileLoader()),
      fileLoader: RootBundleFileLoader(),
    );
  }

  factory RootBundleAssetLoader.fromIOFile() {
    return const RootBundleAssetLoader(
      linkedFileResolver: JsonLinkedFileResolver(fileLoader: IOFileLoader()),
      fileLoader: IOFileLoader(),
    );
  }

  String getLocalePath(String basePath, Locale locale) {
    return '$basePath/${locale.toStringWithSeparator(separator: "-")}.json';
  }

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    var localePath = getLocalePath(path, locale);
    EasyLocalization.logger.debug('Load asset from $path');

    Map<String, dynamic> baseJson = json.decode(await fileLoader.loadString(localePath));
    return await linkedFileResolver.resolveLinkedFiles(
      basePath: path,
      languageCode: locale.languageCode,
      countryCode: locale.countryCode,
      baseJson: baseJson,
    );
  }
}
