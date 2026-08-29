import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/services/ai_service.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';

class AiEmailComposerDialog extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;

  const AiEmailComposerDialog({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  ConsumerState<AiEmailComposerDialog> createState() => _AiEmailComposerDialogState();
}

class _AiEmailComposerDialogState extends ConsumerState<AiEmailComposerDialog> {
  String _selectedType = 'reminder';
  final _customCtrl = TextEditingController();
  AiGeneratedEmail? _generatedEmail;
  bool _isGenerating = false;
  String? _error;

  late TextEditingController _subjectCtrl;
  late TextEditingController _bodyCtrl;

  @override
  void initState() {
    super.initState();
    _subjectCtrl = TextEditingController();
    _bodyCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateEmail() async {
    final org = ref.read(currentOrgProvider).value;
    if (org == null) return;

    setState(() {
      _isGenerating = true;
      _error = null;
      _generatedEmail = null;
    });

    try {
      final aiService = ref.read(aiServiceProvider);
      final result = await aiService.generateEmail(
        orgId: org.id,
        eventId: widget.eventId,
        emailType: _selectedType,
        customInstructions: _selectedType == 'custom' ? _customCtrl.text.trim() : null,
      );

      _subjectCtrl.text = result.subject;
      _bodyCtrl.text = result.body;

      setState(() {
        _generatedEmail = result;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
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
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mail_outline, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Smart Email Composer',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(widget.eventTitle,
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _generatedEmail == null
                ? _buildTypeSelection()
                : _buildResultView(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Che tipo di email vuoi inviare?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 16),

          _buildEmailTypeCard(
            'reminder', Icons.notifications_active_outlined,
            'Reminder Pre-Evento',
            'Ricorda ai partecipanti i dettagli dell\'evento',
          ),
          _buildEmailTypeCard(
            'followup', Icons.favorite_outline,
            'Follow-up Post-Evento',
            'Ringrazia e chiedi un feedback',
          ),
          _buildEmailTypeCard(
            'change', Icons.edit_notifications_outlined,
            'Comunicazione Cambio',
            'Informa di modifiche a orario, luogo o dettagli',
          ),
          _buildEmailTypeCard(
            'custom', Icons.auto_fix_high_outlined,
            'Email Personalizzata',
            'Scrivi istruzioni specifiche per l\'AI',
          ),

          if (_selectedType == 'custom') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Es: Invita i partecipanti a portare un amico con uno sconto del 20%...',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary.withValues(alpha: 0.6)),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_error!, style: TextStyle(fontSize: 12, color: AppColors.error)),
            ),
          ],

          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isGenerating ? null : _generateEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isGenerating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 12),
                        Text('Generazione in corso...', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 20),
                        SizedBox(width: 8),
                        Text('Genera Email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailTypeCard(String type, IconData icon, String title, String subtitle) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isSelected ? AppColors.primary : AppColors.textTertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  )),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Generated badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'Tono: ${_generatedEmail!.tone}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Subject
                Text('Oggetto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                TextField(controller: _subjectCtrl),
                const SizedBox(height: 16),

                // Body
                Text('Corpo Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                TextField(controller: _bodyCtrl, maxLines: 10),
              ],
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _generatedEmail = null;
                    _error = null;
                  }),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('← Rigenera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final text = 'Oggetto: ${_subjectCtrl.text}\n\n${_bodyCtrl.text}';
                    Clipboard.setData(ClipboardData(text: text));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✉️ Email copiata negli appunti!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copia Email', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
