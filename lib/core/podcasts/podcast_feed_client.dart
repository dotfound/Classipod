import 'dart:convert';
import 'dart:io';

import 'package:classipod/core/podcasts/models/podcast_episode.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class ParsedPodcastFeed {
  final String title;
  final String? author;
  final String? artworkUrl;
  final List<PodcastEpisode> episodes;

  const ParsedPodcastFeed({
    required this.title,
    this.author,
    this.artworkUrl,
    required this.episodes,
  });
}

class PodcastFeedResponse {
  /// Null when the server answered 304 Not Modified.
  final ParsedPodcastFeed? feed;
  final String? etag;
  final String? lastModified;

  const PodcastFeedResponse({this.feed, this.etag, this.lastModified});

  bool get notModified => feed == null;
}

class PodcastFeedException implements Exception {
  final String message;

  const PodcastFeedException(this.message);

  @override
  String toString() => 'PodcastFeedException: $message';
}

const _itunes = 'http://www.itunes.com/dtds/podcast-1.0.dtd';

class PodcastFeedClient {
  final http.Client client;
  final Duration timeout;

  PodcastFeedClient({http.Client? client, this.timeout = _defaultTimeout})
    : client = client ?? http.Client();

  static const _defaultTimeout = Duration(seconds: 30);

  Future<PodcastFeedResponse> fetch(
    String feedUrl, {
    String? etag,
    String? lastModified,
  }) async {
    final response = await client
        .get(
          Uri.parse(feedUrl),
          headers: {
            'User-Agent': 'PixelPod/1.0',
            'Accept': 'application/rss+xml, application/xml, text/xml, */*',
            'If-None-Match': ?etag,
            'If-Modified-Since': ?lastModified,
          },
        )
        .timeout(timeout);
    if (response.statusCode == HttpStatus.notModified) {
      return PodcastFeedResponse(etag: etag, lastModified: lastModified);
    }
    if (response.statusCode != HttpStatus.ok) {
      throw PodcastFeedException('HTTP ${response.statusCode} for $feedUrl');
    }
    return PodcastFeedResponse(
      feed: parsePodcastFeed(
        utf8.decode(response.bodyBytes, allowMalformed: true),
        feedUrl,
      ),
      etag: response.headers['etag'],
      lastModified: response.headers['last-modified'],
    );
  }
}

ParsedPodcastFeed parsePodcastFeed(String source, String feedUrl) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(source);
  } on XmlException catch (error) {
    throw PodcastFeedException('Invalid feed XML: ${error.message}');
  }
  final channel = document.rootElement.getElement('channel');
  if (channel == null) {
    throw const PodcastFeedException('Feed has no channel');
  }
  final episodes = <PodcastEpisode>[];
  final seen = <String>{};
  for (final item in channel.findElements('item')) {
    final enclosure = item
        .findElements('enclosure')
        .where(_isAudioEnclosure)
        .firstOrNull;
    final enclosureUrl = enclosure?.getAttribute('url')?.trim();
    if (enclosureUrl == null || enclosureUrl.isEmpty) continue;
    final guid = _text(item.getElement('guid'));
    final id = guid == null || guid.isEmpty ? enclosureUrl : guid;
    if (!seen.add(id)) continue;
    episodes.add(
      PodcastEpisode(
        id: id,
        showFeedUrl: feedUrl,
        title: _text(item.getElement('title')) ?? 'Untitled episode',
        description: stripHtml(
          _text(item.getElement('description')) ??
              _text(item.getElement('summary', namespaceUri: _itunes)) ??
              '',
        ),
        pubDate: parseRssDate(_text(item.getElement('pubDate'))),
        enclosureUrl: enclosureUrl,
        durationSeconds: parseItunesDuration(
          _text(item.getElement('duration', namespaceUri: _itunes)),
        ),
      ),
    );
  }
  return ParsedPodcastFeed(
    title: _text(channel.getElement('title')) ?? feedUrl,
    author: _text(channel.getElement('author', namespaceUri: _itunes)),
    artworkUrl:
        channel
            .getElement('image', namespaceUri: _itunes)
            ?.getAttribute('href') ??
        _text(channel.getElement('image')?.getElement('url')),
    episodes: episodes,
  );
}

