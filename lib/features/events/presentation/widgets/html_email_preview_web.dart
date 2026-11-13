// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

int _emailPreviewViewSeq = 0;

/// Renders the true HTML email inside a sandboxed iframe (scripts disabled).
Widget buildHtmlEmailPreview(String htmlContent) {
  final viewType = 'ticketto-email-preview-${++_emailPreviewViewSeq}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = html.IFrameElement()
      ..srcdoc = htmlContent
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#F3F4F6';
    // Empty sandbox blocks all script execution, navigation, and popups
    // while allowing full HTML + inline CSS email rendering.
    iframe.setAttribute('sandbox', '');
    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}
