// lib/services/google_news_service.dart
//
// Fetches Nepal Lok Sewa / government exam news from the Google News RSS feed,
// parses article titles, sources, and publication dates, and saves new items to
// Firestore via FirestoreService.addNews().
//
// RSS endpoint: https://news.google.com/rss/search?q=Nepal+Lok+Sewa&hl=en&gl=NP&ceid=NP:en
// A corsproxy is NOT needed on mobile — HTTP is direct.

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'firestore_service.dart';

class GoogleNewsService {
  static const _queries = [
    'Nepal Lok Sewa Aayog',
    'Nepal Government Vacancy',
    'Nepal PSC exam',
  ];

  static const _rssBase =
      'https://news.google.com/rss/search?hl=en&gl=NP&ceid=NP:en&q=';

  final FirestoreService _db;

  GoogleNewsService({FirestoreService? db}) : _db = db ?? FirestoreService();

  /// Fetches articles for all queries and saves new ones to Firestore.
  /// Returns the count of newly saved articles.
  Future<int> fetchAndSave() async {
    final seen = <String>{};
    var saved = 0;

    for (final query in _queries) {
      try {
        final articles = await _fetchForQuery(query);
        for (final a in articles) {
          final key = a['title'] as String;
          if (seen.contains(key)) continue;
          seen.add(key);

          // Only save if not already in Firestore (check by title)
          final exists = await _db.newsExistsByTitle(key);
          if (!exists) {
            await _db.addNews({
              'title':    a['title'],
              'summary':  a['summary'],
              'source':   a['source'],
              'imageUrl': '',
              'views':    0,
              'autoFetched': true,
            });
            saved++;
          }
        }
      } catch (_) {
        // skip failed query
      }
    }
    return saved;
  }

  Future<List<Map<String, String>>> _fetchForQuery(String query) async {
    final encoded = Uri.encodeComponent(query);
    final url = '$_rssBase$encoded';

    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];

    final doc = XmlDocument.parse(response.body);
    final items = doc.findAllElements('item');

    return items.map((item) {
      final title   = item.findElements('title').firstOrNull?.innerText ?? '';
      final link    = item.findElements('link').firstOrNull?.innerText ?? '';
      final pubDate = item.findElements('pubDate').firstOrNull?.innerText ?? '';
      final desc    = item.findElements('description').firstOrNull?.innerText ?? '';

      // Clean HTML from description
      final cleanDesc = desc
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&apos;', "'")
          .replaceAll(RegExp(r'&#\d+;'), ' ')
          .replaceAll(RegExp(r'  +'), ' ')  // collapse multiple spaces
          .trim();

      // Google News RSS wraps actual article URL in a redirect
      return {
        'title':   _cleanTitle(title),
        'summary': cleanDesc.isNotEmpty ? cleanDesc : pubDate,
        'source':  link,
      };
    }).where((a) => a['title']!.isNotEmpty).toList();
  }

  String _cleanTitle(String raw) {
    // Google News appends " - Source Name" at the end
    final idx = raw.lastIndexOf(' - ');
    return idx > 0 ? raw.substring(0, idx).trim() : raw.trim();
  }
}
