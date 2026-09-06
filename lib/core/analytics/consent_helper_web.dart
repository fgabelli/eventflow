import 'dart:html' as html;
// ignore: uri_does_not_exist
import 'dart:js_util' as js_util;

/// Web implementation: reads consent state from localStorage.
String? getSavedConsent() => html.window.localStorage['cookie_consent'];

/// Call gtag('event', name, params) on web — goes directly to GA4 via the
/// gtag.js script already loaded in index.html / app.html.
void gtagLogEvent(String name, Map<String, Object>? params) {
  try {
    final jsParams = params != null
        ? js_util.jsify(params)
        : js_util.jsify(<String, Object>{});
    js_util.callMethod(html.window, 'gtag', ['event', name, jsParams]);
  } catch (_) {
    // gtag unavailable — silently ignore.
  }
}

/// Call gtag('set', {'user_id': uid}) on web.
void gtagSetUserId(String? uid) {
  try {
    final props = uid != null
        ? js_util.jsify({'user_id': uid})
        : js_util.jsify({'user_id': ''});
    js_util.callMethod(html.window, 'gtag', ['set', props]);
  } catch (_) {}
}
