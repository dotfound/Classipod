import 'package:xml/xml.dart';

/// Returns the feed URLs in an OPML document, in order, without duplicates.
List<String> parseOpmlFeedUrls(String source) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(source);
  } on XmlException {
    return const [];
  }
  final urls = <String>{};
  for (final outline in document.findAllElements('outline')) {
    final url = (outline.getAttribute('xmlUrl') ?? '').trim();
    if (url.startsWith('http')) urls.add(url);
  }
  return urls.toList();
}
