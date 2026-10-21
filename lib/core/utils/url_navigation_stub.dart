import 'package:url_launcher/url_launcher.dart';

/// Stub implementation for non-web platforms (e.g. unit tests, VM).
void openUrlInCurrentTab(String url) {
  // No-op for VM
}

void openExternalUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null) {
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
