import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';

class RedeemVoucherDialog extends ConsumerStatefulWidget {
  final Organization org;
  final String? initialCode;

  const RedeemVoucherDialog({
    super.key,
    required this.org,
    this.initialCode,
  });

  @override
  ConsumerState<RedeemVoucherDialog> createState() => _RedeemVoucherDialogState();
}

class _RedeemVoucherDialogState extends ConsumerState<RedeemVoucherDialog> {
  final _codeCtrl = TextEditingController();
  bool _showScanner = false;
  bool _isLoading = false;
  bool _isRedeeming = false;
  String? _errorMessage;
  String? _successMessage;

  VoucherModel? _foundVoucher;
  PromotionModel? _foundPromo;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _codeCtrl.text = widget.initialCode!;
      _searchVoucher(widget.initialCode!);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchVoucher(String rawCode) async {
    String cleanCode = rawCode.trim().toUpperCase();
    // If a full URL was scanned (e.g. https://domain.com/p/FIT-0001), extract code
    if (cleanCode.contains('/p/')) {
      cleanCode = cleanCode.split('/p/').last.split('?').first.trim();
    }

    if (cleanCode.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
      _foundVoucher = null;
      _foundPromo = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      DocumentSnapshot? voucherDoc;

      // 1. Try exact voucher code
      final query = await db
          .collection(Collections.vouchers)
          .where('orgId', isEqualTo: widget.org.id)
          .where('code', isEqualTo: cleanCode)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        voucherDoc = query.docs.first;
      } else {
        // 2. Fallback: Search across organization vouchers by customer name, email or phone
        final term = rawCode.trim().toLowerCase();
        final snap = await db
            .collection(Collections.vouchers)
            .where('orgId', isEqualTo: widget.org.id)
            .get();

        final matches = snap.docs.where((d) {
          final v = VoucherModel.fromFirestore(d);
          return v.code.toLowerCase() == term ||
              v.claimedFullName.toLowerCase().contains(term) ||
              (v.claimedEmail ?? '').toLowerCase().contains(term) ||
              (v.claimedPhone ?? '').contains(term);
        }).toList();

        if (matches.isNotEmpty) {
          voucherDoc = matches.first;
        }
      }

      if (voucherDoc == null) {
        setState(() {
          _errorMessage = 'Nessun voucher trovato per "$rawCode". Digita il codice (es. FIT-0001), il nome cliente o l\'email.';
          _isLoading = false;
        });
        return;
      }

      final voucher = VoucherModel.fromFirestore(voucherDoc);

      // Load corresponding promotion
      final promoDoc = await db.collection(Collections.promotions).doc(voucher.promoId).get();
      PromotionModel? promo;
      if (promoDoc.exists) {
        promo = PromotionModel.fromFirestore(promoDoc);
      }

      setState(() {
        _foundVoucher = voucher;
        _foundPromo = promo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore durante la verifica: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmRedemption() async {
    if (_foundVoucher == null || _foundPromo == null) return;

    final voucher = _foundVoucher!;
    final promo = _foundPromo!;
    final appUser = ref.read(appUserProvider).value;

    setState(() {
      _isRedeeming = true;
      _errorMessage = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // Update voucher document
      final voucherRef = db.collection(Collections.vouchers).doc(voucher.id);
      batch.update(voucherRef, {
        'status': VoucherStatus.redeemed.name,
        'redeemedAt': Timestamp.now(),
        'redeemedByUserId': appUser?.id ?? 'staff',
        'paymentStatus': promo.paymentMethod == PromotionPaymentMethod.online
            ? VoucherPaymentStatus.paidOnline.name
            : promo.paymentMethod == PromotionPaymentMethod.atVenue
                ? VoucherPaymentStatus.paidAtVenue.name
                : VoucherPaymentStatus.notRequired.name,
      });

      // Increment redeemed count on promotion
      final promoRef = db.collection(Collections.promotions).doc(promo.id);
      batch.update(promoRef, {
        'redeemedCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });

      await batch.commit();

      setState(() {
        _isRedeeming = false;
        _successMessage = 'Voucher ${voucher.code} riscattato con successo! Accesso consentito.';
        _foundVoucher = voucher.copyWith(
          status: VoucherStatus.redeemed,
          redeemedAt: DateTime.now(),
        );
      });
    } catch (e) {
      setState(() {
        _isRedeeming = false;
        _errorMessage = 'Errore durante la registrazione del riscatto: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: const Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)['redeem_dialog_title'],
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(context)['redeem_dialog_hint'],
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

              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 16),

              // Code Input & Scanner Toggle
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)['redeem_code_label'],
                        hintText: 'es. FIT-0001',
                        prefixIcon: const Icon(Icons.confirmation_number_rounded),
                        suffixIcon: _codeCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _codeCtrl.clear();
                                  setState(() {
                                    _foundVoucher = null;
                                    _foundPromo = null;
                                    _errorMessage = null;
                                    _successMessage = null;
                                  });
                                },
                              )
                            : null,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: _searchVoucher,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _searchVoucher(_codeCtrl.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Verifica'),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _showScanner ? AppColors.primary : AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _showScanner ? AppColors.primary : AppColors.border),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.camera_alt_rounded,
                        color: _showScanner ? Colors.white : AppColors.textPrimary,
                      ),
                      tooltip: 'Attiva fotocamera per scansionare',
                      onPressed: () => setState(() => _showScanner = !_showScanner),
                    ),
                  ),
                ],
              ),

              // Camera scanner area
              if (_showScanner) ...[
                const SizedBox(height: 16),
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: MobileScanner(
                    onDetect: (capture) {
                      final barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                        final code = barcodes.first.rawValue!;
                        setState(() {
                          _showScanner = false;
                          _codeCtrl.text = code;
                        });
                        _searchVoucher(code);
                      }
                    },
                  ),
                ),
              ],

