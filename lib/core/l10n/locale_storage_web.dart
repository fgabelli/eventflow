// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation using window.localStorage.
String? getSavedUiLanguage() {
  try {
    return html.window.localStorage['ui_language'];
  } catch (_) {
    return null;
  }
}

void saveUiLanguage(String code) {
  try {
    html.window.localStorage['ui_language'] = code;
  } catch (_) {}
}
