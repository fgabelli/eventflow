import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';
import 'package:eventflow/features/promotions/presentation/dialogs/redeem_voucher_dialog.dart';
import 'package:eventflow/features/promotions/presentation/dialogs/print_format_dialog.dart';
import 'package:eventflow/features/promotions/presentation/dialogs/create_promotion_dialog.dart';

class PromotionDetailScreen extends ConsumerStatefulWidget {
  final String promotionId;

  const PromotionDetailScreen({super.key, required this.promotionId});

  @override
  ConsumerState<PromotionDetailScreen> createState() => _PromotionDetailScreenState();
}

class _PromotionDetailScreenState extends ConsumerState<PromotionDetailScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedFilter = 'all'; // all, available, claimed, redeemed
  bool _isGeneratingMore = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openEditDialog(Organization org, PromotionModel promo) {
    showDialog(
      context: context,
      builder: (ctx) => CreatePromotionDialog(
        org: org,
        existingPromotions: const [],
        initialPromo: promo,
      ),
    );
  }

  Future<void> _confirmDeletePromotion(Organization org, PromotionModel promo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Eliminare la promozione?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sei sicuro di voler eliminare l\'offerta "${promo.title}"?'),
            const SizedBox(height: 12),
            Text(
              'Verranno eliminati permanentemente la promozione e tutti i ${promo.totalVouchers} voucher generati.',
              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'Questa operazione è irreversibile.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Elimina Definitivamente'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Eliminazione voucher in corso...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final db = FirebaseFirestore.instance;
      final vouchersSnap = await db
          .collection(Collections.vouchers)
          .where('promoId', isEqualTo: promo.id)
          .get();

      WriteBatch batch = db.batch();
      int count = 0;
      for (final doc in vouchersSnap.docs) {
        batch.delete(doc.reference);
        count++;
        if (count >= 400) {
          await batch.commit();
          batch = db.batch();
          count = 0;
        }
      }
      if (count > 0) {
        await batch.commit();
      }

      await db.collection(Collections.promotions).doc(promo.id).delete();

      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Promozione "${promo.title}" eliminata con successo.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/promotions');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante l\'eliminazione: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showCampaignQrDialog(PromotionModel promo, Organization org) {
    final campaignUrl = 'https://eventflow-3541b.web.app/p/c/${promo.id}';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(28),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'QR CODE UNICO DI CAMPAGNA',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.8),
              ),
              const SizedBox(height: 4),
              Text(promo.title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
              if (promo.partnerName != null && promo.partnerName!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('Partner: ${promo.partnerName!}', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),
              QrImageView(
                data: campaignUrl,
                version: QrVersions.auto,
                size: 220,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: SelectableText(
                  campaignUrl,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Tutti i coupon stampati usano questo QR. Alla prima scansione, il cliente si registra e ottiene il suo Pass sequenziale personale.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: campaignUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link di registrazione copiato negli appunti!')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copia Link'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    child: const Text('Chiudi'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRedeemDialog(Organization org, {String? initialCode}) {
    showDialog(
      context: context,
      builder: (ctx) => RedeemVoucherDialog(org: org, initialCode: initialCode),
    );
  }

  void _printCoupons(Organization org, PromotionModel promo, List<VoucherModel> vouchers) {
    showDialog(
      context: context,
      builder: (ctx) => PrintFormatDialog(org: org, promo: promo, vouchers: vouchers),
    );
  }

  Future<void> _showAddMoreVouchersDialog(Organization org, PromotionModel promo) async {
    final qtyCtrl = TextEditingController(text: '25');
    final plan = org.plan;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Aggiungi altri Voucher'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attualmente emessi: ${promo.totalVouchers} voucher (${promo.codePrefix}-0001 ... ${promo.codePrefix}-${promo.totalVouchers.toString().padLeft(4, '0')})'),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              decoration: const InputDecoration(
                labelText: 'Quanti altri voucher generare?',
                prefixIcon: Icon(Icons.add_circle_outline),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () async {
              final addQty = int.tryParse(qtyCtrl.text.trim());
              if (addQty == null || addQty <= 0) return;

              final newTotal = promo.totalVouchers + addQty;
              if (!plan.isUnlimitedVouchers && newTotal > plan.maxVouchersPerPromotion) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Limite piano raggiunto: max ${plan.maxVouchersPerPromotion} voucher.')),
                );
                return;
              }

              Navigator.of(ctx).pop();
              await _generateAdditionalVouchers(org, promo, addQty);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Genera'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAdditionalVouchers(Organization org, PromotionModel promo, int count) async {
    setState(() => _isGeneratingMore = true);

    try {
      final db = FirebaseFirestore.instance;
      final startSeq = promo.currentSequence + 1;
      final endSeq = promo.currentSequence + count;

      WriteBatch batch = db.batch();
      int batchCount = 0;

      for (int i = startSeq; i <= endSeq; i++) {
        final codeNumber = i.toString().padLeft(4, '0');
        final voucherCode = '${promo.codePrefix}-$codeNumber';
        final voucherDocId = '${org.id}_$voucherCode';
        final voucherRef = db.collection(Collections.vouchers).doc(voucherDocId);

        final voucher = VoucherModel(
          id: voucherDocId,
          promoId: promo.id,
          orgId: org.id,
          code: voucherCode,
          sequenceNumber: i,
          status: VoucherStatus.available,
          paymentStatus: promo.paymentMethod == PromotionPaymentMethod.online
              ? VoucherPaymentStatus.pending
              : promo.paymentMethod == PromotionPaymentMethod.atVenue
                  ? VoucherPaymentStatus.pending
                  : VoucherPaymentStatus.notRequired,
        );

        batch.set(voucherRef, voucher.toFirestore());
        batchCount++;

        if (batchCount >= 400) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      // Update promo sequence & total
      await db.collection(Collections.promotions).doc(promo.id).update({
        'currentSequence': endSeq,
        'totalVouchers': promo.totalVouchers + count,
        'updatedAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generati $count nuovi voucher (${promo.codePrefix}-${startSeq.toString().padLeft(4, '0')} ... ${promo.codePrefix}-${endSeq.toString().padLeft(4, '0')})')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante la generazione: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingMore = false);
    }
  }

  void _showSingleVoucherQrDialog(VoucherModel voucher, PromotionModel promo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(28),
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'VOUCHER: ${voucher.code}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.8),
              ),
              const SizedBox(height: 4),
              Text(promo.title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              QrImageView(
                data: 'https://eventflow-3541b.web.app/p/${voucher.code}',
                version: QrVersions.auto,
                size: 200,
              ),
              const SizedBox(height: 16),
              Text(
                'Scansiona questo QR code con lo smartphone per aprire la pagina di attivazione del voucher.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Chiudi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(currentOrgProvider).value;

    if (org == null) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection(Collections.promotions).doc(widget.promotionId).snapshots(),
      builder: (context, promoSnap) {
        if (promoSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: AppColors.surface, body: Center(child: CircularProgressIndicator()));
        }

        if (!promoSnap.hasData || !promoSnap.data!.exists) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(backgroundColor: AppColors.surface),
            body: const Center(child: Text('Promozione non trovata.')),
          );
        }

        final promo = PromotionModel.fromFirestore(promoSnap.data!);

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(Collections.vouchers)
              .where('promoId', isEqualTo: promo.id)
              .orderBy('sequenceNumber')
              .snapshots(),
          builder: (context, vouchersSnap) {
            final allVouchers = vouchersSnap.data?.docs.map((d) => VoucherModel.fromFirestore(d)).toList() ?? [];

            var filteredVouchers = allVouchers;
            if (_selectedFilter == 'available') {
              filteredVouchers = filteredVouchers.where((v) => v.isAvailable).toList();
            } else if (_selectedFilter == 'claimed') {
              filteredVouchers = filteredVouchers.where((v) => v.isClaimed && !v.isExpired).toList();
            } else if (_selectedFilter == 'redeemed') {
              filteredVouchers = filteredVouchers.where((v) => v.isRedeemed).toList();
            } else if (_selectedFilter == 'expired') {
              filteredVouchers = filteredVouchers.where((v) => v.isExpired && !v.isRedeemed).toList();
            }

            final searchQuery = _searchCtrl.text.toLowerCase().trim();
            if (searchQuery.isNotEmpty) {
              filteredVouchers = filteredVouchers.where((v) {
                final code = v.code.toLowerCase();
                final name = v.claimedFullName.toLowerCase();
                final email = (v.claimedEmail ?? '').toLowerCase();
                return code.contains(searchQuery) || name.contains(searchQuery) || email.contains(searchQuery);
              }).toList();
            }

            return Scaffold(
              backgroundColor: AppColors.surface,
              appBar: AppBar(
                title: Row(
                  children: [
                    Text(promo.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    if (promo.partnerName != null && promo.partnerName!.trim().isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Partner: ${promo.partnerName!}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ],
                ),
                backgroundColor: AppColors.surface,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/promotions'),
                ),
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => _openEditDialog(org, promo),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Modifica'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _openRedeemDialog(org),
                    icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                    label: const Text('Convalida in Cassa'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _printCoupons(org, promo, allVouchers),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Stampa Coupon PDF'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _confirmDeletePromotion(org, promo),
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    tooltip: 'Elimina Promozione',
                  ),
                  const SizedBox(width: 12),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Summary Card
                    _buildOverviewCard(org, promo, allVouchers),

                    const SizedBox(height: 28),

                    // Vouchers Section Header & Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Elenco Voucher Generati (${filteredVouchers.length}/${allVouchers.length})',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Serie sequenziale: ${promo.codePrefix}-0001 ... ${promo.codePrefix}-${promo.totalVouchers.toString().padLeft(4, '0')}',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: _isGeneratingMore ? null : () => _showAddMoreVouchersDialog(org, promo),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(_isGeneratingMore ? 'Generazione...' : 'Aggiungi altri Voucher'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Filters and Search bar
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Cerca codice o nome cliente...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchCtrl.clear()))
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildFilterChip('Tutti (${allVouchers.length})', 'all'),
                            _buildFilterChip('Disponibili (${allVouchers.where((v) => v.isAvailable).length})', 'available'),
                            _buildFilterChip('Attivati (${allVouchers.where((v) => v.isClaimed && !v.isExpired).length})', 'claimed'),
                            _buildFilterChip('Riscattati (${allVouchers.where((v) => v.isRedeemed).length})', 'redeemed'),
                            _buildFilterChip('Scaduti (${allVouchers.where((v) => v.isExpired && !v.isRedeemed).length})', 'expired'),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Vouchers Table / Cards
                    if (filteredVouchers.isEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text('Nessun voucher corrisponde ai filtri selezionati.', style: Theme.of(context).textTheme.bodyMedium),
                        ),
                      ),
                    ] else ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredVouchers.length,
                        itemBuilder: (context, index) {
                          final voucher = filteredVouchers[index];
                          return _buildVoucherRow(org, voucher, promo);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = value),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        fontSize: 12,
      ),
    );
  }

  Widget _buildPartnerLogoThumb(String logoData) {
    try {
      if (logoData.startsWith('data:image')) {
        final commaIdx = logoData.indexOf(',');
        if (commaIdx != -1) {
          final bytes = base64Decode(logoData.substring(commaIdx + 1));
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(bytes, width: 44, height: 44, fit: BoxFit.contain),
          );
        }
      } else if (logoData.startsWith('http://') || logoData.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            logoData,
            width: 44,
            height: 44,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => const Icon(Icons.handshake_outlined, size: 24, color: AppColors.primary),
          ),
        );
      }
    } catch (_) {}
    return const Icon(Icons.handshake_outlined, size: 24, color: AppColors.primary);
  }

  Widget _buildOverviewCard(Organization org, PromotionModel promo, List<VoucherModel> vouchers) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final available = vouchers.where((v) => v.isAvailable).length;
    final claimed = vouchers.where((v) => v.isClaimed && !v.isExpired).length;
    final redeemed = vouchers.where((v) => v.isRedeemed).length;
    final expired = vouchers.where((v) => v.isExpired && !v.isRedeemed).length;
    final campaignUrl = 'https://eventflow-3541b.web.app/p/c/${promo.id}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (promo.partnerLogoUrl != null && promo.partnerLogoUrl!.trim().isNotEmpty) ...[
                      Container(
                        height: 52,
                        width: 52,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: _buildPartnerLogoThumb(promo.partnerLogoUrl!),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Riepilogo Offerta', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                              if (promo.partnerName != null && promo.partnerName!.trim().isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Partner: ${promo.partnerName!}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (promo.description != null && promo.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(promo.description!, style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Modifica Offerta',
                    onPressed: () => _openEditDialog(org, promo),
                  ),
                  IconButton(
                    icon: Icon(promo.status == PromotionStatus.active ? Icons.pause_circle_outline : Icons.play_circle_outline),
                    tooltip: promo.status == PromotionStatus.active ? 'Metti in pausa' : 'Riattiva offerta',
                    onPressed: () async {
                      final newStatus = promo.status == PromotionStatus.active ? PromotionStatus.paused : PromotionStatus.active;
                      await FirebaseFirestore.instance.collection(Collections.promotions).doc(promo.id).update({
                        'status': newStatus.name,
                        'updatedAt': Timestamp.now(),
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOverviewMetric('Totale Emessi', '${vouchers.length}', AppColors.textPrimary),
              _buildOverviewMetric('Disponibili', '$available', const Color(0xFF64748B)),
              _buildOverviewMetric('Attivati', '$claimed', const Color(0xFF0EA5E9)),
              _buildOverviewMetric('Riscattati', '$redeemed', AppColors.success),
              if (expired > 0)
                _buildOverviewMetric('Scaduti', '$expired', AppColors.error),
              _buildOverviewMetric('Validità', '${promo.validityDays} gg', const Color(0xFF8B5CF6)),
              _buildOverviewMetric(
                'Termine Registrazione',
                promo.expirationDate != null ? dateFormat.format(promo.expirationDate!) : 'Aperto',
                promo.isRegistrationClosed ? AppColors.warning : AppColors.textPrimary,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'QR Code Unico di Campagna (Stampa Identica & Conio Dinamico)',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        campaignUrl,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: campaignUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link di registrazione copiato negli appunti!')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copia Link'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showCampaignQrDialog(promo, org),
                  icon: const Icon(Icons.fullscreen_rounded, size: 16),
                  label: const Text('Ingrandisci QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
      ],
    );
  }

  Widget _buildVoucherRow(Organization org, VoucherModel voucher, PromotionModel promo) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dateOnlyFormat = DateFormat('dd/MM/yyyy');
    final isVoucherExpired = voucher.isExpired;
    final isPromoExpired = promo.isExpired;
    final isExpired = (isVoucherExpired || isPromoExpired) && !voucher.isRedeemed;

    Color badgeColor = const Color(0xFF64748B);
    String badgeText = 'Disponibile';

    if (voucher.isRedeemed) {
      badgeColor = AppColors.success;
      badgeText = 'Riscattato';
    } else if (isExpired) {
      badgeColor = AppColors.error;
      badgeText = 'Scaduto';
    } else if (voucher.isClaimed) {
      badgeColor = const Color(0xFF0EA5E9);
      badgeText = 'Attivato';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpired
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // QR icon button to preview
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
            tooltip: 'Mostra QR Code',
            onPressed: () => _showSingleVoucherQrDialog(voucher, promo),
          ),
          const SizedBox(width: 8),

          // Code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              voucher.code,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(width: 16),

          // Status Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: TextStyle(color: badgeColor, fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ),
          const SizedBox(width: 16),

          // Client details if claimed
          Expanded(
            child: voucher.isClaimed || voucher.isRedeemed
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        voucher.claimedFullName.isNotEmpty ? voucher.claimedFullName : 'Cliente',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Row(
                        children: [
                          Text(
                            '${voucher.claimedEmail ?? ""} ${voucher.claimedPhone != null ? "• ${voucher.claimedPhone!}" : ""}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          if (voucher.expiresAt != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• Scadenza: ${dateOnlyFormat.format(voucher.expiresAt!)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isExpired ? AppColors.error : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  )
                : const Text(
                    'In attesa di scansione da coupon cartaceo',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary, fontStyle: FontStyle.italic),
                  ),
          ),

          // Timestamp
          if (voucher.redeemedAt != null) ...[
            Text('Riscattato: ${dateFormat.format(voucher.redeemedAt!)}', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            const SizedBox(width: 12),
          ] else if (voucher.claimedAt != null) ...[
            Text('Attivato: ${dateFormat.format(voucher.claimedAt!)}', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            const SizedBox(width: 12),
          ],

          // Quick action button
          if (voucher.isRedeemed) ...[
            const SizedBox.shrink(),
          ] else if (isExpired) ...[
            OutlinedButton(
              onPressed: () => _openRedeemDialog(org, initialCode: voucher.code),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              child: const Text('Dettagli Scaduto'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () => _openRedeemDialog(org, initialCode: voucher.code),
              style: ElevatedButton.styleFrom(
                backgroundColor: voucher.isClaimed ? AppColors.primary : AppColors.surface,
                foregroundColor: voucher.isClaimed ? Colors.white : AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                elevation: voucher.isClaimed ? 1 : 0,
              ),
              child: const Text('Riscatta in cassa'),
            ),
          ],
        ],
      ),
    );
  }
}
