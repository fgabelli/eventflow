import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/services/ai_service.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';
import 'package:eventflow/features/events/presentation/screens/events_screen.dart';

class AiEventCreatorDialog extends ConsumerStatefulWidget {
  const AiEventCreatorDialog({super.key});

  @override
  ConsumerState<AiEventCreatorDialog> createState() => _AiEventCreatorDialogState();
}

class _AiEventCreatorDialogState extends ConsumerState<AiEventCreatorDialog> {
  final _promptController = TextEditingController();
  AiGeneratedEvent? _generatedEvent;
  bool _isGenerating = false;
  bool _isCreating = false;
  String? _error;
  AiUsageStats? _usageStats;
  bool _loadingUsages = true;

  // Editable fields after generation
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _maxAttendeesCtrl;
  late TextEditingController _priceCtrl;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  bool _isPaid = false;
  bool _hasTimeSlots = false;
  List<TimeSlot> _timeSlots = [];
  List<CustomField> _customFields = [];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    _maxAttendeesCtrl = TextEditingController(text: '50');
    _priceCtrl = TextEditingController();
    _loadRemainingUsages();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _maxAttendeesCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRemainingUsages() async {
    final org = ref.read(currentOrgProvider).value;
    if (org == null) return;
    
    final aiService = ref.read(aiServiceProvider);
    final stats = await aiService.getUsageStats(orgId: org.id);
    
    if (mounted) {
      setState(() {
        _usageStats = stats;
        _loadingUsages = false;
      });
    }
  }

