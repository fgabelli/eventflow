import 'package:flutter/material.dart';

/// Non-web fallback for rendering HTML email preview content.
Widget buildHtmlEmailPreview(String htmlContent) {
  final plainPreview = htmlContent
      .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|tr|div|h1|h2|h3)>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
      .trim();

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: SelectableText(
      plainPreview,
      style: const TextStyle(fontSize: 14, height: 1.5),
    ),
  );
}
