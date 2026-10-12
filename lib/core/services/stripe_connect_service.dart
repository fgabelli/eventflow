import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';

import 'package:eventflow/core/utils/url_navigation.dart';

class StripeConnectService {
  static Future<void> connectStripe(
    BuildContext context, {
    required String orgId,
    required String orgName,
    String? userEmail,
  }) async {
    // Show loading
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)['stripe_connecting']),
            ],
          ),
          duration: const Duration(seconds: 10),
        ),
      );
    }

    try {
      final response = await http.post(
        Uri.parse('https://us-central1-eventflow-3541b.cloudfunctions.net/createConnectAccount'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orgId': orgId,
          'email': userEmail ?? '',
          'orgName': orgName,
        }),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['url'] != null) {
        final urlString = data['url'] as String;
        final stripeUrl = Uri.parse(urlString);
        bool launched = false;
        try {
          launched = await launchUrl(
            stripeUrl,
            mode: LaunchMode.platformDefault,
            webOnlyWindowName: '_self',
          );
        } catch (_) {}

        if (!launched) {
          try {
            openUrlInCurrentTab(urlString);
            launched = true;
          } catch (_) {}
        }

        if (!launched && context.mounted) {
          // Fallback: show the URL so the user can copy it
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Apri manualmente: $urlString'),
              duration: const Duration(seconds: 15),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'Errore nella connessione a Stripe (${response.statusCode})'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
