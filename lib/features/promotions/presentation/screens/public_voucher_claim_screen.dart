import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';

class PublicVoucherClaimScreen extends StatefulWidget {
  final String code;

  const PublicVoucherClaimScreen({super.key, required this.code});

  @override
  State<PublicVoucherClaimScreen> createState() => _PublicVoucherClaimScreenState();
}

class _PublicVoucherClaimScreenState extends State<PublicVoucherClaimScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _isClaimedSuccess = false;
  String? _claimError;

  VoucherModel? _claimedVoucher;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitClaim(VoucherModel voucher, PromotionModel promo) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _claimError = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final voucherRef = db.collection(Collections.vouchers).doc(voucher.id);

      // Re-verify voucher in real-time
      final freshSnap = await voucherRef.get();
      if (!freshSnap.exists) {
        setState(() {
          _claimError = 'Voucher non valido o inesistente.';
          _isSubmitting = false;
        });
        return;
      }

      final freshVoucher = VoucherModel.fromFirestore(freshSnap);
      if (freshVoucher.isRedeemed) {
        setState(() {
          _claimError = 'Questo voucher è già stato utilizzato presso la struttura.';
          _isSubmitting = false;
        });
        return;
      }

      if (freshVoucher.isClaimed) {
        // Already claimed by someone
        setState(() {
          _claimedVoucher = freshVoucher;
          _isClaimedSuccess = true;
          _isSubmitting = false;
        });
        return;
      }

      final batch = db.batch();

      final updatedVoucher = freshVoucher.copyWith(
        status: VoucherStatus.claimed,
        claimedAt: DateTime.now(),
        claimedFirstName: _firstNameCtrl.text.trim(),
        claimedLastName: _lastNameCtrl.text.trim(),
        claimedEmail: _emailCtrl.text.trim().toLowerCase(),
        claimedPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        paymentStatus: promo.paymentMethod == PromotionPaymentMethod.online
            ? VoucherPaymentStatus.paidOnline
            : VoucherPaymentStatus.pending,
      );

      batch.update(voucherRef, updatedVoucher.toFirestore());

      // Increment claimed count in promotion
      final promoRef = db.collection(Collections.promotions).doc(promo.id);
      batch.update(promoRef, {
        'claimedCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });

      await batch.commit();

      setState(() {
        _claimedVoucher = updatedVoucher;
        _isClaimedSuccess = true;
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _claimError = 'Si è verificato un errore durante l\'attivazione: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanCode = widget.code.trim().toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection(Collections.vouchers)
            .where('code', isEqualTo: cleanCode)
            .limit(1)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildNotFoundState(cleanCode);
          }

          final voucherDoc = snapshot.data!.docs.first;
          final voucher = _claimedVoucher ?? VoucherModel.fromFirestore(voucherDoc);

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection(Collections.promotions).doc(voucher.promoId).get(),
            builder: (context, promoSnap) {
              if (promoSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!promoSnap.hasData || !promoSnap.data!.exists) {
                return _buildNotFoundState(cleanCode);
              }

              final promo = PromotionModel.fromFirestore(promoSnap.data!);

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection(Collections.organizations).doc(promo.orgId).get(),
                builder: (context, orgSnap) {
                  Organization? org;
                  if (orgSnap.hasData && orgSnap.data!.exists) {
                    org = Organization.fromFirestore(orgSnap.data!);
                  }

                  if (_isClaimedSuccess || voucher.isClaimed) {
                    return _buildSuccessState(voucher, promo, org);
                  }

                  if (voucher.isRedeemed) {
                    return _buildAlreadyRedeemedState(voucher, promo, org);
                  }

                  if (promo.isExpired) {
                    return _buildExpiredState(promo, org);
                  }

                  return _buildClaimForm(voucher, promo, org);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildClaimForm(VoucherModel voucher, PromotionModel promo, Organization? org) {
    final expDateStr = DateFormat('dd/MM/yyyy').format(promo.expirationDate);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Org Header
              _buildOrgHeader(org),

              // Offer Banner Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            promo.offerType.label,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            voucher.code,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      promo.title,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    if (promo.partnerName != null && promo.partnerName!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'In convenzione con: ${promo.partnerName!}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                    if (promo.description != null && promo.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        promo.description!,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.event_available_rounded, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Valido fino al: $expDateStr',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Form Section
              Text(
                AppLocalizations.of(context)['public_voucher_form_title'],
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Registra il tuo pass per poter usufruire della promozione al tuo arrivo.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),

              if (_claimError != null) ...[
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
                        child: Text(_claimError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nome *',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Cognome *',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Obbligatorio' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        hintText: 'tu@esempio.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Obbligatorio';
                        if (!v.contains('@') || !v.contains('.')) return 'Email non valida';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cellulare (Opzionale)',
                        hintText: '+39...',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Payment note
              if (promo.paymentMethod == PromotionPaymentMethod.atVenue) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          promo.price != null && promo.price! > 0
                              ? 'Pagherai €${promo.price!.toStringAsFixed(2)} direttamente alla reception della struttura.'
                              : promo.isTwoForOne
                                  ? 'Offerta 2x1: paghi 1 ingresso standard e il secondo è omaggio, direttamente alla reception.'
                                  : 'Pagamento o saldo direttamente alla reception al momento del check-in.',
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Submit Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _submitClaim(voucher, promo),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          promo.paymentMethod == PromotionPaymentMethod.atVenue
                              ? AppLocalizations.of(context)['public_voucher_activate_venue']
                              : promo.paymentMethod == PromotionPaymentMethod.online
                                  ? AppLocalizations.of(context)['public_voucher_activate_online']
                                  : 'Attiva Offerta Gratuita',
                        ),
                ),
              ),

              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessState(VoucherModel voucher, PromotionModel promo, Organization? org) {
    final expDateStr = DateFormat('dd/MM/yyyy').format(promo.expirationDate);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildOrgHeader(org),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)['public_voucher_success_title'],
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Promozione attivata per ${voucher.claimedFullName.isNotEmpty ? voucher.claimedFullName : "te"}!',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)['public_voucher_success_desc'],
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Digital Pass with QR
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      promo.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    if (promo.partnerName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Partner: ${promo.partnerName!}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // QR Code
                    QrImageView(
                      data: voucher.code,
                      version: QrVersions.auto,
                      size: 180,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF0F172A),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'CODICE: ${voucher.code}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Scadenza:', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                        Text(expDateStr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Stato Pass:', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                        const Text('Attivato (Pronto per l\'uso)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.success)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.screenshot_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Fai uno screenshot di questo pass per averlo sempre a portata di mano al tuo arrivo.',
                        style: TextStyle(fontSize: 12, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),

              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlreadyRedeemedState(VoucherModel voucher, PromotionModel promo, Organization? org) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildOrgHeader(org),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, size: 56, color: AppColors.warning),
            ),
            const SizedBox(height: 24),
            Text('Voucher Già Utilizzato', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Il voucher "${voucher.code}" è già stato riscattato presso la nostra struttura.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiredState(PromotionModel promo, Organization? org) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildOrgHeader(org),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_busy_rounded, size: 56, color: AppColors.error),
            ),
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)['public_voucher_expired'], style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Questa promozione è scaduta in data ${DateFormat('dd/MM/yyyy').format(promo.expirationDate)}.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundState(String code) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sentiment_dissatisfied_rounded, size: 56, color: AppColors.error),
            ),
            const SizedBox(height: 24),
            Text('Voucher non trovato', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Non abbiamo trovato alcuna offerta associata al codice "$code". Controlla di aver inserito il codice corretto.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrgHeader(Organization? org) {
    if (org == null) return const SizedBox(height: 16);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                org.name.isNotEmpty ? org.name[0].toUpperCase() : '🏢',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            org.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 36, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset('assets/images/ticketto_logo.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Powered by Ticketto',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
