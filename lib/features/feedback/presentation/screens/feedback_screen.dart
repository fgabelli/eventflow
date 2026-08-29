import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eventflow/core/theme/app_theme.dart';

class FeedbackScreen extends StatefulWidget {
  final String eventId;
  const FeedbackScreen({super.key, required this.eventId});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;
  String? _eventTitle;
  String? _eventDate;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();

      if (!doc.exists) {
        setState(() { _notFound = true; _loading = false; });
        return;
      }

      final data = doc.data()!;
      final date = (data['date'] as Timestamp?)?.toDate();
      final formattedDate = date != null
          ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
          : '';

      setState(() {
        _eventTitle = data['title'] ?? 'Evento';
        _eventDate = formattedDate;
        _loading = false;
      });
    } catch (e) {
      setState(() { _notFound = true; _loading = false; });
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno una stella'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('feedback')
          .add({
        'rating': _rating,
        'comment': _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() { _submitted = true; _isSubmitting = false; });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _notFound
                    ? _buildNotFound()
                    : _submitted
                        ? _buildThankYou()
                        : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildNotFound() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 4))],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy, size: 64, color: AppColors.textTertiary),
          SizedBox(height: 16),
          Text('Evento non trovato', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text('Il link potrebbe essere errato o l\'evento non esiste più.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildThankYou() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(36),
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('Grazie per il tuo feedback!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Il tuo parere ci aiuterà a migliorare i prossimi eventi.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => Icon(
              i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
              color: const Color(0xFFF59E0B),
              size: 32,
            )),
          ),
          if (_commentCtrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '"${_commentCtrl.text.trim()}"',
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const Text('💬', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 12),
                const Text(
                  'Lascia il tuo feedback',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  _eventTitle ?? '',
                  style: const TextStyle(fontSize: 15, color: Colors.white70, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                if (_eventDate != null && _eventDate!.isNotEmpty)
                  Text(
                    _eventDate!,
                    style: const TextStyle(fontSize: 13, color: Colors.white54),
                  ),
              ],
            ),
          ),

          // Form body
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                // Stars
                const Text(
                  'Come valuti l\'evento?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return GestureDetector(
                      onTap: () => setState(() => _rating = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: AnimatedScale(
                          scale: i < _rating ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: i < _rating ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB),
                            size: 44,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                if (_rating > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    _ratingLabel(_rating),
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
                const SizedBox(height: 28),

                // Comment
                TextField(
                  controller: _commentCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Lascia un commento (opzionale)...',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Invia feedback', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: const Center(
              child: Text(
                'Powered by Ticketto',
                style: TextStyle(fontSize: 11, color: Color(0xFFD1D5DB)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 1: return '😞 Scarso';
      case 2: return '😐 Sufficiente';
      case 3: return '🙂 Buono';
      case 4: return '😊 Ottimo';
      case 5: return '🤩 Eccellente!';
      default: return '';
    }
  }
}
