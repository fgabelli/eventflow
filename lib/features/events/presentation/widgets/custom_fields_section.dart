import 'package:flutter/material.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/core/widgets/ticket_badge.dart';
import 'package:eventflow/core/widgets/help_tip.dart';
import 'package:eventflow/core/utils/feature_gate.dart';

/// Reusable section for managing custom registration fields.
/// Used both in event creation dialogs and in the event edit screen.
class CustomFieldsSection extends StatelessWidget {
  final List<CustomField> fields;
  final ValueChanged<List<CustomField>> onChanged;
  final bool hasAttendees;
  final SubscriptionPlan plan;
  final Color? backgroundColor;

  const CustomFieldsSection({
    super.key,
    required this.fields,
    required this.onChanged,
    required this.hasAttendees,
    required this.plan,
    this.backgroundColor,
  });

  static IconData fieldTypeIcon(String type) {
    switch (type) {
      case 'text':
        return Icons.short_text_rounded;
      case 'select':
        return Icons.list_rounded;
      case 'number':
        return Icons.tag_rounded;
      case 'checkbox':
        return Icons.check_box_rounded;
      case 'email':
        return Icons.email_rounded;
      case 'phone':
        return Icons.phone_rounded;
      default:
        return Icons.text_fields_rounded;
    }
  }

  static String localizedTypeLabel(BuildContext context, String type) {
    final l = AppLocalizations.of(context);
    switch (type) {
      case 'text':
        return l['custom_field_type_text'];
      case 'select':
        return l['custom_field_type_select'];
      case 'number':
        return l['custom_field_type_number'];
      case 'checkbox':
        return l['custom_field_type_checkbox'];
      case 'email':
        return l['custom_field_type_email'];
      case 'phone':
        return l['custom_field_type_phone'];
      default:
        return type;
    }
  }

  void _moveUp(int index) {
    if (index <= 0) return;
    final updated = List<CustomField>.from(fields);
    final item = updated.removeAt(index);
    updated.insert(index - 1, item);
    onChanged(updated);
  }

  void _moveDown(int index) {
    if (index >= fields.length - 1) return;
    final updated = List<CustomField>.from(fields);
    final item = updated.removeAt(index);
    updated.insert(index + 1, item);
    onChanged(updated);
  }

