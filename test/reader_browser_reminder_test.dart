import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_flutter_app/core/services/browser_push.dart';
import 'package:my_flutter_app/core/services/reader_browser_reminder_service.dart';

class _Browser extends BrowserPush {
  int starts = 0;
  int stops = 0;
  final prompts = <bool>[];
  @override bool get supported => true;
  @override String get timeZone => 'Asia/Karachi';
  @override Future<Map<String, dynamic>> subscribe(String key, {bool requestPermission = true}) async {
    starts++;
    prompts.add(requestPermission);
    return {'endpoint': 'https://fcm.googleapis.com/test', 'keys': {'p256dh': 'point', 'auth': 'key'}};
  }
  @override Future<void> unsubscribe() async { stops++; }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('unconfigured server never requests browser permission or uploads reader data', () async {
    final browser = _Browser();
    final service = ReaderBrowserReminderService.forTesting('https://quran.test', browser: browser,
      clientFactory: () => MockClient((request) async {
        expect(request.url.path, '/public/reminders/config');
        expect(request.headers.containsKey('Authorization'), false);
        return http.Response('{"success":true,"configured":false,"publicKey":null}', 200);
      }));
    await service.initialize();
    await service.setEnabled(true, hour: 20, minute: 0, language: 'ar');
    expect(service.enabled, false);
    expect(browser.starts, 0);
    expect(service.error, isNotNull);
  });

  test('subscription is authenticated, backend-bound and stores no additional bearer', () async {
    final browser = _Browser();
    final requests = <http.Request>[];
    final service = ReaderBrowserReminderService.forTesting('https://quran.test', browser: browser,
      clientFactory: () => MockClient((request) async {
        requests.add(request);
        expect(request.followRedirects, false);
        if (request.method == 'GET') return http.Response(jsonEncode({'success': true, 'configured': true, 'publicKey': 'A' * 87}), 200);
        final body = jsonDecode(request.body) as Map;
        expect(body['zone'], 'Asia/Karachi');
        expect(body['language'], 'ar');
        expect(body.containsKey('payload'), false);
        expect(body.containsKey('token'), false);
        expect(request.headers['Authorization'], matches(r'^Bearer [A-Za-z0-9_-]{43}$'));
        return http.Response('{"success":true}', 200);
      }));
    await service.initialize();
    await service.setEnabled(true, hour: 18, minute: 25, language: 'ar');
    expect(service.enabled, true);
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('reader.push.https%3A%2F%2Fquran.test.v1')!) as Map;
    expect(saved.keys.toSet(), {'instanceId', 'enabled'});
    expect(saved['instanceId'], matches(r'^[A-Za-z0-9_-]{32}$'));
    expect(requests.last.url.path, '/public/reminders/subscribe');
  });

  test('refused registration cleans up new browser subscription', () async {
    final browser = _Browser();
    final service = ReaderBrowserReminderService.forTesting('https://quran.test', browser: browser,
      clientFactory: () => MockClient((request) async => request.method == 'GET'
        ? http.Response(jsonEncode({'success': true, 'configured': true, 'publicKey': 'A' * 87}), 200)
        : http.Response('{"message":"Unavailable"}', 503)));
    await service.initialize();
    await service.setEnabled(true, hour: 20, minute: 0, language: 'en');
    expect(service.enabled, false);
    expect(browser.stops, 1);
    expect(service.busy, false);
  });

  test('failed time update preserves previously enabled browser subscription', () async {
    final browser = _Browser();
    var fail = false;
    final service = ReaderBrowserReminderService.forTesting('https://quran.test', browser: browser,
      clientFactory: () => MockClient((request) async => request.method == 'GET'
        ? http.Response(jsonEncode({'success': true, 'configured': true, 'publicKey': 'A' * 87}), 200)
        : http.Response('{"success":true}', fail ? 503 : 200)));
    await service.initialize();
    await service.setEnabled(true, hour: 20, minute: 0, language: 'en');
    fail = true;
    await service.updateTime(hour: 21, minute: 0, language: 'en');
    expect(service.enabled, true);
    expect(service.error, isNotNull);
    expect(browser.stops, 0);
    expect(browser.prompts, [true, false]);
  });

  test('disable unsubscribes locally and removes only authenticated reminder binding', () async {
    final browser = _Browser();
    String? removed;
    final service = ReaderBrowserReminderService.forTesting('https://quran.test', browser: browser,
      clientFactory: () => MockClient((request) async {
        if (request.method == 'GET') return http.Response(jsonEncode({'success': true, 'configured': true, 'publicKey': 'A' * 87}), 200);
        if (request.url.path.endsWith('/unsubscribe')) { removed = request.body; expect(request.headers['Authorization'], isNotNull); }
        return http.Response('{"success":true}', 200);
      }));
    await service.initialize();
    await service.setEnabled(true, hour: 20, minute: 0, language: 'en');
    await service.setEnabled(false, hour: 20, minute: 0, language: 'en');
    expect(service.enabled, false);
    expect(browser.stops, 1);
    expect((jsonDecode(removed!) as Map).keys.toSet(), {'deviceId', 'instanceId'});
  });
}
