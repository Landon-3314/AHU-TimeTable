class UpdateManifest {
  const UpdateManifest({
    required this.versionName,
    required this.versionCode,
    required this.releaseNotes,
    required this.assets,
  });

  factory UpdateManifest.fromJson(Map<String, Object?> json) {
    final versionName = json['versionName'];
    final versionCode = json['versionCode'];
    final releaseNotes = json['releaseNotes'];
    final rawAssets = json['assets'];
    if (versionName is! String ||
        versionName.trim().isEmpty ||
        versionCode is! int ||
        versionCode <= 0 ||
        rawAssets is! List) {
      throw const FormatException('Invalid update manifest');
    }

    final assets = rawAssets
        .whereType<Map>()
        .map((asset) => UpdateAsset.fromJson(Map<String, Object?>.from(asset)))
        .toList(growable: false);
    if (assets.isEmpty) {
      throw const FormatException('Update manifest has no usable assets');
    }

    return UpdateManifest(
      versionName: versionName.trim(),
      versionCode: versionCode,
      releaseNotes: releaseNotes is String ? releaseNotes.trim() : '',
      assets: assets,
    );
  }

  final String versionName;
  final int versionCode;
  final String releaseNotes;
  final List<UpdateAsset> assets;

  UpdateAsset? selectAssetForAbis(List<String> supportedAbis) {
    for (final abi in supportedAbis) {
      for (final asset in assets) {
        if (asset.abi == abi) {
          return asset;
        }
      }
    }
    return null;
  }
}

class UpdateAsset {
  const UpdateAsset({
    required this.abi,
    required this.url,
    required this.sha256,
    required this.size,
    this.mirrorUrls = const [],
  });

  factory UpdateAsset.fromJson(Map<String, Object?> json) {
    final abi = json['abi'];
    final url = json['url'];
    final rawMirrorUrls = json['mirrorUrls'];
    final sha256 = json['sha256'];
    final size = json['size'];
    final parsedUrl = url is String ? Uri.tryParse(url) : null;
    final mirrorUrls = _parseMirrorUrls(rawMirrorUrls);
    if (abi is! String ||
        abi.trim().isEmpty ||
        url is! String ||
        parsedUrl == null ||
        parsedUrl.scheme != 'https' ||
        parsedUrl.host.isEmpty ||
        mirrorUrls == null ||
        sha256 is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256.trim()) ||
        size is! int ||
        size <= 0) {
      throw const FormatException('Invalid update asset');
    }

    return UpdateAsset(
      abi: abi.trim(),
      url: parsedUrl,
      sha256: sha256.trim().toLowerCase(),
      size: size,
      mirrorUrls: mirrorUrls,
    );
  }

  final String abi;
  final Uri url;
  final String sha256;
  final int size;
  final List<Uri> mirrorUrls;

  static List<Uri>? _parseMirrorUrls(Object? value) {
    if (value == null) {
      return const [];
    }
    if (value is! List) {
      return null;
    }
    final mirrors = <Uri>[];
    for (final entry in value) {
      if (entry is! String) {
        return null;
      }
      final uri = Uri.tryParse(entry);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        return null;
      }
      mirrors.add(uri);
    }
    return List.unmodifiable(mirrors);
  }
}
