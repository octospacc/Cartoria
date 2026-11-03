import 'package:flutter/foundation.dart';
import 'package:opengraph/opengraph.dart';

class LinkMetadata {
  final String? title;
  final String? description;
  final String? image;

  const LinkMetadata({this.title, this.description, this.image});
}

class LinkMetadataService {
  LinkMetadataService({String? proxyUrl}) {
    if (proxyUrl != null) {
      OpengraphFetch.proxyUrl = proxyUrl;
    }
  }

  Future<LinkMetadata?> fetch(String url) async {
    if (url.trim().isEmpty) return null;
    try {
      final data = await opengraph_fetch(
        url,
        timeout: const Duration(seconds: 8),
      );
      if (data == null) return null;
      String? clean(String s) {
        final t = s.trim();
        return t.isEmpty ? null : t;
      }
      return LinkMetadata(
        title: clean(data.title),
        description: clean(data.description),
        image: clean(data.image),
      );
    } catch (e) {
      debugPrint('Metadata fetch failed for $url: $e');
      return null;
    }
  }
}