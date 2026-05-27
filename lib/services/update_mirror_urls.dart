class UpdateMirrorUrls {
  const UpdateMirrorUrls._();

  static const List<String> defaultGithubMirrorPrefixes = [
    'https://gh-proxy.com/',
  ];

  static List<Uri> withGithubMirrors(
    Uri primary, {
    List<Uri> extraMirrors = const [],
    List<String> githubMirrorPrefixes = defaultGithubMirrorPrefixes,
  }) {
    final candidates = <Uri>[
      primary,
      ...extraMirrors,
    ];
    if (_isGithubHosted(primary)) {
      for (final prefix in githubMirrorPrefixes) {
        final mirrorUri = Uri.tryParse('$prefix$primary');
        if (mirrorUri != null &&
            mirrorUri.scheme == 'https' &&
            mirrorUri.host.isNotEmpty) {
          candidates.add(mirrorUri);
        }
      }
    }
    return dedupe(candidates);
  }

  static List<Uri> dedupe(Iterable<Uri> uris) {
    final seen = <String>{};
    final result = <Uri>[];
    for (final uri in uris) {
      final key = uri.toString();
      if (seen.add(key)) {
        result.add(uri);
      }
    }
    return result;
  }

  static bool _isGithubHosted(Uri uri) {
    return uri.host == 'github.com' ||
        uri.host == 'raw.githubusercontent.com' ||
        uri.host == 'objects.githubusercontent.com' ||
        uri.host == 'release-assets.githubusercontent.com';
  }
}
