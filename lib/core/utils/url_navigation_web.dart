// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Navigates the current browser tab directly to the specified URL.
/// This works reliably on mobile Safari and Chrome without being blocked by popup blockers.
void openUrlInCurrentTab(String url) {
  html.window.location.href = url;
}
