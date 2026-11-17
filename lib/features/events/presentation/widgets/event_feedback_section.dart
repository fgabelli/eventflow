import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/theme/app_theme.dart';

class EventFeedbackSection extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const EventFeedbackSection({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<EventFeedbackSection> createState() => _EventFeedbackSectionState();
}

class _EventFeedbackSectionState extends State<EventFeedbackSection> {
  static const int _collapsedLimit = 5;
  bool _showAll = false;

  void _exportCsv(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final rows = <List<dynamic>>[
      ['Data', 'Valutazione (1-5)', 'Commento'],
    ];

    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    for (final doc in docs) {
      final data = doc.data();
      final rating = (data['rating'] as num?)?.toInt() ?? 0;
      final comment = (data['comment'] as String?)?.trim() ?? '';
      final ts = data['createdAt'] as Timestamp?;
      final dateStr = ts != null ? dateFmt.format(ts.toDate()) : '';
      rows.add([dateStr, rating, comment]);
    }

    final csvString = '\uFEFF${CsvCodec().encoder.convert(rows)}';
    if (kIsWeb) {
      final safeSlug = widget.eventTitle
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      final filename = 'feedback_${safeSlug.isEmpty ? widget.eventId : safeSlug}.csv';
      final bytes = utf8.encode(csvString);
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback esportati in CSV'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Widget _buildStarRow(double rating, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        IconData icon;
        if (rating >= starIndex) {
          icon = Icons.star_rounded;
        } else if (rating >= starIndex - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(
          icon,
          size: size,
          color: rating >= starIndex - 0.5 ? Colors.amber.shade600 : AppColors.textTertiary,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(Collections.events)
          .doc(widget.eventId)
          .collection('feedback')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final count = docs.length;
        final avgRating = count == 0
            ? 0.0
            : docs.fold<int>(
                  0,
                  (total, d) => total + ((d.data()['rating'] as num?)?.toInt() ?? 0),
                ) /
                count;

        final visibleDocs = _showAll ? docs : docs.take(_collapsedLimit).toList();
        final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rate_review_outlined, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Feedback partecipanti',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (count > 0 && kIsWeb)
                    TextButton.icon(
                      onPressed: () => _exportCsv(docs),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Esporta CSV', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting && docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Impossibile caricare i feedback: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                )
              else if (count == 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Nessun feedback ricevuto finora. I partecipanti possono lasciare una valutazione tramite il link nell\'email di ringraziamento.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStarRow(avgRating, size: 18),
                          const SizedBox(height: 2),
                          Text(
                            count == 1 ? '1 risposta' : '$count risposte',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...visibleDocs.map((doc) {
                  final data = doc.data();
                  final rating = (data['rating'] as num?)?.toInt() ?? 0;
                  final comment = (data['comment'] as String?)?.trim();
                  final ts = data['createdAt'] as Timestamp?;
                  final dateLabel = ts != null ? dateFmt.format(ts.toDate()) : '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildStarRow(rating.toDouble(), size: 16),
                            const Spacer(),
                            if (dateLabel.isNotEmpty)
                              Text(
                                dateLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          (comment != null && comment.isNotEmpty) ? comment : 'Nessun commento',
                          style: TextStyle(
                            fontSize: 13,
                            color: (comment != null && comment.isNotEmpty)
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                            fontStyle: (comment != null && comment.isNotEmpty)
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (count > _collapsedLimit)
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _showAll = !_showAll),
                      child: Text(
                        _showAll ? 'Mostra meno' : 'Mostra tutti ($count)',
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
