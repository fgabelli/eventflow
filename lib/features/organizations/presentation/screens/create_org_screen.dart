import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';

class CreateOrgScreen extends ConsumerStatefulWidget {
  const CreateOrgScreen({super.key});

  @override
  ConsumerState<CreateOrgScreen> createState() => _CreateOrgScreenState();
}

class _CreateOrgScreenState extends ConsumerState<CreateOrgScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createOrganization() async {
    setState(() => _isLoading = true);

    try {
      final appUser = ref.read(appUserProvider).value;
      if (appUser == null) return;

      // If user already has an organization, inform and redirect
      if (appUser.organizationIds.isNotEmpty) {
        // Ensure activeOrgId is set
        await ref.read(authServiceProvider).createOrganization(
          '', // name unused — existing org path
          appUser.id,
          appUser.email,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(AppLocalizations.of(context)['org_already_exists'])),
                ],
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
            ),
          );
          context.go('/');
        }
        return;
      }

      // If no name provided, use the user's display name or email prefix
      String name = _nameController.text.trim();
      if (name.isEmpty) {
        name = appUser.displayName ?? appUser.email.split('@').first;
        // Capitalize first letter
        if (name.isNotEmpty) {
          name = '${name[0].toUpperCase()}${name.substring(1)}';
        }
      }

      await ref.read(authServiceProvider).createOrganization(
        name,
        appUser.id,
        appUser.email,
      );

      // Navigate explicitly after successful creation
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)['error_generic_short']}: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserProvider).value;
    final userName = appUser?.displayName ?? appUser?.email.split('@').first ?? '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E1B4B),
              Color(0xFF312E81),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/ticketto_logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'Benvenuto, $userName! 👋',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Manca solo un passo per iniziare a creare i tuoi eventi.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Workspace name field (optional)
                          Text(
                            'Nome del workspace',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Opzionale — se lo lasci vuoto useremo il tuo nome.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: userName,
                              prefixIcon: const Icon(Icons.apartment_rounded),
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _createOrganization(),
                          ),
                          const SizedBox(height: 24),

                          // Quick start button
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _createOrganization,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.rocket_launch_rounded, size: 20),
                                        const SizedBox(width: 10),
                                        Text(AppLocalizations.of(context)['start_now']),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Info box
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Il workspace è il tuo spazio di lavoro dove gestisci eventi e partecipanti. Puoi sempre cambiare il nome dalle impostazioni.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => ref.read(authServiceProvider).signOut(),
                      icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                      label: const Text(
                        'Esci',
                        style: TextStyle(color: Colors.white70),
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
}
