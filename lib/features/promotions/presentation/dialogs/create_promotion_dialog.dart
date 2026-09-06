import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/core/utils/feature_gate.dart';

class CreatePromotionDialog extends ConsumerStatefulWidget {
  final Organization org;
  final List<PromotionModel> existingPromotions;

  const CreatePromotionDialog({
    super.key,
    required this.org,
    required this.existingPromotions,
  });

  @override
  ConsumerState<CreatePromotionDialog> createState() => _CreatePromotionDialogState();
}

class _CreatePromotionDialogState extends ConsumerState<CreatePromotionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _partnerCtrl = TextEditingController();
  final _partnerLogoCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController(text: 'PROMO');
  final _quantityCtrl = TextEditingController(text: '25');
  final _priceCtrl = TextEditingController();
  final _discountValueCtrl = TextEditingController();
  final _customValidityCtrl = TextEditingController(text: '30');

  bool _isPartnership = false;
  bool _isUploadingPartnerLogo = false;
  OfferType _selectedOfferType = OfferType.twoForOne;
  PromotionPaymentMethod _selectedPaymentMethod = PromotionPaymentMethod.atVenue;
  DateTime _expirationDate = DateTime.now().add(const Duration(days: 90));
  int _validityDays = 30;
  bool _isCustomValidity = false;
  String? _selectedEventId;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _partnerCtrl.dispose();
    _partnerLogoCtrl.dispose();
    _prefixCtrl.dispose();
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    _discountValueCtrl.dispose();
    _customValidityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPartnerLogo() async {
    try {
      setState(() => _isUploadingPartnerLogo = true);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final name = result.files.single.name;
        final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'png';
        final mimeType = ext == 'svg'
            ? 'image/svg+xml'
            : (ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'image/png');
        final base64String = base64Encode(bytes);
        _partnerLogoCtrl.text = 'data:$mimeType;base64,$base64String';
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore selezione file: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPartnerLogo = false);
    }
  }

  Widget _buildPartnerLogoPreview(String logoData) {
    if (logoData.startsWith('data:image')) {
      final commaIdx = logoData.indexOf(',');
      if (commaIdx != -1) {
        try {
          final bytes = base64Decode(logoData.substring(commaIdx + 1));
          return Image.memory(bytes, fit: BoxFit.cover);
        } catch (_) {}
      }
    } else if (logoData.startsWith('http://') || logoData.startsWith('https://')) {
      return Image.network(
        logoData,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined, size: 20),
      );
    }
    return const Icon(Icons.image_outlined, size: 20);
  }

  Future<void> _pickExpirationDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() {
        _expirationDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final plan = widget.org.plan;
    final prefix = _prefixCtrl.text.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final quantity = int.tryParse(_quantityCtrl.text.trim()) ?? 25;

    // Check plan limits
    if (!plan.isUnlimitedVouchers && quantity > plan.maxVouchersPerPromotion) {
      setState(() {
        _errorMessage = 'Il tuo piano ${plan.label} permette massimo ${plan.maxVouchersPerPromotion} voucher per offerta.';
      });
      return;
    }

    if (_selectedPaymentMethod == PromotionPaymentMethod.online && !plan.canOnlinePromotionPayment) {
      canUseOnlinePaymentForPromotion(context, plan);
      return;
    }

    // Check unique prefix across active promotions of this organization
    final prefixExists = widget.existingPromotions.any(
      (p) => p.codePrefix == prefix && p.status == PromotionStatus.active,
    );
    if (prefixExists) {
      setState(() {
        _errorMessage = 'Esiste già una promozione attiva con il prefisso "$prefix". Scegline uno diverso.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final promoDocRef = db.collection(Collections.promotions).doc();

      final finalValidityDays = _isCustomValidity
          ? (int.tryParse(_customValidityCtrl.text.trim()) ?? 30)
          : _validityDays;

      final promo = PromotionModel(
        id: promoDocRef.id,
        orgId: widget.org.id,
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
        partnerName: _isPartnership && _partnerCtrl.text.trim().isNotEmpty ? _partnerCtrl.text.trim() : null,
        partnerLogoUrl: _isPartnership && _partnerLogoCtrl.text.trim().isNotEmpty ? _partnerLogoCtrl.text.trim() : null,
        codePrefix: prefix,
        currentSequence: quantity,
        totalVouchers: quantity,
        claimedCount: 0,
        redeemedCount: 0,
        expirationDate: _expirationDate,
        validityDays: finalValidityDays,
        offerType: _selectedOfferType,
        discountValue: double.tryParse(_discountValueCtrl.text.trim()),
        price: double.tryParse(_priceCtrl.text.trim()),
        paymentMethod: _selectedPaymentMethod,
        linkedEventId: _selectedEventId,
        status: PromotionStatus.active,
      );

      // Save promotion document
      await promoDocRef.set(promo.toFirestore());

      // Batch create sequential vouchers
      // Format code as PREFIX-0001, PREFIX-0002, etc. (with 4-digit padding)
      const int batchLimit = 400;
      WriteBatch currentBatch = db.batch();
      int batchCount = 0;

      for (int i = 1; i <= quantity; i++) {
        final codeNumber = i.toString().padLeft(4, '0');
        final voucherCode = '$prefix-$codeNumber';
        final voucherDocId = '${widget.org.id}_$voucherCode';
        final voucherRef = db.collection(Collections.vouchers).doc(voucherDocId);

        final voucher = VoucherModel(
          id: voucherDocId,
          promoId: promoDocRef.id,
          orgId: widget.org.id,
          code: voucherCode,
          sequenceNumber: i,
          status: VoucherStatus.available,
          paymentStatus: _selectedPaymentMethod == PromotionPaymentMethod.online
              ? VoucherPaymentStatus.pending
              : _selectedPaymentMethod == PromotionPaymentMethod.atVenue
                  ? VoucherPaymentStatus.pending
                  : VoucherPaymentStatus.notRequired,
        );

        currentBatch.set(voucherRef, voucher.toFirestore());
        batchCount++;

        if (batchCount >= batchLimit) {
          await currentBatch.commit();
          currentBatch = db.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await currentBatch.commit();
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore durante la creazione dell\'offerta: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.org.plan;
    final maxVouchers = plan.isUnlimitedVouchers ? 500 : plan.maxVouchersPerPromotion;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)['new_promotion_btn'],
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Crea una convenzione e genera coupon con QR code sequenziali',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],

                // Offer Title
                TextFormField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: '${AppLocalizations.of(context)['offer_title']} *',
                    hintText: AppLocalizations.of(context)['offer_title_hint'],
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Inserisci un titolo per l\'offerta' : null,
                ),
                const SizedBox(height: 16),

                // Partnership Switch (Internal vs Collaboration)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isPartnership ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isPartnership ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.handshake_rounded,
                        color: _isPartnership ? AppColors.primary : AppColors.textSecondary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)['is_partnership_toggle'],
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppLocalizations.of(context)['is_partnership_subtitle'],
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPartnership,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) => setState(() => _isPartnership = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // If Partnership enabled: Partner Name & Partner Logo
                if (_isPartnership) ...[
                  TextFormField(
                    controller: _partnerCtrl,
                    decoration: InputDecoration(
                      labelText: '${AppLocalizations.of(context)['partner_name']} *',
                      hintText: AppLocalizations.of(context)['partner_hint'],
                      prefixIcon: const Icon(Icons.business_rounded),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      if (_isPartnership && (v == null || v.trim().isEmpty)) {
                        return 'Inserisci il nome del partner della convenzione';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Partner Logo input & upload button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _partnerLogoCtrl,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)['partner_logo_label'],
                            hintText: AppLocalizations.of(context)['partner_logo_hint'],
                            prefixIcon: const Icon(Icons.image_outlined),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _isUploadingPartnerLogo ? null : _pickPartnerLogo,
                        icon: _isUploadingPartnerLogo
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.upload_file_rounded, size: 18),
                        label: Text(AppLocalizations.of(context)['upload_partner_logo']),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      if (_partnerLogoCtrl.text.trim().isNotEmpty) ...[
                        const SizedBox(width: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 44,
                            height: 44,
                            color: AppColors.surface,
                            child: _buildPartnerLogoPreview(_partnerLogoCtrl.text.trim()),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Logos preview card for printed coupons
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.print_outlined, size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)['both_logos_printed'],
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Offer Type & Payment Method in a Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<OfferType>(
                        initialValue: _selectedOfferType,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)['offer_type'],
                          prefixIcon: const Icon(Icons.discount_rounded),
                        ),
                        items: OfferType.values.map((type) {
                          return DropdownMenuItem(value: type, child: Text(type.label, overflow: TextOverflow.ellipsis));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedOfferType = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<PromotionPaymentMethod>(
                        initialValue: _selectedPaymentMethod,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)['payment_method'],
                          prefixIcon: const Icon(Icons.payments_rounded),
                        ),
                        items: PromotionPaymentMethod.values.map((m) {
                          final isOnlineDisabled = m == PromotionPaymentMethod.online && !plan.canOnlinePromotionPayment;
                          return DropdownMenuItem(
                            value: m,
                            child: Row(
                              children: [
                                Expanded(child: Text(m.label, overflow: TextOverflow.ellipsis)),
                                if (isOnlineDisabled)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(Icons.lock, size: 14, color: AppColors.warning),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            if (val == PromotionPaymentMethod.online && !plan.canOnlinePromotionPayment) {
                              canUseOnlinePaymentForPromotion(context, plan);
                              return;
                            }
                            setState(() => _selectedPaymentMethod = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Price / Value optional fields
                if (_selectedOfferType == OfferType.fixedDiscount || _selectedOfferType == OfferType.specialPrice) ...[
                  TextFormField(
                    controller: _priceCtrl,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)['offer_price'],
                      hintText: 'es. 15.00',
                      prefixIcon: const Icon(Icons.euro_rounded),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                ] else if (_selectedOfferType == OfferType.percentageDiscount) ...[
                  TextFormField(
                    controller: _discountValueCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Percentuale Sconto (%)',
                      hintText: 'es. 20',
                      prefixIcon: Icon(Icons.percent_rounded),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                ],

                // Code Prefix & Quantity to generate
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _prefixCtrl,
                        decoration: InputDecoration(
                          labelText: '${AppLocalizations.of(context)['code_prefix']} *',
                          hintText: 'es. FIT',
                          prefixIcon: const Icon(Icons.tag_rounded),
                          helperText: 'Prefisso univoco (solo lettere/cifre)',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Inserisci un prefisso';
                          if (v.trim().length < 2) return 'Minimo 2 caratteri';
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _quantityCtrl,
                        decoration: InputDecoration(
                          labelText: '${AppLocalizations.of(context)['vouchers_quantity']} *',
                          hintText: 'es. 25',
                          prefixIcon: const Icon(Icons.format_list_numbered_rounded),
                          helperText: 'Max $maxVouchers (piano ${plan.label})',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Obbligatorio';
                          final num = int.tryParse(v.trim());
                          if (num == null || num <= 0) return 'Numero non valido';
                          if (!plan.isUnlimitedVouchers && num > plan.maxVouchersPerPromotion) {
                            return 'Max ${plan.maxVouchersPerPromotion}';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),

                // Visual code preview banner
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Serie generata: ${_prefixCtrl.text.trim().toUpperCase()}-0001 ... ${_prefixCtrl.text.trim().toUpperCase()}-${(_quantityCtrl.text.trim().padLeft(4, '0'))}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Voucher Validity Duration from Registration
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
                          const Icon(Icons.timer_outlined, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)['voucher_validity_label'],
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context)['voucher_validity_helper'],
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [7, 14, 30, 60, 90].map((days) {
                          final isSelected = !_isCustomValidity && _validityDays == days;
                          return ChoiceChip(
                            label: Text('$days ${AppLocalizations.of(context)['validity_days_unit']}'),
                            selected: isSelected,
                            selectedColor: AppColors.primary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _isCustomValidity = false;
                                _validityDays = days;
                              });
                            },
                          );
                        }).toList()
                          ..add(
                            ChoiceChip(
                              label: const Text('Personalizzato'),
                              selected: _isCustomValidity,
                              selectedColor: AppColors.primary.withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: _isCustomValidity ? AppColors.primary : AppColors.textPrimary,
                                fontWeight: _isCustomValidity ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 13,
                              ),
                              onSelected: (_) {
                                setState(() => _isCustomValidity = true);
                              },
                            ),
                          ),
                      ),
                      if (_isCustomValidity) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: 220,
                          child: TextFormField(
                            controller: _customValidityCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Giorni di validità',
                              suffixText: AppLocalizations.of(context)['validity_days_unit'],
                              prefixIcon: const Icon(Icons.edit_calendar_outlined),
                            ),
                            validator: (v) {
                              if (_isCustomValidity) {
                                final val = int.tryParse(v ?? '');
                                if (val == null || val <= 0) return 'Inserisci giorni validi (> 0)';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Campaign Expiration Date (Last Activation Date)
                InkWell(
                  onTap: _pickExpirationDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_rounded, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppLocalizations.of(context)['campaign_deadline_label'], style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('dd/MM/yyyy').format(_expirationDate),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppLocalizations.of(context)['campaign_deadline_helper'],
                                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Optional Linked Event
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(Collections.events)
                      .where('orgId', isEqualTo: widget.org.id)
                      .where('status', isEqualTo: EventStatus.published.name)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final events = snapshot.data?.docs.map((d) => EventModel.fromFirestore(d)).toList() ?? [];
                    return DropdownButtonFormField<String?>(
                      initialValue: _selectedEventId,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)['linked_event_optional'],
                        prefixIcon: const Icon(Icons.link_rounded),
                        helperText: 'Lascia vuoto se valida per l\'accesso generale alla struttura',
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(AppLocalizations.of(context)['linked_event_none']),
                        ),
                        ...events.map((e) => DropdownMenuItem<String?>(
                              value: e.id,
                              child: Text(e.title, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) => setState(() => _selectedEventId = val),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Description & Terms
                TextFormField(
                  controller: _descriptionCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)['offer_description'],
                    hintText: 'Note, limitazioni (es. valido dal lunedì al venerdì) e modalità di fruizione',
                    prefixIcon: const Icon(Icons.notes_rounded),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Submit Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Annulla'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(_isSaving ? 'Generazione voucher...' : 'Crea Offerta e Voucher'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
