import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/core/widgets/help_tip.dart';
import 'package:eventflow/features/onboarding/presentation/onboarding_tutorial.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _showChatbot = true;

  @override
  void initState() {
    super.initState();
    try {
      _showChatbot = html.window.localStorage['show_chatbot'] != 'false';
    } catch (_) {}
  }

  Widget _buildFallbackOrgAvatar(Organization? org) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          org?.name.isNotEmpty == true ? org!.name[0].toUpperCase() : '🏢',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildOrgLogoImage(String? url, {double? width, double? height, BoxFit fit = BoxFit.cover, Widget Function()? fallback}) {
    if (url == null || url.trim().isEmpty) {
      return fallback != null ? fallback() : const SizedBox.shrink();
    }
    final trimmed = url.trim();
    if (trimmed.startsWith('data:image/')) {
      try {
        final comma = trimmed.indexOf(',');
        if (comma != -1) {
          final bytes = base64Decode(trimmed.substring(comma + 1));
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => fallback != null ? fallback() : const Icon(Icons.broken_image),
          );
        }
      } catch (_) {}
    }
    return Image.network(
      trimmed,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback != null ? fallback() : const Icon(Icons.broken_image),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserProvider).value;
    final org = ref.watch(currentOrgProvider).value;
    final l = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(l['settings'], style: Theme.of(context).textTheme.headlineMedium),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Section
          _SectionHeader(title: l['profile']),
          _SettingsCard(
            children: [
              ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: appUser?.photoUrl != null
                      ? NetworkImage(appUser!.photoUrl!)
                      : null,
                  child: appUser?.photoUrl == null
                      ? Text(
                          (appUser?.displayName?.isNotEmpty == true)
                              ? appUser!.displayName![0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                title: Text(appUser?.displayName ?? 'User'),
                subtitle: Text(appUser?.email ?? ''),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Organization Section
          _SectionHeader(title: l['organization']),
          _SettingsCard(
            children: [
              ListTile(
                leading: org?.logo != null && org!.logo!.isNotEmpty
                    ? Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildOrgLogoImage(
                            org.logo,
                            fit: BoxFit.cover,
                            fallback: () => _buildFallbackOrgAvatar(org),
                          ),
                        ),
                      )
                    : _buildFallbackOrgAvatar(org),
                title: Text(org?.name ?? 'Organization'),
                subtitle: Text('${l['plan_label']}: ${org?.plan.label ?? 'Free'} • ${l['org_branding']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showEditOrgDialog(context, org),
              ),
              const Divider(indent: 72),
              ListTile(
                leading: const _SettingsIcon(icon: Icons.people_outline, color: AppColors.accent),
                title: Row(
                  children: [
                    Text(l['team_members']),
                    HelpTip(text: l['help_team'], iconSize: 16),
                  ],
                ),
                subtitle: Text(l['manage_roles']),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/team'),
              ),
              const Divider(indent: 72),
              ListTile(
                leading: const _SettingsIcon(icon: Icons.swap_horiz, color: AppColors.warning),
                title: Text(l['switch_org']),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Show org switcher
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Payments Section (Stripe Connect)
          _SectionHeader(title: l['payments'], helpText: l['help_stripe_connect']),
          _buildStripeConnectSection(context, ref, org, appUser?.email),

          const SizedBox(height: 24),

          // App Settings
          _SectionHeader(title: 'App'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const _SettingsIcon(icon: Icons.notifications_outlined, color: AppColors.primary),
                title: Text(l['notifications']),
                trailing: Switch(
                  value: true,
                  onChanged: (v) {
                    // TODO: Toggle notifications
                  },
                  activeColor: AppColors.primary,
                ),
              ),
              const Divider(indent: 72),
              ListTile(
                leading: const _SettingsIcon(icon: Icons.smart_toy_outlined, color: AppColors.primary),
                title: Text(l['show_chatbot_label']),
                subtitle: Text(l['show_chatbot_desc']),
                trailing: Switch(
                  value: _showChatbot,
                  onChanged: (v) {
                    setState(() => _showChatbot = v);
                    try {
                      html.window.localStorage['show_chatbot'] = v.toString();
                      html.window.dispatchEvent(html.CustomEvent('toggle_chatbot', detail: v));
                    } catch (_) {}
                  },
                  activeColor: AppColors.primary,
                ),
              ),
              const Divider(indent: 72),
              ListTile(
                leading: const _SettingsIcon(icon: Icons.language, color: AppColors.accent),
                title: Row(
                  children: [
                    Text(l['language']),
                    HelpTip(text: l['help_language'], iconSize: 16),
                  ],
                ),
                subtitle: Text(currentLocale.languageCode == 'it' ? '🇮🇹 ${l['italian']}' : '🇬🇧 ${l['english']}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    currentLocale.languageCode.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l['language']),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LanguageOption(
                            flag: '🇮🇹',
                            label: l['italian'],
                            isSelected: currentLocale.languageCode == 'it',
                            onTap: () {
                              setAndPersistLocale(ref, 'it');
                              Navigator.pop(ctx);
                            },
                          ),
                          const SizedBox(height: 8),
                          _LanguageOption(
                            flag: '🇬🇧',
                            label: l['english'],
                            isSelected: currentLocale.languageCode == 'en',
                            onTap: () {
                              setAndPersistLocale(ref, 'en');
                              Navigator.pop(ctx);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const Divider(indent: 72),
              ListTile(
                leading: const _SettingsIcon(icon: Icons.info_outline, color: AppColors.textTertiary),
                title: Text(l['info']),
                subtitle: const Text('Ticketto v1.0.0'),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Ticketto',
                    applicationVersion: '1.0.0',
                    applicationIcon: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/images/ticketto_logo.png', width: 48, height: 48),
                    ),
                    children: [
                      Text(l['about_description'] ?? 'Ticketto — La piattaforma per la gestione degli eventi.'),
                    ],
                  );
                },
              ),
              const Divider(indent: 72),
              ListTile(
                leading: const _SettingsIcon(icon: Icons.school_outlined, color: AppColors.accent),
                title: Text(l['tutorial_restart']),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  // Reset tutorial state
                  html.window.localStorage.remove('tutorial_complete');
                  final user = ref.read(appUserProvider).value;
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.id)
                        .update({'hasSeenTutorial': false});
                  }
                  if (context.mounted) {
                    context.go('/');
                    // Show tutorial after navigating
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        showGeneralDialog(
                          context: context,
                          barrierDismissible: false,
                          barrierColor: Colors.transparent,
                          pageBuilder: (_, __, ___) => const OnboardingTutorial(),
                          transitionDuration: Duration.zero,
                        );
                      }
                    });
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Danger zone
          _SettingsCard(
            children: [
              ListTile(
                leading: const _SettingsIcon(icon: Icons.logout, color: AppColors.error),
                title: Text(l['sign_out'], style: const TextStyle(color: AppColors.error)),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      final dl = AppLocalizations.of(context);
                      return AlertDialog(
                        title: Text(dl['sign_out']),
                        content: Text(dl['sign_out_confirm']),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(dl['cancel']),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                            child: Text(dl['sign_out']),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirm == true) {
                    await ref.read(authServiceProvider).signOut();
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStripeConnectSection(BuildContext context, WidgetRef ref, dynamic org, String? userEmail) {
    if (org == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(Collections.organizations)
          .doc(org.id)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final connectAccountId = data?['stripeConnectAccountId'] as String?;
        final connectStatus = data?['stripeConnectStatus'] as String? ?? 'none';

        return Column(
          children: [
            _SettingsCard(
              children: [
                if (connectAccountId == null || connectStatus == 'none') ...[
                  // Not connected
                  ListTile(
                    leading: const _SettingsIcon(icon: Icons.account_balance_wallet_outlined, color: Color(0xFF635BFF)),
                    title: Text(AppLocalizations.of(context)['connect_stripe']),
                    subtitle: Text(AppLocalizations.of(context)['stripe_subtitle']),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _connectStripe(context, org, userEmail: userEmail),
                  ),
                ] else if (connectStatus == 'pending') ...[
                  // Pending onboarding
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.pending_outlined, color: AppColors.warning, size: 22),
                    ),
                    title: Text(AppLocalizations.of(context)['stripe_pending']),
                    subtitle: Text(AppLocalizations.of(context)['stripe_pending_desc']),
                    trailing: FilledButton(
                      onPressed: () => _connectStripe(context, org, userEmail: userEmail),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.warning,
                      ),
                      child: Text(AppLocalizations.of(context)['stripe_complete_btn']),
                    ),
                  ),
                ] else ...[
                  // Active
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.check_circle_outlined, color: AppColors.success, size: 22),
                    ),
                    title: Text(AppLocalizations.of(context)['stripe_connected']),
                    subtitle: Text('Account: ${connectAccountId?.substring(0, 12) ?? ''}...'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openStripeDashboard(context, org.id),
                  ),
                ],
              ],
            ),

            // Instructions — show only when not connected or pending
            if (connectAccountId == null || connectStatus == 'none' || connectStatus == 'pending') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF635BFF).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF635BFF).withValues(alpha: 0.10)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: const Color(0xFF635BFF)),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)['stripe_how_title'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF635BFF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      number: '1',
                      title: AppLocalizations.of(context)['stripe_step1_title'],
                      description: AppLocalizations.of(context)['stripe_step1_desc'],
                    ),
                    const SizedBox(height: 10),
                    _buildInstructionStep(
                      number: '2',
                      title: AppLocalizations.of(context)['stripe_step2_title'],
                      description: AppLocalizations.of(context)['stripe_step2_desc'],
                    ),
                    const SizedBox(height: 10),
                    _buildInstructionStep(
                      number: '3',
                      title: AppLocalizations.of(context)['stripe_step3_title'],
                      description: AppLocalizations.of(context)['stripe_step3_desc'],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.percent, size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)['stripe_fee_note'],
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.security_outlined, size: 14, color: AppColors.textTertiary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)['stripe_security_note'],
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _connectStripe(BuildContext context, dynamic org, {String? userEmail}) async {
    // Show loading
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)['stripe_connecting']),
            ],
          ),
          duration: const Duration(seconds: 10),
        ),
      );
    }

    try {
      final response = await http.post(
        Uri.parse('https://us-central1-eventflow-3541b.cloudfunctions.net/createConnectAccount'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orgId': org.id,
          'email': userEmail ?? '',
          'orgName': org.name,
        }),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['url'] != null) {
        final stripeUrl = Uri.parse(data['url']);
        final launched = await launchUrl(
          stripeUrl,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_self',
        );
        if (!launched && context.mounted) {
          // Fallback: show the URL so the user can copy it
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Apri manualmente: ${data['url']}'),
              duration: const Duration(seconds: 15),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'Errore nella connessione a Stripe (${response.statusCode})'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openStripeDashboard(BuildContext context, String orgId) async {
    try {
      final response = await http.get(
        Uri.parse('https://us-central1-eventflow-3541b.cloudfunctions.net/createConnectAccountLink?orgId=$orgId&type=dashboard'),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['url'] != null) {
        await launchUrl(Uri.parse(data['url']), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)['error_generic_short']}: $e')),
        );
      }
    }
  }

  Widget _buildInstructionStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF635BFF).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF635BFF),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditOrgDialog(BuildContext context, Organization? org) {
    if (org == null) return;
    final nameCtrl = TextEditingController(text: org.name);
    final logoCtrl = TextEditingController(text: org.logo ?? '');
    final hexColorCtrl = TextEditingController(text: org.primaryColor ?? '#6366F1');
    String? selectedColor = org.primaryColor ?? '#6366F1';
    bool isUploading = false;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final l = AppLocalizations.of(context);
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.business_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(l['org_branding']),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: l['org_name_label'],
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: logoCtrl,
                      decoration: InputDecoration(
                        labelText: l['org_logo_label'],
                        hintText: l['org_logo_url_hint'],
                        prefixIcon: const Icon(Icons.image_outlined),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: isUploading
                              ? null
                              : () async {
                                  try {
                                    setDialogState(() => isUploading = true);
                                    final result = await FilePicker.platform.pickFiles(
                                      type: FileType.image,
                                      withData: true,
                                    );
                                    if (result != null && result.files.single.bytes != null) {
                                      final bytes = result.files.single.bytes!;
                                      final name = result.files.single.name;
                                      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'png';
                                      final mimeType = ext == 'svg' ? 'image/svg+xml' : (ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'image/png');
                                      final base64String = base64Encode(bytes);
                                      final dataUrl = 'data:$mimeType;base64,$base64String';
                                      logoCtrl.text = dataUrl;
                                      setDialogState(() {});
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('File error: $e'), backgroundColor: AppColors.error),
                                      );
                                    }
                                  } finally {
                                    setDialogState(() => isUploading = false);
                                  }
                                },
                          icon: isUploading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.cloud_upload_outlined, size: 18),
                          label: Text(l['upload_logo_btn']),
                        ),
                        const SizedBox(width: 12),
                        if (logoCtrl.text.trim().isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: _buildOrgLogoImage(logoCtrl.text.trim()),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(l['event_color'], style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        {'name': 'Viola', 'hex': '#6366F1', 'color': const Color(0xFF6366F1)},
                        {'name': 'Blu Oceano', 'hex': '#1B5E9E', 'color': const Color(0xFF1B5E9E)},
                        {'name': 'Teal', 'hex': '#0D9488', 'color': const Color(0xFF0D9488)},
                        {'name': 'Smeraldo', 'hex': '#10B981', 'color': const Color(0xFF10B981)},
                        {'name': 'Ambra', 'hex': '#D97706', 'color': const Color(0xFFD97706)},
                        {'name': 'Rosso', 'hex': '#E11D48', 'color': const Color(0xFFE11D48)},
                        {'name': 'Dark Grafite', 'hex': '#1E293B', 'color': const Color(0xFF1E293B)},
                      ].map((preset) {
                        final hex = preset['hex'] as String;
                        final isSelected = selectedColor?.toUpperCase() == hex.toUpperCase();
                        final color = preset['color'] as Color;

                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedColor = hex;
                              hexColorCtrl.text = hex;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check, size: 10, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  preset['name'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hexColorCtrl,
                      decoration: InputDecoration(
                        labelText: l['custom_hex_color'],
                        hintText: '#1B5E9E',
                        prefixIcon: const Icon(Icons.colorize_outlined),
                      ),
                      onChanged: (val) {
                        if (val.trim().startsWith('#') && val.trim().length >= 7) {
                          setDialogState(() => selectedColor = val.trim());
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l['cancel']),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final newName = nameCtrl.text.trim();
                        final newLogo = logoCtrl.text.trim();
                        if (newName.isEmpty) return;

                        setDialogState(() => isSaving = true);
                        try {
                          await FirebaseFirestore.instance
                              .collection(Collections.organizations)
                              .doc(org.id)
                              .update({
                            'name': newName,
                            'logo': newLogo.isNotEmpty ? newLogo : null,
                            'primaryColor': selectedColor,
                          });
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l['save_changes']),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l['save_changes']),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? helpText;
  const _SectionHeader({required this.title, this.helpText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          if (helpText != null)
            HelpTip(text: helpText!, iconSize: 15),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _SettingsIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String flag;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _LanguageOption({
    required this.flag,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
