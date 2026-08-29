import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';

/// Onboarding tutorial overlay shown on first login.
/// Uses a full-screen spotlight approach with animated cards.
class OnboardingTutorial extends ConsumerStatefulWidget {
  const OnboardingTutorial({super.key});

  @override
  ConsumerState<OnboardingTutorial> createState() => _OnboardingTutorialState();
}

class _OnboardingTutorialState extends ConsumerState<OnboardingTutorial>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const _totalSteps = 6;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep < _totalSteps - 1) {
      _animController.reverse().then((_) {
        if (mounted) {
          setState(() => _currentStep++);
          _animController.forward();
        }
      });
    } else {
      _complete();
    }
  }

  void _complete() {
    _markTutorialComplete();
    _animController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
        // Navigate to events page on final step
        if (_currentStep == _totalSteps - 1) {
          context.go('/events');
        }
      }
    });
  }

  void _skip() {
    _markTutorialComplete();
    _animController.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _markTutorialComplete() async {
    // Save to localStorage
    html.window.localStorage['tutorial_complete'] = 'true';
    // Save to Firestore
    final user = ref.read(appUserProvider).value;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .set({'hasSeenTutorial': true}, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final step = _getStep(l);

    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Step indicator + skip
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
                      child: Row(
                        children: [
                          // Progress dots
                          Row(
                            children: List.generate(_totalSteps, (i) {
                              return Container(
                                width: i == _currentStep ? 24 : 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: i == _currentStep
                                      ? AppColors.primary
                                      : i < _currentStep
                                          ? AppColors.primary.withValues(alpha: 0.3)
                                          : AppColors.border,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _skip,
                            child: Text(
                              l['tutorial_skip'],
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Icon
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(step.icon, color: Colors.white, size: 32),
                      ),
                    ),

                    // Title
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Text(
                        step.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),

                    // Body
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Text(
                        step.body,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // CTA Button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _next,
                          style: FilledButton.styleFrom(
                            backgroundColor: _currentStep == _totalSteps - 1
                                ? AppColors.success
                                : AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _currentStep == _totalSteps - 1
                                ? l['tutorial_done_btn']
                                : '${l['tutorial_next']}  →',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _TutorialStep _getStep(AppLocalizations l) {
    switch (_currentStep) {
      case 0:
        return _TutorialStep(
          icon: Icons.dashboard_rounded,
          title: l['tutorial_welcome_title'],
          body: l['tutorial_welcome_body'],
        );
      case 1:
        return _TutorialStep(
          icon: Icons.event_rounded,
          title: l['tutorial_events_title'],
          body: l['tutorial_events_body'],
        );
      case 2:
        return _TutorialStep(
          icon: Icons.people_rounded,
          title: l['tutorial_attendees_title'],
          body: l['tutorial_attendees_body'],
        );
      case 3:
        return _TutorialStep(
          icon: Icons.qr_code_scanner_rounded,
          title: l['tutorial_checkin_title'],
          body: l['tutorial_checkin_body'],
        );
      case 4:
        return _TutorialStep(
          icon: Icons.settings_rounded,
          title: l['tutorial_settings_title'],
          body: l['tutorial_settings_body'],
        );
      case 5:
        return _TutorialStep(
          icon: Icons.rocket_launch_rounded,
          title: l['tutorial_done_title'],
          body: l['tutorial_done_body'],
        );
      default:
        return _TutorialStep(
          icon: Icons.help,
          title: '',
          body: '',
        );
    }
  }
}

class _TutorialStep {
  final IconData icon;
  final String title;
  final String body;
  const _TutorialStep({required this.icon, required this.title, required this.body});
}

/// Call this to check and show the tutorial on first login.
Future<void> maybeShowTutorial(BuildContext context, WidgetRef ref) async {
  // Check localStorage first (fastest)
  final localDone = html.window.localStorage['tutorial_complete'];
  if (localDone == 'true') return;

  // Check Firestore
  final user = ref.read(appUserProvider).value;
  if (user == null) return;

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.id)
      .get();

  if (doc.data()?['hasSeenTutorial'] == true) {
    html.window.localStorage['tutorial_complete'] = 'true';
    return;
  }

  // Show tutorial
  if (context.mounted) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (_, __, ___) => const OnboardingTutorial(),
      transitionDuration: Duration.zero,
    );
  }
}
