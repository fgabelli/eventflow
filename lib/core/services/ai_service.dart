import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eventflow/core/constants/app_constants.dart';

// ─── AI Generated Event Data ───────────────────────────────────────

class AiGeneratedEvent {
  final String title;
  final String description;
  final String? location;
  final int maxAttendees;
  final bool isPaid;
  final double? price;
  final List<String> categories;
  final List<Map<String, dynamic>> suggestedCustomFields;
  final List<Map<String, dynamic>> suggestedTimeSlots;

  AiGeneratedEvent({
    required this.title,
    required this.description,
    this.location,
    this.maxAttendees = 50,
    this.isPaid = false,
    this.price,
    this.categories = const ['Standard'],
    this.suggestedCustomFields = const [],
    this.suggestedTimeSlots = const [],
  });

  factory AiGeneratedEvent.fromJson(Map<String, dynamic> json) {
    return AiGeneratedEvent(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      location: json['location'],
      maxAttendees: (json['maxAttendees'] as num?)?.toInt() ?? 50,
      isPaid: json['isPaid'] ?? false,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      categories: json['categories'] != null
          ? List<String>.from(json['categories'])
          : ['Standard'],
      suggestedCustomFields: json['customFields'] != null
          ? List<Map<String, dynamic>>.from(
              (json['customFields'] as List).map((f) => Map<String, dynamic>.from(f)))
          : [],
      suggestedTimeSlots: json['timeSlots'] != null
          ? List<Map<String, dynamic>>.from(
              (json['timeSlots'] as List).map((s) => Map<String, dynamic>.from(s)))
          : [],
    );
  }
}

// ─── AI Usage Stats ────────────────────────────────────────────────

class AiUsageStats {
  final String plan;
  final int maxUsages;
  final int currentUsage;
  final int remaining; // -1 = unlimited

  AiUsageStats({
    required this.plan,
    required this.maxUsages,
    required this.currentUsage,
    required this.remaining,
  });

  factory AiUsageStats.fromJson(Map<String, dynamic> json) {
    return AiUsageStats(
      plan: json['plan'] ?? 'free',
      maxUsages: (json['maxUsages'] as num?)?.toInt() ?? 0,
      currentUsage: (json['currentUsage'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isUnlimited => remaining == -1;
  bool get hasUsagesLeft => isUnlimited || remaining > 0;
}

// ─── AI Service (Cloud Functions) ──────────────────────────────────

class AiService {
  final FirebaseFunctions _functions;

  AiService()
      : _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Sanitize Cloud Functions response to avoid Int64 issues on dart2js (web).
  /// Int64 from fixnum is NOT a standard Dart num, so jsonEncode() crashes.
  /// We recursively convert the data structure to native Dart primitives first.
  static Map<String, dynamic> _sanitize(dynamic data) {
    return Map<String, dynamic>.from(_deepSanitize(data) as Map);
  }

  static dynamic _deepSanitize(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is bool) return value;
    if (value is int) return value;
    if (value is double) return value;
    if (value is List) return value.map(_deepSanitize).toList();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _deepSanitize(v)));
    }
    // Int64, Timestamp, or any other non-native type:
    // Try converting via .toInt() first (works for fixnum Int64),
    // then fall back to parsing the string representation.
    try {
      final s = value.toString();
      final asInt = int.tryParse(s);
      if (asInt != null) return asInt;
      final asDouble = double.tryParse(s);
      if (asDouble != null) return asDouble;
      return s;
    } catch (_) {
      return value.toString();
    }
  }

  /// Generate event details via Cloud Function + Vertex AI
  /// All security checks happen server-side
  Future<AiGeneratedEvent> generateEvent({
    required String orgId,
    required String prompt,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('generateEventWithAI', options: HttpsCallableOptions(timeout: const Duration(seconds: 60)))
          .call({'orgId': orgId, 'prompt': prompt});

      final data = _sanitize(result.data);
      if (data['success'] != true || data['event'] == null) {
        throw Exception('AI generation returned no data');
      }

      return AiGeneratedEvent.fromJson(Map<String, dynamic>.from(data['event']));
    } on FirebaseFunctionsException catch (e) {
      // Re-throw with user-friendly messages
      switch (e.code) {
        case 'permission-denied':
          throw Exception('Le funzionalità AI non sono disponibili nel piano Free. Passa a Pro per sbloccarle.');
        case 'resource-exhausted':
          throw Exception('Hai esaurito gli utilizzi AI per questo mese. Passa a Business per utilizzi illimitati.');
        case 'unauthenticated':
          throw Exception('Devi essere autenticato per usare l\'AI.');
        default:
          throw Exception('Errore nella generazione AI. Riprova.');
      }
    }
  }