              // Error banner
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],

              // Success banner
              if (_successMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_successMessage!, style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],

              // Result Card
              if (_foundVoucher != null && _foundPromo != null) ...[
                const SizedBox(height: 20),
                _buildVoucherDetailsCard(_foundVoucher!, _foundPromo!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoucherDetailsCard(VoucherModel voucher, PromotionModel promo) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final isVoucherExpired = voucher.isExpired;
    final isPromoExpired = promo.isExpired;
    final isExpired = isVoucherExpired || isPromoExpired;
    final isRedeemed = voucher.isRedeemed;
    final isClaimed = voucher.isClaimed;
    final isAvailable = voucher.isAvailable;

    Color statusColor = AppColors.primary;
    String statusText = 'Valido & Disponibile';

    if (isRedeemed) {
      statusColor = AppColors.error;
      statusText = 'GIÀ RISCATTATO';
    } else if (isExpired) {
      statusColor = AppColors.error;
      statusText = isVoucherExpired ? 'SCADUTO (Termine registrazione)' : 'CAMPAGNA TERMINATA';
    } else if (isClaimed) {
      statusColor = AppColors.success;
      statusText = 'ATTIVATO DA CLIENTE';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VOUCHER: ${voucher.code}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Promotion Title & Partner
          Text(promo.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          if (promo.partnerName != null) ...[
            const SizedBox(height: 2),
            Text(
              'Collaborazione: ${promo.partnerName!}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
          const SizedBox(height: 8),

          // Offer conditions
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  promo.offerType.label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Scadenza: ${DateFormat('dd/MM/yyyy').format(promo.expirationDate)}',
                style: TextStyle(fontSize: 12, color: isExpired ? AppColors.error : AppColors.textTertiary),
              ),
            ],
          ),

          const Divider(height: 24),

          // Customer Details if claimed
          if (isClaimed || (voucher.claimedFirstName != null && voucher.claimedFirstName!.isNotEmpty)) ...[
            Text('Dati Cliente Registrato:', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(voucher.claimedFullName, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            if (voucher.claimedEmail != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.email_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(voucher.claimedEmail!, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ],
            if (voucher.claimedPhone != null && voucher.claimedPhone!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(voucher.claimedPhone!, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ],
            if (voucher.claimedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Registrato il: ${dateFormat.format(voucher.claimedAt!)}',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
            if (voucher.expiresAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    voucher.isExpired ? Icons.timer_off_outlined : Icons.timer_outlined,
                    size: 15,
                    color: voucher.isExpired ? AppColors.error : AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    voucher.isExpired
                        ? 'Scaduto il: ${dateFormat.format(voucher.expiresAt!)}'
                        : 'Scadenza voucher: ${dateFormat.format(voucher.expiresAt!)} (${voucher.remainingDays ?? 0} gg rimasti)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: voucher.isExpired ? AppColors.error : AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 24),
          ] else if (isAvailable) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Coupon cartaceo valido non ancora attivato online dal cliente. Puoi convalidarlo direttamente.',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Payment requirement warning
          if (promo.paymentMethod == PromotionPaymentMethod.atVenue) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, color: Color(0xFFD97706)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      promo.price != null && promo.price! > 0
                          ? 'Da riscuotere in cassa: €${promo.price!.toStringAsFixed(2)}'
                          : promo.isTwoForOne
                              ? 'Promozione 2x1: incassare 1 ingresso standard alla cassa.'
                              : 'Incassare l\'importo concordato alla reception.',
                      style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Expired notice
          if (isExpired && !isRedeemed) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_off_outlined, color: AppColors.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isVoucherExpired
                          ? 'Voucher non riscattabile: scaduto il ${dateFormat.format(voucher.expiresAt!)}. I ${promo.validityDays} giorni di validità dalla registrazione sono trascorsi.'
                          : 'Voucher non riscattabile: la campagna promozionale è terminata il ${DateFormat('dd/MM/yyyy').format(promo.expirationDate)}.',
                      style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Already redeemed notice
          if (isRedeemed && voucher.redeemedAt != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel_outlined, color: AppColors.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Attenzione: utilizzato in data ${dateFormat.format(voucher.redeemedAt!)}.',
                      style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action Button: Confirm Redemption
          if (!isRedeemed && !isExpired) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isRedeeming ? null : _confirmRedemption,
                icon: _isRedeeming
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(_isRedeeming ? 'Convalida in corso...' : AppLocalizations.of(context)['redeem_confirm_btn']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