bool _isAudioEnclosure(XmlElement enclosure) {
  final type = enclosure.getAttribute('type')?.toLowerCase() ?? '';
  if (type.startsWith('audio/')) return true;
  if (type.startsWith('video/') || type.startsWith('image/')) return false;
  final path =
      Uri.tryParse(enclosure.getAttribute('url') ?? '')?.path.toLowerCase() ??
      '';
  return const [
    '.mp3',
    '.m4a',
    '.aac',
    '.ogg',
    '.opus',
    '.wav',
    '.flac',
  ].any(path.endsWith);
}

String? _text(XmlElement? element) {
  final text = element?.innerText.trim();
  return text == null || text.isEmpty ? null : text;
}

/// Parses `itunes:duration`, which can be seconds, MM:SS or HH:MM:SS.
int parseItunesDuration(String? value) {
  if (value == null) return 0;
  final parts = value.trim().split(':');
  if (parts.isEmpty || parts.length > 3) return 0;
  var seconds = 0;
  for (final part in parts) {
    final number = double.tryParse(part.trim());
    if (number == null || number < 0) return 0;
    seconds = seconds * 60 + number.round();
  }
  return seconds;
}

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

const _zones = {
  'gmt': 0,
  'ut': 0,
  'utc': 0,
  'z': 0,
  'bst': 60,
  'est': -300,
  'edt': -240,
  'cst': -360,
  'cdt': -300,
  'mst': -420,
  'mdt': -360,
  'pst': -480,
  'pdt': -420,
};

final _rssDate = RegExp(
  r'(\d{1,2})\s+([A-Za-z]{3})[A-Za-z]*\s+(\d{2,4})\s+'
  r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|[A-Za-z]+)?',
);

/// Parses an RFC 822 date as used by RSS, falling back to ISO 8601.
DateTime? parseRssDate(String? value) {
  if (value == null) return null;
  final match = _rssDate.firstMatch(value);
  if (match == null) return DateTime.tryParse(value.trim())?.toUtc();
  final month = _months[match.group(2)!.toLowerCase()];
  if (month == null) return null;
  var year = int.parse(match.group(3)!);
  if (year < 100) year += year < 70 ? 2000 : 1900;
  final zone = match.group(7);
  var offsetMinutes = 0;
  if (zone != null) {
    if (zone.startsWith('+') || zone.startsWith('-')) {
      final sign = zone.startsWith('-') ? -1 : 1;
      offsetMinutes =
          sign *
          (int.parse(zone.substring(1, 3)) * 60 +
              int.parse(zone.substring(3, 5)));
    } else {
      offsetMinutes = _zones[zone.toLowerCase()] ?? 0;
    }
  }
  return DateTime.utc(
    year,
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6) ?? '0'),
  ).subtract(Duration(minutes: offsetMinutes));
}

const _entities = {
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&apos;': "'",
  '&#39;': "'",
  '&nbsp;': ' ',
  '&rsquo;': '’',
  '&lsquo;': '‘',
  '&rdquo;': '”',
  '&ldquo;': '“',
  '&ndash;': '–',
  '&mdash;': '—',
  '&hellip;': '…',
};

/// Reduces an HTML description to plain text.
String stripHtml(String html) {
  var text = html
      .replaceAll(
        RegExp(r'<(br|/p|/div|/li)\s*/?>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp('<[^>]*>'), '');
  _entities.forEach((entity, replacement) {
    text = text.replaceAll(entity, replacement);
  });
  text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
    final code = int.tryParse(match.group(1)!);
    return code == null ? '' : String.fromCharCode(code);
  });
  return text
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}
