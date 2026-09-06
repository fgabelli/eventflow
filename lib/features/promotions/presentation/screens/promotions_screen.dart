import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/core/utils/feature_gate.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';
import 'package:eventflow/features/promotions/presentation/dialogs/create_promotion_dialog.dart';
import 'package:eventflow/features/promotions/presentation/dialogs/redeem_voucher_dialog.dart';
import 'package:eventflow/features/promotions/presentation/dialogs/print_format_dialog.dart';

class PromotionsScreen extends ConsumerStatefulWidget {
  const PromotionsScreen({super.key});

  @override
  ConsumerState<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends ConsumerState<PromotionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openCreateDialog(Organization org, List<PromotionModel> promos) {
    final activeCount = promos.where((p) => p.status == PromotionStatus.active).length;
    if (!canCreatePromotion(context, org.plan, activeCount)) return;

    showDialog(
      context: context,
      builder: (ctx) => CreatePromotionDialog(org: org, existingPromotions: promos),
    );
  }

  void _openRedeemDialog(Organization org, {String? initialCode}) {
    showDialog(
      context: context,
      builder: (ctx) => RedeemVoucherDialog(org: org, initialCode: initialCode),
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)['promotions_title'], style: Theme.of(context).textTheme.headlineMedium),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton.icon(
              onPressed: () => _openRedeemDialog(org),
              icon: const Icon(Icons.point_of_sale_rounded, size: 18),
              label: Text(AppLocalizations.of(context)['redeem_voucher_btn']),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(Collections.promotions)
                .where('orgId', isEqualTo: org.id)
                .snapshots(),
            builder: (context, snapshot) {
              final promos = snapshot.data?.docs.map((d) => PromotionModel.fromFirestore(d)).toList() ?? [];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ElevatedButton.icon(
                  onPressed: () => _openCreateDialog(org, promos),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(AppLocalizations.of(context)['new_promotion_btn']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.local_offer_outlined), text: 'Campagne & Offerte'),
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Registro Registrazioni Clienti'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(Collections.promotions)
            .where('orgId', isEqualTo: org.id)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final promotions = snapshot.data?.docs
              .map((d) => PromotionModel.fromFirestore(d))
              .toList() ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCampaignsTab(org, promotions),
              _buildRegistrationsTab(org, promotions),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCampaignsTab(Organization org, List<PromotionModel> promotions) {
    if (promotions.isEmpty) {
      return _buildEmptyState(org);
    }

    final activePromos = promotions.where((p) => p.isActive).length;
    final totalVouchers = promotions.fold<int>(0, (total, p) => total + p.totalVouchers);
    final totalClaimed = promotions.fold<int>(0, (total, p) => total + p.claimedCount);
    final totalRedeemed = promotions.fold<int>(0, (total, p) => total + p.redeemedCount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final cards = [
                _buildStatCard('Campagne Attive', '$activePromos', Icons.campaign_rounded, AppColors.primary),
                _buildStatCard('Voucher Emessi', '$totalVouchers', Icons.confirmation_number_rounded, const Color(0xFF6366F1)),
                _buildStatCard('Clienti Registrati', '$totalClaimed', Icons.people_alt_rounded, const Color(0xFF0EA5E9)),
                _buildStatCard('Voucher Riscattati', '$totalRedeemed', Icons.check_circle_rounded, AppColors.success),
              ];

              if (isWide) {
                return Row(
                  children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
                );
              }
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: cards,
              );
            },
          ),

          const SizedBox(height: 28),

          // Section Title
          Text('Tutte le Offerte & Convenzioni', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          // List of Promotions
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: promotions.length,
            itemBuilder: (context, index) {
              final promo = promotions[index];
              return _buildPromotionCard(org, promo);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 2),
                Text(label, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionCard(Organization org, PromotionModel promo) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isExpired = promo.isExpired;
    final isActive = promo.isActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.go('/promotions/${promo.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      promo.codePrefix,
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          promo.title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        if (promo.partnerName != null && promo.partnerName!.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.handshake_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                'Partner: ${promo.partnerName!}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Status chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? AppColors.error.withValues(alpha: 0.1)
                          : isActive
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isExpired
                          ? 'Scaduta'
                          : isActive
                              ? 'Attiva'
                              : 'In Pausa',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isExpired
                            ? AppColors.error
                            : isActive
                                ? AppColors.success
                                : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Conversion progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Attivati: ${promo.claimedCount} / ${promo.totalVouchers}  •  Riscattati: ${promo.redeemedCount}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      Text(
                        'Scadenza: ${dateFormat.format(promo.expirationDate)}',
                        style: TextStyle(fontSize: 12, color: isExpired ? AppColors.error : AppColors.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: promo.totalVouchers > 0 ? (promo.redeemedCount / promo.totalVouchers).clamp(0.0, 1.0) : 0,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          promo.offerType.label,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        promo.paymentMethod.label,
                        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _printCouponsPdf(org, promo),
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: const Text('Stampa Coupon'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () => context.go('/promotions/${promo.id}'),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text('Dettagli Voucher'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printCouponsPdf(Organization org, PromotionModel promo) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(Collections.vouchers)
          .where('promoId', isEqualTo: promo.id)
          .orderBy('sequenceNumber')
          .get();

      final vouchers = snap.docs.map((d) => VoucherModel.fromFirestore(d)).toList();

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => PrintFormatDialog(org: org, promo: promo, vouchers: vouchers),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il caricamento dei voucher: $e')),
        );
      }
    }
  }

  Widget _buildRegistrationsTab(Organization org, List<PromotionModel> promotions) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(Collections.vouchers)
          .where('orgId', isEqualTo: org.id)
          .where('status', whereIn: [VoucherStatus.claimed.name, VoucherStatus.redeemed.name])
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var vouchers = snapshot.data?.docs.map((d) => VoucherModel.fromFirestore(d)).toList() ?? [];

        // Sort by claimedAt descending
        vouchers.sort((a, b) => (b.claimedAt ?? b.createdAt).compareTo(a.claimedAt ?? a.createdAt));

        final searchQuery = _searchCtrl.text.toLowerCase().trim();
        if (searchQuery.isNotEmpty) {
          vouchers = vouchers.where((v) {
            final name = v.claimedFullName.toLowerCase();
            final email = (v.claimedEmail ?? '').toLowerCase();
            final phone = (v.claimedPhone ?? '').toLowerCase();
            final code = v.code.toLowerCase();
            return name.contains(searchQuery) || email.contains(searchQuery) || phone.contains(searchQuery) || code.contains(searchQuery);
          }).toList();
        }

        if (_selectedStatusFilter == 'claimed') {
          vouchers = vouchers.where((v) => v.isClaimed && !v.isExpired).toList();
        } else if (_selectedStatusFilter == 'redeemed') {
          vouchers = vouchers.where((v) => v.isRedeemed).toList();
        } else if (_selectedStatusFilter == 'expired') {
          vouchers = vouchers.where((v) => v.isExpired && !v.isRedeemed).toList();
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search & Filter row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Cerca per nome, email, cellulare o codice voucher...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedStatusFilter,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tutti gli stati')),
                      DropdownMenuItem(value: 'claimed', child: Text('Solo Attivati (Validi)')),
                      DropdownMenuItem(value: 'redeemed', child: Text('Solo Riscattati (Completati)')),
                      DropdownMenuItem(value: 'expired', child: Text('Solo Scaduti')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedStatusFilter = v);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Results count header
              Text(
                'Registrazioni trovate: ${vouchers.length}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),

              // Registrations List
              Expanded(
                child: vouchers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_search_rounded, size: 48, color: AppColors.textTertiary),
                            const SizedBox(height: 12),
                            Text(
                              'Nessuna registrazione trovata.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: vouchers.length,
                        itemBuilder: (context, index) {
                          final voucher = vouchers[index];
                          final promo = promotions.firstWhere(
                            (p) => p.id == voucher.promoId,
                            orElse: () => PromotionModel(
                              id: voucher.promoId,
                              orgId: org.id,
                              title: 'Promozione',
                              codePrefix: voucher.code.split('-').first,
                              expirationDate: DateTime.now(),
                            ),
                          );

                          return _buildRegistrationTile(org, voucher, promo);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegistrationTile(Organization org, VoucherModel voucher, PromotionModel promo) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dateOnlyFormat = DateFormat('dd/MM/yyyy');
    final isRedeemed = voucher.isRedeemed;
    final isExpired = voucher.isExpired || promo.isExpired;

    Color tileStatusColor = isRedeemed
        ? AppColors.success
        : isExpired
            ? AppColors.error
            : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tileStatusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: tileStatusColor.withValues(alpha: 0.1),
            child: Icon(
              isRedeemed
                  ? Icons.check_circle_rounded
                  : isExpired
                      ? Icons.timer_off_rounded
                      : Icons.person_rounded,
              color: tileStatusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Client Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      voucher.claimedFullName.isNotEmpty ? voucher.claimedFullName : 'Cliente Registrato',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        voucher.code,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11),
                      ),
                    ),
                    if (isExpired && !isRedeemed) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'SCADUTO',
                          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (voucher.claimedEmail != null) ...[
                      Text(voucher.claimedEmail!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 8),
                    ],
                    if (voucher.claimedPhone != null && voucher.claimedPhone!.isNotEmpty) ...[
                      Text('•  ${voucher.claimedPhone!}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Offerta: ${promo.title} ${promo.partnerName != null ? "(${promo.partnerName})" : ""}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textTertiary),
                    ),
                    if (voucher.expiresAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• Scadenza: ${dateOnlyFormat.format(voucher.expiresAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isExpired ? AppColors.error : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Status & Action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isRedeemed) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Riscattato', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
                if (voucher.redeemedAt != null) ...[
                  const SizedBox(height: 3),
                  Text(dateFormat.format(voucher.redeemedAt!), style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ] else if (isExpired) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Scaduto', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => _openRedeemDialog(org, initialCode: voucher.code),
                  icon: const Icon(Icons.info_outline, size: 14),
                  label: const Text('Dettagli'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () => _openRedeemDialog(org, initialCode: voucher.code),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                  label: const Text('Riscatta in cassa'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                if (voucher.expiresAt != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${voucher.remainingDays ?? 0} gg rimasti',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (voucher.remainingDays ?? 0) <= 3 ? AppColors.warning : AppColors.textSecondary,
                    ),
                  ),
                ] else if (voucher.claimedAt != null) ...[
                  const SizedBox(height: 3),
                  Text('Attivato il: ${dateFormat.format(voucher.claimedAt!)}', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Organization org) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_offer_rounded, size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)['no_promotions_yet'], style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text(
                AppLocalizations.of(context)['no_promotions_desc'],
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openCreateDialog(org, []),
              icon: const Icon(Icons.add_rounded),
              label: Text(AppLocalizations.of(context)['new_promotion_btn']),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
