import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/services/ai_service.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';

class AiEventInsightsDialog extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;

  const AiEventInsightsDialog({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  ConsumerState<AiEventInsightsDialog> createState() => _AiEventInsightsDialogState();
}

class _AiEventInsightsDialogState extends ConsumerState<AiEventInsightsDialog> {
  AiEventInsights? _insights;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    final org = ref.read(currentOrgProvider).value;
    if (org == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final aiService = ref.read(aiServiceProvider);
      final result = await aiService.generateInsights(
        orgId: org.id,
        eventId: widget.eventId,
      );
      if (mounted) setState(() { _insights = result; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.insights, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI Event Insights',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(widget.eventTitle,
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Business', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? _buildLoading()
                : _error != null
                    ? _buildError()
                    : _buildInsightsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 40, height: 40,
              child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 20),
          Text('L\'AI sta analizzando i dati del tuo evento...',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Questo può richiedere qualche secondo',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadInsights,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsView() {
    final insights = _insights!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Overall Score
          _buildScoreCard(insights.overallScore),
          const SizedBox(height: 20),

          // Key Metrics Row
          Row(
            children: [
              _buildMetricChip('Capacità', '${insights.keyMetrics['capacityRate'] ?? 0}%', Icons.people_outline),
              const SizedBox(width: 10),
              _buildMetricChip('Check-in', '${insights.keyMetrics['checkInRate'] ?? 0}%', Icons.check_circle_outline),
              const SizedBox(width: 10),
              _buildMetricChip('No-Show', '${insights.keyMetrics['noShowRate'] ?? 0}%', Icons.person_off_outlined),
            ],
          ),
          const SizedBox(height: 20),

          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.summarize_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text('Riepilogo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(insights.summary,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Insights list
          const Text('Analisi Dettagliata', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          ...insights.insights.map((insight) => _buildInsightCard(insight)),

          const SizedBox(height: 16),

          // Predictions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF06B6D4).withValues(alpha: 0.08),
                  const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🔮', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('Predizioni AI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPredictionRow(
                  'Tasso No-Show previsto',
                  '${insights.predictedNoShowRate}%',
                  Icons.trending_down,
                ),
                const SizedBox(height: 8),
                _buildPredictionRow(
                  'Finestra registrazioni migliore',
                  insights.bestRegistrationWindow,
                  Icons.calendar_today,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildScoreCard(int score) {
    Color scoreColor;
    String scoreLabel;
    if (score >= 80) {
      scoreColor = AppColors.success;
      scoreLabel = 'Eccellente';
    } else if (score >= 60) {
      scoreColor = const Color(0xFFF59E0B);
      scoreLabel = 'Buono';
    } else if (score >= 40) {
      scoreColor = const Color(0xFFF97316);
      scoreLabel = 'Da Migliorare';
    } else {
      scoreColor = AppColors.error;
      scoreLabel = 'Critico';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scoreColor.withValues(alpha: 0.08), scoreColor.withValues(alpha: 0.02)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64, height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64, height: 64,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 5,
                    color: scoreColor,
                    backgroundColor: scoreColor.withValues(alpha: 0.15),
                  ),
                ),
                Text('$score', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scoreColor)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Performance Score', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                const SizedBox(height: 4),
                Text(scoreLabel, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: scoreColor)),
                Text('Basato su capacità, check-in e engagement',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(AiInsight insight) {
    Color sentimentColor;
    switch (insight.sentiment) {
      case 'positive':
        sentimentColor = AppColors.success;
        break;
      case 'negative':
        sentimentColor = AppColors.error;
        break;
      default:
        sentimentColor = const Color(0xFFF59E0B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(insight.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(insight.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: sentimentColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(insight.description,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(insight.recommendation,
                      style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8B5CF6)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
