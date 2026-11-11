// Builds assets/podcasts_seed.opml from podcasts.txt (names or feed URLs,
// one per line). Names are resolved with the iTunes search API and every
// feed is fetched and parsed before it goes into the seed.
//
// Usage: dart run tool/build_seed_opml.dart [podcasts.txt]
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:classipod/core/podcasts/podcast_feed_client.dart';
import 'package:http/http.dart' as http;

Future<void> main(List<String> arguments) async {
  final input = File(arguments.isEmpty ? 'podcasts.txt' : arguments.first);
  final lines = input
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'));
  final client = http.Client();
  final feeds = PodcastFeedClient(client: client);
  final seed = <({String title, String url})>[];
  final problems = <String>[];
  for (final line in lines) {
    var url = line;
    if (!line.startsWith('http')) {
      final uri = Uri.https('itunes.apple.com', '/search', {
        'media': 'podcast',
        'limit': '3',
        'term': line,
      });
      final results =
          (jsonDecode((await client.get(uri)).body)
                  as Map<String, dynamic>)['results']
              as List<dynamic>? ??
          [];
      final matches = [
        for (final result in results.cast<Map<String, dynamic>>())
          if (result['feedUrl'] != null) result,
      ];
      print('\n$line');
      for (final (index, match) in matches.indexed) {
        print(
          '  ${index + 1}. ${match['collectionName']} '
          '(${match['artistName']}) ${match['feedUrl']}',
        );
      }
      if (matches.isEmpty) {
        problems.add('$line: no match found');
        continue;
      }
      url = matches.first['feedUrl'] as String;
    }
    try {
      final feed = (await feeds.fetch(url)).feed!;
      final newest = feed.episodes.firstOrNull?.pubDate;
      print(
        '  -> ${feed.title}: ${feed.episodes.length} episodes, '
        'newest ${newest?.toIso8601String().substring(0, 10)}',
      );
      if (feed.episodes.isEmpty) {
        problems.add('$line: feed has no audio episodes ($url)');
        continue;
      }
      seed.add((title: feed.title, url: url));
    } catch (error) {
      problems.add('$line: dead feed $url ($error)');
    }
  }
  client.close();
  String escape(String value) => const HtmlEscape().convert(value);
  final outlines = [
    for (final entry in seed)
      '    <outline type="rss" text="${escape(entry.title)}" '
          'xmlUrl="${escape(entry.url)}"/>',
  ];
  File('assets/podcasts_seed.opml').writeAsStringSync(
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<opml version="2.0">\n'
    '  <head><title>PixelPod subscriptions</title></head>\n'
    '  <body>\n${outlines.join('\n')}\n  </body>\n'
    '</opml>\n',
  );
  print('\nWrote ${seed.length} feeds to assets/podcasts_seed.opml');
  if (problems.isNotEmpty) {
    print('Problems:\n  ${problems.join('\n  ')}');
    exitCode = 1;
  }
}
