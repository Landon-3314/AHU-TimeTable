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
  });

  factory UpdateAsset.fromJson(Map<String, Object?> json) {
    final abi = json['abi'];
    final url = json['url'];
    final sha256 = json['sha256'];
    final size = json['size'];
    if (abi is! String ||
        abi.trim().isEmpty ||
        url is! String ||
        Uri.tryParse(url)?.hasAbsolutePath != true ||
        sha256 is! String ||
        sha256.trim().isEmpty ||
        size is! int ||
        size <= 0) {
      throw const FormatException('Invalid update asset');
    }

    return UpdateAsset(
      abi: abi.trim(),
      url: Uri.parse(url),
      sha256: sha256.trim().toLowerCase(),
      size: size,
    );
  }

  final String abi;
  final Uri url;
  final String sha256;
  final int size;
}
