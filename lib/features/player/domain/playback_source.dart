class PlaybackSource {
  final String id;
  final String title;
  final String url;
  final String subtitle;
  final Map<String, String> headers;

  const PlaybackSource({
    required this.id,
    required this.title,
    required this.url,
    this.subtitle = '',
    this.headers = const {},
  });

  factory PlaybackSource.fromMap(
    String id,
    Map<String, dynamic> data, {
    required String fallbackTitle,
  }) {
    final rawHeaders = data['headers'];
    final headers = <String, String>{};
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        headers[entry.key.toString()] = entry.value.toString();
      }
    }

    return PlaybackSource(
      id: id,
      title: (data['title'] ?? fallbackTitle).toString().trim(),
      subtitle: (data['subtitle'] ?? '').toString().trim(),
      url: (data['url'] ?? '').toString().trim(),
      headers: headers,
    );
  }
}