  Future<void> _generateEvent() async {
    if (_promptController.text.trim().isEmpty) return;

    final org = ref.read(currentOrgProvider).value;
    if (org == null) return;

    setState(() {
      _isGenerating = true;
      _error = null;
      _generatedEvent = null;
    });

    try {
      final aiService = ref.read(aiServiceProvider);
      
      // Call Cloud Function — all checks (auth, plan, limits) happen server-side
      final result = await aiService.generateEvent(
        orgId: org.id,
        prompt: _promptController.text.trim(),
      );

      // Populate editable fields
      _titleCtrl.text = result.title;
      _descCtrl.text = result.description;
      _locationCtrl.text = result.location ?? '';
      final plan = org.plan;
      final aiMax = result.maxAttendees;
      final clampedMax = plan.isUnlimitedAttendees ? aiMax : aiMax.clamp(1, plan.maxAttendeesPerEvent);
      _maxAttendeesCtrl.text = clampedMax.toString();
      _isPaid = result.isPaid;
      if (result.price != null) _priceCtrl.text = result.price!.toStringAsFixed(2);

      // Convert suggested custom fields
      _customFields = result.suggestedCustomFields.map((f) => CustomField(
        label: f['label'] ?? '',
        type: f['type'] ?? 'text',
        required: f['required'] ?? false,
        placeholder: f['placeholder'],
        options: f['options'] != null ? List<String>.from(f['options']) : null,
      )).toList();

      // Convert suggested time slots
      if (result.suggestedTimeSlots.isNotEmpty) {
        _hasTimeSlots = true;
        _timeSlots = result.suggestedTimeSlots.map((s) => TimeSlot(
          id: DateTime.now().millisecondsSinceEpoch.toString() + (s['label'] ?? ''),
          label: s['label'] ?? '',
          startTime: s['startTime'] ?? '09:00',
          endTime: s['endTime'] ?? '10:00',
          maxCapacity: (s['maxCapacity'] as num?)?.toInt() ?? 20,
        )).toList();
      }

      setState(() {
        _generatedEvent = result;
        _isGenerating = false;
      });
      
      // Refresh usage stats from server
      _loadRemainingUsages();
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _createEvent() async {
    if (_titleCtrl.text.trim().isEmpty) return;

    final org = ref.read(currentOrgProvider).value;
    if (org == null) return;

    setState(() => _isCreating = true);

    final eventDate = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute,
    );

    try {
      await ref.read(eventsServiceProvider).createEvent(EventModel(
        id: '',
        orgId: org.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        date: eventDate,
        location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        status: EventStatus.draft,
        maxAttendees: () {
          final plan = org.plan;
          final parsed = int.tryParse(_maxAttendeesCtrl.text) ?? 50;
          return plan.isUnlimitedAttendees ? parsed : parsed.clamp(1, plan.maxAttendeesPerEvent);
        }(),
        isPaid: _isPaid,
        price: _isPaid ? double.tryParse(_priceCtrl.text) : null,
        hasTimeSlots: _hasTimeSlots,
        timeSlots: _hasTimeSlots ? _timeSlots : [],
        customFields: _customFields,
      ));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Evento creato con AI!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
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
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Event Creator',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      if (!_loadingUsages && _usageStats != null)
                        Text(
                          _usageStats!.isUnlimited
                              ? 'Utilizzi illimitati'
                              : '${_usageStats!.remaining} utilizzi rimasti questo mese',
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
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

          // Content
          Expanded(
            child: _generatedEvent == null
                ? _buildPromptView()
                : _buildResultView(),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Prompt input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Descrivi il tuo evento',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scrivi in linguaggio naturale e l\'AI creerà il tuo evento',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _promptController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Es: Workshop di ceramica il 20 marzo a Roma, max 25 persone, 35€ a partecipante, con 2 turni mattina e pomeriggio...',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Quick suggestions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSuggestionChip('🎨 Workshop creativo'),
              _buildSuggestionChip('🍷 Degustazione vini'),
              _buildSuggestionChip('💼 Conferenza aziendale'),
              _buildSuggestionChip('🎉 Festa privata'),
              _buildSuggestionChip('🏃 Evento sportivo'),
              _buildSuggestionChip('🎵 Concerto'),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Server-side badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Text(
                  'AI sicura — elaborazione server-side via Vertex AI',
                  style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Generate button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isGenerating ? null : _generateEvent,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isGenerating
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Text('L\'AI sta creando il tuo evento...', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 20),
                        SizedBox(width: 8),
                        Text('Genera con AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label) {
    return InkWell(
      onTap: () {
        _promptController.text = label.substring(2).trim();
        _promptController.selection = TextSelection.fromPosition(
          TextPosition(offset: _promptController.text.length),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
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
                // AI Generated badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Generato con AI — modifica i campi prima di creare',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                _buildLabel('Titolo Evento *'),
                TextField(controller: _titleCtrl),
                const SizedBox(height: 16),

                // Description
                _buildLabel('Descrizione'),
                TextField(controller: _descCtrl, maxLines: 3),
                const SizedBox(height: 16),

                // Date & Time
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Data'),
                          InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2030),
                              );
                              if (date != null) setState(() => _selectedDate = date);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: const InputDecoration(),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18, color: AppColors.textTertiary),
                                  const SizedBox(width: 8),
                                  Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Ora'),
                          InkWell(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _selectedTime,
                              );
                              if (time != null) setState(() => _selectedTime = time);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: const InputDecoration(),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 18, color: AppColors.textTertiary),
                                  const SizedBox(width: 8),
                                  Text('${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Location
                _buildLabel('Location'),
                TextField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Max Attendees
                _buildLabel('Max Partecipanti'),
                TextField(
                  controller: _maxAttendeesCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.people_outline),
                    helperText: () {
                      final plan = ref.read(currentOrgProvider).value?.plan ?? SubscriptionPlan.free;
                      return plan.isUnlimitedAttendees ? 'Illimitati' : 'Max ${plan.maxAttendeesPerEvent} (piano ${plan.label})';
                    }(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Paid toggle
                if (_isPaid) ...[
                  _buildLabel('Prezzo'),
                  TextField(
                    controller: _priceCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.euro),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                ],

                // AI-suggested custom fields
                if (_customFields.isNotEmpty) ...[
                  _buildLabel('Campi personalizzati suggeriti'),
                  const SizedBox(height: 8),
                  ...List.generate(_customFields.length, (i) {
                    final field = _customFields[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            field.type == 'select' ? Icons.list_rounded
                                : field.type == 'checkbox' ? Icons.check_box_outlined
                                : field.type == 'number' ? Icons.numbers
                                : Icons.text_fields,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  field.label,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${field.typeLabel}${field.required ? ' • Obbligatorio' : ''}',
                                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 18, color: AppColors.textTertiary),
                            onPressed: () => setState(() => _customFields.removeAt(i)),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                // AI-suggested time slots
                if (_hasTimeSlots && _timeSlots.isNotEmpty) ...[
                  _buildLabel('Fasce orarie suggerite'),
                  const SizedBox(height: 8),
                  ...List.generate(_timeSlots.length, (i) {
                    final slot = _timeSlots[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(slot.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text(
                                  '${slot.startTime} – ${slot.endTime} • Max ${slot.maxCapacity}',
                                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 18, color: AppColors.textTertiary),
                            onPressed: () {
                              setState(() {
                                _timeSlots.removeAt(i);
                                if (_timeSlots.isEmpty) _hasTimeSlots = false;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),

        // Bottom actions
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
                    _generatedEvent = null;
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
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isCreating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Crea Evento', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