  /// Get usage stats from the server
  Future<AiUsageStats> getUsageStats({required String orgId}) async {
    try {
      final result = await _functions
          .httpsCallable('getAiUsageStats')
          .call({'orgId': orgId});

      return AiUsageStats.fromJson(_sanitize(result.data));
    } catch (_) {
      // Fallback: return empty stats
      return AiUsageStats(plan: 'free', maxUsages: 0, currentUsage: 0, remaining: 0);
    }
  }

  /// Quick check if AI is available for current plan (client-side pre-check)
  /// Real enforcement is always server-side
  static bool isPlanEligible(SubscriptionPlan plan) => plan.aiEnabled;

  /// Generate email draft via Cloud Function + Vertex AI
  Future<AiGeneratedEmail> generateEmail({
    required String orgId,
    required String eventId,
    required String emailType, // 'reminder', 'followup', 'change', 'custom'
    String? customInstructions,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('generateEmailWithAI', options: HttpsCallableOptions(timeout: const Duration(seconds: 60)))
          .call({
        'orgId': orgId,
        'eventId': eventId,
        'emailType': emailType,
        'customInstructions': customInstructions,
      });

      final data = _sanitize(result.data);
      if (data['success'] != true || data['email'] == null) {
        throw Exception('AI email generation returned no data');
      }

      return AiGeneratedEmail.fromJson(Map<String, dynamic>.from(data['email']));
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'permission-denied':
          throw Exception('Le funzionalità AI non sono disponibili nel piano Free.');
        case 'resource-exhausted':
          throw Exception('Hai esaurito gli utilizzi AI per questo mese.');
        default:
          throw Exception('Errore nella generazione email AI. Riprova.');
      }
    }
  }

  /// Generate event insights via Cloud Function + Vertex AI (Business only)
  Future<AiEventInsights> generateInsights({
    required String orgId,
    required String eventId,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('generateEventInsights', options: HttpsCallableOptions(timeout: const Duration(seconds: 90)))
          .call({'orgId': orgId, 'eventId': eventId});

      final data = _sanitize(result.data);
      if (data['success'] != true || data['insights'] == null) {
        throw Exception('AI insights returned no data');
      }

      return AiEventInsights.fromJson(Map<String, dynamic>.from(data['insights']));
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'permission-denied':
          throw Exception('Event Insights è disponibile esclusivamente nel piano Business.');
        default:
          throw Exception('Errore nella generazione insights. Riprova.');
      }
    }
  }
}

// ─── AI Generated Email ────────────────────────────────────────────

class AiGeneratedEmail {
  final String subject;
  final String body;
  final String tone;

  AiGeneratedEmail({
    required this.subject,
    required this.body,
    this.tone = 'friendly',
  });

  factory AiGeneratedEmail.fromJson(Map<String, dynamic> json) {
    return AiGeneratedEmail(
      subject: json['subject'] ?? '',
      body: json['body'] ?? '',
      tone: json['tone'] ?? 'friendly',
    );
  }
}

// ─── AI Event Insights ─────────────────────────────────────────────

class AiEventInsights {
  final String summary;
  final int overallScore;
  final List<AiInsight> insights;
  final int predictedNoShowRate;
  final String bestRegistrationWindow;
  final Map<String, dynamic> keyMetrics;

  AiEventInsights({
    required this.summary,
    required this.overallScore,
    required this.insights,
    required this.predictedNoShowRate,
    required this.bestRegistrationWindow,
    required this.keyMetrics,
  });

  factory AiEventInsights.fromJson(Map<String, dynamic> json) {
    return AiEventInsights(
      summary: json['summary'] ?? '',
      overallScore: (json['overallScore'] as num?)?.toInt() ?? 0,
      insights: (json['insights'] as List<dynamic>?)
              ?.map((i) => AiInsight.fromJson(Map<String, dynamic>.from(i)))
              .toList() ??
          [],
      predictedNoShowRate: (json['predictedNoShowRate'] as num?)?.toInt() ?? 0,
      bestRegistrationWindow: json['bestRegistrationWindow'] ?? '',
      keyMetrics: Map<String, dynamic>.from(json['keyMetrics'] ?? {}),
    );
  }
}

class AiInsight {
  final String icon;
  final String title;
  final String description;
  final String recommendation;
  final String sentiment;

  AiInsight({
    required this.icon,
    required this.title,
    required this.description,
    required this.recommendation,
    this.sentiment = 'neutral',
  });

  factory AiInsight.fromJson(Map<String, dynamic> json) {
    return AiInsight(
      icon: json['icon'] ?? '📊',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      recommendation: json['recommendation'] ?? '',
      sentiment: json['sentiment'] ?? 'neutral',
    );
  }
}

final aiServiceProvider = Provider<AiService>((ref) => AiService());