  Future<void> _deleteField(BuildContext context, int index) async {
    final l = AppLocalizations.of(context);
    if (hasAttendees) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l['delete_field_title']),
          content: Text(l['delete_field_confirm_attendees']),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l['cancel']),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l['delete']),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final updated = List<CustomField>.from(fields);
    updated.removeAt(index);
    onChanged(updated);
  }

  void _editField(BuildContext context, int index, CustomField field) {
    if (plan.isFree) {
      checkFeatureAccess(
        context: context,
        currentPlan: plan,
        requiredPlan: SubscriptionPlan.pro,
        featureName: AppLocalizations.of(context)['custom_fields_label'],
      );
      return;
    }
    _showCustomFieldDialog(
      context: context,
      existingField: field,
      hasAttendees: hasAttendees,
      onSave: (updatedField) {
        final updated = List<CustomField>.from(fields);
        updated[index] = updatedField;
        onChanged(updated);
      },
    );
  }

  void _addField(BuildContext context) {
    _showCustomFieldDialog(
      context: context,
      existingField: null,
      hasAttendees: hasAttendees,
      onSave: (newField) {
        final updated = List<CustomField>.from(fields)..add(newField);
        onChanged(updated);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sectionBg = backgroundColor ?? AppColors.card;
    final itemBg = sectionBg == AppColors.surface ? AppColors.card : AppColors.surface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dynamic_form_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(l['custom_fields_label'], style: Theme.of(context).textTheme.titleMedium),
                        if (plan.isFree) ...[
                          const SizedBox(width: 6),
                          const TicketBadge(label: 'PRO'),
                        ],
                        HelpTip(text: l['help_custom_fields']),
                      ],
                    ),
                    Text(
                      l['custom_fields_desc'],
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (fields.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...fields.asMap().entries.map((entry) {
              final i = entry.key;
              final field = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: itemBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(fieldTypeIcon(field.type), size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => _editField(context, i, field),
                        borderRadius: BorderRadius.circular(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    field.label,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (field.required) ...[
                                  const SizedBox(width: 4),
                                  const Text('*', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    localizedTypeLabel(context, field.type),
                                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                if (field.type == 'select' && field.options != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    l['options_count'].replaceAll('{count}', field.options!.length.toString()),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (fields.length > 1) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 16),
                        tooltip: l['move_up'],
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: i > 0 ? () => _moveUp(i) : null,
                        color: i > 0 ? AppColors.textSecondary : AppColors.textTertiary.withValues(alpha: 0.3),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 16),
                        tooltip: l['move_down'],
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: i < fields.length - 1 ? () => _moveDown(i) : null,
                        color: i < fields.length - 1 ? AppColors.textSecondary : AppColors.textTertiary.withValues(alpha: 0.3),
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      tooltip: l['edit_field'],
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => _editField(context, i, field),
                      color: AppColors.primary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 17),
                      tooltip: l['delete_field_title'],
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => _deleteField(context, i),
                      color: AppColors.error,
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              if (plan.isFree) {
                checkFeatureAccess(
                  context: context,
                  currentPlan: plan,
                  requiredPlan: SubscriptionPlan.pro,
                  featureName: l['custom_fields_label'],
                );
                return;
              }
              _addField(context);
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text(l['add_field']),
          ),
        ],
      ),
    );
  }

  static void _showCustomFieldDialog({
    required BuildContext context,
    CustomField? existingField,
    required bool hasAttendees,
    required ValueChanged<CustomField> onSave,
  }) {
    final l = AppLocalizations.of(context);
    final isEditing = existingField != null;
    final labelCtrl = TextEditingController(text: existingField?.label ?? '');
    final placeholderCtrl = TextEditingController(text: existingField?.placeholder ?? '');
    String selectedType = existingField?.type ?? 'text';
    bool isRequired = existingField?.required ?? false;
    final List<String> options = List<String>.from(existingField?.options ?? []);
    final optionCtrl = TextEditingController();
    final initialType = existingField?.type;
    String? validationError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? l['edit_field'] : l['add_field']),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field label
                    TextField(
                      controller: labelCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: l['field_name_label'],
                        hintText: l['field_name_hint'],
                      ),
                      onChanged: (_) {
                        if (validationError != null) {
                          setDialogState(() => validationError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Field type
                    Text(l['field_type_label'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _typeChip(
                          'text',
                          l['custom_field_type_text'],
                          Icons.short_text_rounded,
                          selectedType,
                          (v) => _handleTypeSelection(ctx, setDialogState, v, selectedType, initialType, hasAttendees, (newT) => selectedType = newT),
                        ),
                        _typeChip(
                          'select',
                          l['custom_field_type_select'],
                          Icons.list_rounded,
                          selectedType,
                          (v) => _handleTypeSelection(ctx, setDialogState, v, selectedType, initialType, hasAttendees, (newT) => selectedType = newT),
                        ),
                        _typeChip(
                          'number',
                          l['custom_field_type_number'],
                          Icons.tag_rounded,
                          selectedType,
                          (v) => _handleTypeSelection(ctx, setDialogState, v, selectedType, initialType, hasAttendees, (newT) => selectedType = newT),
                        ),
                        _typeChip(
                          'checkbox',
                          l['custom_field_type_checkbox'],
                          Icons.check_box_rounded,
                          selectedType,
                          (v) => _handleTypeSelection(ctx, setDialogState, v, selectedType, initialType, hasAttendees, (newT) => selectedType = newT),
                        ),
                        _typeChip(
                          'email',
                          l['custom_field_type_email'],
                          Icons.email_rounded,
                          selectedType,
                          (v) => _handleTypeSelection(ctx, setDialogState, v, selectedType, initialType, hasAttendees, (newT) => selectedType = newT),
                        ),
                        _typeChip(
                          'phone',
                          l['custom_field_type_phone'],
                          Icons.phone_rounded,
                          selectedType,
                          (v) => _handleTypeSelection(ctx, setDialogState, v, selectedType, initialType, hasAttendees, (newT) => selectedType = newT),
                        ),
                      ],
                    ),

                    if (isEditing && hasAttendees && selectedType != initialType) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l['change_field_type_warning_inline'],
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Placeholder (hidden for checkbox)
                    if (selectedType != 'checkbox') ...[
                      TextField(
                        controller: placeholderCtrl,
                        decoration: InputDecoration(
                          labelText: l['field_placeholder_label'],
                          hintText: l['field_placeholder_hint'],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Required toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l['field_required_label'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        Switch(
                          value: isRequired,
                          onChanged: (v) => setDialogState(() => isRequired = v),
                          activeThumbColor: AppColors.primary,
                        ),
                      ],
                    ),

                    // Options (for select type)
                    if (selectedType == 'select') ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(l['options_label'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...options.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 6, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.value, style: const TextStyle(fontSize: 14))),
                            InkWell(
                              onTap: () => setDialogState(() => options.removeAt(e.key)),
                              child: const Icon(Icons.close, size: 16, color: AppColors.error),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: optionCtrl,
                              decoration: InputDecoration(
                                hintText: l['field_options_hint'],
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              onSubmitted: (v) {
                                if (v.trim().isNotEmpty) {
                                  setDialogState(() {
                                    options.add(v.trim());
                                    optionCtrl.clear();
                                    validationError = null;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              if (optionCtrl.text.trim().isNotEmpty) {
                                setDialogState(() {
                                  options.add(optionCtrl.text.trim());
                                  optionCtrl.clear();
                                  validationError = null;
                                });
                              }
                            },
                            icon: const Icon(Icons.add_circle, color: AppColors.primary),
                            iconSize: 22,
                          ),
                        ],
                      ),
                    ],

                    if (validationError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        validationError!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l['cancel']),
              ),
              FilledButton(
                onPressed: () {
                  if (labelCtrl.text.trim().isEmpty) {
                    setDialogState(() => validationError = l['required_field']);
                    return;
                  }
                  if (selectedType == 'select' && options.isEmpty) {
                    setDialogState(() => validationError = l['options_required_error']);
                    return;
                  }

                  // Existing fields retain their exact id; new fields generate a fresh timestamp id
                  final field = CustomField(
                    id: existingField?.id,
                    label: labelCtrl.text.trim(),
                    type: selectedType,
                    required: isRequired,
                    options: selectedType == 'select' ? List.from(options) : null,
                    placeholder: placeholderCtrl.text.trim().isEmpty ? null : placeholderCtrl.text.trim(),
                  );
                  onSave(field);
                  Navigator.pop(ctx);
                },
                child: Text(isEditing ? l['save'] : l['add']),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> _handleTypeSelection(
    BuildContext ctx,
    StateSetter setDialogState,
    String newType,
    String currentSelected,
    String? initialType,
    bool hasAttendees,
    ValueChanged<String> onSelected,
  ) async {
    if (newType == currentSelected) return;

    if (initialType != null && hasAttendees && newType != initialType) {
      final l = AppLocalizations.of(ctx);
      final confirm = await showDialog<bool>(
        context: ctx,
        builder: (c) => AlertDialog(
          title: Text(l['change_field_type_title']),
          content: Text(l['change_field_type_confirm_attendees']),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l['cancel']),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l['continue_label']),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setDialogState(() {
      onSelected(newType);
    });
  }

  static Widget _typeChip(
    String value,
    String label,
    IconData icon,
    String selected,
    ValueChanged<String> onTap,
  ) {
    final isActive = value == selected;
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? AppColors.primary : AppColors.textTertiary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
