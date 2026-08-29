import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isYearly = true;
  bool _isLoading = false;

  SubscriptionPlan get _currentPlan {
    final org = ref.watch(currentOrgProvider).value;
    return org?.plan ?? SubscriptionPlan.free;
  }

  Future<void> _handleSubscribe(SubscriptionPlan plan) async {
    if (plan == _currentPlan) return;
    
    final org = ref.read(currentOrgProvider).value;
    if (org == null) return;

    setState(() => _isLoading = true);

    try {
      // Create Stripe Checkout session via Cloud Function
      final user = ref.read(appUserProvider).value;
      if (user == null) return;

      final priceId = _isYearly
          ? _getYearlyPriceId(plan)
          : _getMonthlyPriceId(plan);

      final docRef = await FirebaseFirestore.instance
          .collection('stripe_checkout_sessions')
          .add({
        'orgId': org.id,
        'userId': user.id,
        'email': user.email,
        'priceId': priceId,
        'plan': plan.name,
        'billingCycle': _isYearly ? 'yearly' : 'monthly',
        'successUrl': '${Uri.base.origin}/settings?session_id={CHECKOUT_SESSION_ID}',
        'cancelUrl': '${Uri.base.origin}/subscription',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Listen for the checkout URL created by Cloud Function
      docRef.snapshots().listen((snap) {
        final data = snap.data();
        if (data != null && data['url'] != null) {
          launchUrl(Uri.parse(data['url']), mode: LaunchMode.externalApplication);
        }
        if (data != null && data['error'] != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${AppLocalizations.of(context)['error_generic_short']}: ${data['error']}'), backgroundColor: AppColors.error),
            );
            setState(() => _isLoading = false);
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)['error_generic_short']}: $e'), backgroundColor: AppColors.error),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  String _getMonthlyPriceId(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.pro:
        return 'price_1T1ZfEACt8KFe0S0ofhDwKYq';
      case SubscriptionPlan.business:
        return 'price_1T1ZfSACt8KFe0S0IuMAPQTm';
      default:
        return '';
    }
  }

  String _getYearlyPriceId(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.pro:
        return 'price_1T1ZfLACt8KFe0S0rPJmtP4p';
      case SubscriptionPlan.business:
        return 'price_1T1ZfZACt8KFe0S0DYxK6R9X';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 32),

            // Billing toggle
            _buildBillingToggle(),
            const SizedBox(height: 40),

            // Plans
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildPlanCard(SubscriptionPlan.free)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildPlanCard(SubscriptionPlan.pro, highlighted: true)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildPlanCard(SubscriptionPlan.business)),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildPlanCard(SubscriptionPlan.free),
                    const SizedBox(height: 20),
                    _buildPlanCard(SubscriptionPlan.pro, highlighted: true),
                    const SizedBox(height: 20),
                    _buildPlanCard(SubscriptionPlan.business),
                  ],
                );
              },
            ),
            const SizedBox(height: 48),

            // FAQ
            _buildFAQ(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
           child: const Text(
            '💎 PREZZI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Scegli il piano perfetto\nper i tuoi eventi',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Inizia gratis, scala quando cresci',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBillingToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton('Mensile', !_isYearly, () => setState(() => _isYearly = false)),
          _buildToggleButton('Annuale  -28%', _isYearly, () => setState(() => _isYearly = true)),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, {bool highlighted = false}) {
    final isCurrent = plan == _currentPlan;
    final price = _isYearly ? plan.yearlyPrice : plan.monthlyPrice;
    final monthlyEquiv = _isYearly && plan.yearlyPrice > 0
        ? (plan.yearlyPrice / 12).round()
        : plan.monthlyPrice;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted ? AppColors.primary : (isCurrent ? AppColors.success : AppColors.border),
          width: highlighted || isCurrent ? 2 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          // Popular badge
          if (highlighted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: const Text(
                '⭐ PIÙ POPOLARE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan name + badge
                Row(
                  children: [
                    Text(
                      plan.label,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ATTUALE',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getPlanDescription(plan),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Price
                if (plan.isFree)
                  const Text(
                    'Gratis',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '€$monthlyEquiv',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Text(
                          '/mese',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_isYearly && plan.isPaid)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '€$price fatturato annualmente',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ),
                const SizedBox(height: 24),

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: isCurrent
                      ? OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Piano attuale'),
                        )
                      : plan.isFree
                          ? OutlinedButton(
                              onPressed: null,
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Incluso'),
                            )
                          : ElevatedButton(
                              onPressed: _isLoading ? null : () => _handleSubscribe(plan),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: highlighted ? AppColors.primary : AppColors.textPrimary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      _currentPlan.index < plan.index ? 'Aggiorna a ${plan.label}' : 'Cambia piano',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                            ),
                ),
                const SizedBox(height: 24),

                // Divider
                const Divider(),
                const SizedBox(height: 16),

                // Features list
                ..._getPlanFeatures(plan).map((f) => _buildFeatureRow(f)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(_Feature feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: feature.included
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.textTertiary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              feature.included ? Icons.check_rounded : Icons.close_rounded,
              size: 14,
              color: feature.included ? AppColors.success : AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              feature.label,
              style: TextStyle(
                fontSize: 13,
                color: feature.included ? AppColors.textPrimary : AppColors.textTertiary,
                fontWeight: feature.included ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPlanDescription(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 'Perfetto per iniziare e provare la piattaforma';
      case SubscriptionPlan.pro:
        return 'Per organizzatori che gestiscono eventi regolarmente';
      case SubscriptionPlan.business:
        return 'Per aziende e agenzie con esigenze professionali';
    }
  }

  List<_Feature> _getPlanFeatures(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return [
          _Feature('1 evento attivo', true),
          _Feature('Fino a 50 partecipanti', true),
          _Feature('Check-in via smartphone', true),
          _Feature('Email di conferma automatica', true),
          _Feature('Eventi online (Zoom/Meet)', true),
          _Feature('Supporto base', true),
          _Feature('Pagamenti con Stripe', false),
          _Feature('Biglietto PDF e Wallet', false),
          _Feature('Esportazione Badge PDF A4', false),
          _Feature('Notifiche real-time', false),
          _Feature('Importazione da CSV', false),
          _Feature('Stampa termica Zero-Tap', false),
        ];
      case SubscriptionPlan.pro:
        return [
          _Feature('10 eventi attivi', true),
          _Feature('Fino a 500 partecipanti', true),
          _Feature('Check-in via smartphone', true),
          _Feature('Email di conferma automatica', true),
          _Feature('Eventi online (Zoom/Meet)', true),
          _Feature('Supporto base', true),
          _Feature('Pagamenti con Stripe', true),
          _Feature('Biglietto PDF e Wallet', true),
          _Feature('Esportazione Badge PDF A4', true),
          _Feature('Notifiche real-time', true),
          _Feature('Importazione da CSV', true),
          _Feature('Stampa termica Zero-Tap', false),
        ];
      case SubscriptionPlan.business:
        return [
          _Feature('Eventi illimitati', true),
          _Feature('Partecipanti illimitati', true),
          _Feature('Check-in via smartphone', true),
          _Feature('Email di conferma automatica', true),
          _Feature('Eventi online (Zoom/Meet)', true),
          _Feature('Supporto base', true),
          _Feature('Pagamenti con Stripe', true),
          _Feature('Biglietto PDF e Wallet', true),
          _Feature('Esportazione Badge PDF A4', true),
          _Feature('Notifiche real-time', true),
          _Feature('Importazione da CSV', true),
          _Feature('Stampa termica Zero-Tap', true),
        ];
    }
  }

  Widget _buildFAQ() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(
        children: [
          const Text(
            'Domande frequenti',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          _buildFAQItem(
            'Posso cambiare piano in qualsiasi momento?',
            'Sì, puoi aggiornare o declassare il tuo piano in qualsiasi momento. Le modifiche saranno effettive immediatamente.',
          ),
          _buildFAQItem(
            'Cosa succede quando scade il mio abbonamento?',
            'Il tuo account tornerà automaticamente al piano FREE. I tuoi dati saranno conservati, ma le funzionalità premium saranno disabilitate.',
          ),
          _buildFAQItem(
            'Quali metodi di pagamento accettate?',
            'Accettiamo tutte le principali carte di credito/debito (Visa, Mastercard, American Express) tramite Stripe, il processore di pagamenti più sicuro al mondo.',
          ),
          _buildFAQItem(
            'Posso richiedere un rimborso?',
            'Sì, offriamo un rimborso completo entro 14 giorni dall\'acquisto se non sei soddisfatto del servizio.',
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        shape: const Border(),
        title: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Text(
            answer,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature {
  final String label;
  final bool included;
  const _Feature(this.label, this.included);
}
