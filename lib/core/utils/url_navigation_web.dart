// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Navigates the current browser tab directly to the specified URL.
/// This works reliably on mobile Safari and Chrome without being blocked by popup blockers.
void openUrlInCurrentTab(String url) {
  html.window.location.href = url;
}

/// Opens an external URL in a new tab with target="_blank" and rel="noopener".
void openExternalUrl(String url) {
  final anchor = html.AnchorElement(href: url)
    ..target = '_blank'
    ..rel = 'noopener';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
