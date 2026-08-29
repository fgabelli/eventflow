import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:eventflow/core/theme/app_theme.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/utils/feature_gate.dart';
import 'package:eventflow/features/auth/presentation/providers/auth_providers.dart';
import 'package:eventflow/core/l10n/app_localizations.dart';

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  @override
  Widget build(BuildContext context) {
    final org = ref.watch(currentOrgProvider).value;
    final currentUser = ref.watch(appUserProvider).value;

    if (org == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
        title: Text(AppLocalizations.of(context)['team_members'], style: Theme.of(context).textTheme.headlineMedium),
        actions: [
          FilledButton.icon(
            onPressed: () => _tryInviteMember(context, org),
            icon: const Icon(Icons.person_add, size: 18),
            label: Text(AppLocalizations.of(context)['invite_member']),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('organizations')
            .doc(org.id)
            .collection('members')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = snapshot.data?.docs
              .map((d) => OrgMember.fromFirestore(d))
              .toList() ?? [];

          if (members.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 64, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)['no_team_members'], style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            );
          }

          // Sort: owner first, then admin, staff, viewer
          members.sort((a, b) => a.role.index.compareTo(b.role.index));

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Stats
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _TeamStat(label: AppLocalizations.of(context)['members_stat'], value: '${members.length}', icon: Icons.people),
                    _TeamStat(label: AppLocalizations.of(context)['admins_stat'], value: '${members.where((m) => m.role == OrgRole.admin || m.role == OrgRole.owner).length}', icon: Icons.admin_panel_settings),
                    _TeamStat(label: AppLocalizations.of(context)['staff_stat'], value: '${members.where((m) => m.role == OrgRole.staff).length}', icon: Icons.badge),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Members list
              ...members.map((member) => _MemberCard(
                member: member,
                isCurrentUser: member.userId == currentUser?.id,
                onRoleChange: (role) => _changeRole(org.id, member.id, role),
                onRemove: () => _removeMember(org.id, member),
              )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changeRole(String orgId, String memberId, OrgRole newRole) async {
    await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .doc(memberId)
        .update({'role': newRole.name});
  }

  Future<void> _removeMember(String orgId, OrgMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l['remove_member']),
          content: Text('${l['remove_confirm']}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l['cancel'])),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: Text(l['remove']),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .collection('members')
          .doc(member.id)
          .delete();
    }
  }

  Future<void> _tryInviteMember(BuildContext context, Organization org) async {
    final plan = org.plan;

    // Check team member limit
    if (!plan.isUnlimitedTeam) {
      final membersSnap = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(org.id)
          .collection('members')
          .get();
      final currentCount = membersSnap.docs.length;

      if (currentCount >= plan.maxTeamMembers) {
        if (!context.mounted) return;
        _showTeamLimitDialog(context, plan, currentCount);
        return;
      }
    }

    if (!context.mounted) return;
    _showInviteMemberDialog(context, org);
  }

  void _showTeamLimitDialog(BuildContext context, SubscriptionPlan plan, int currentCount) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.group_off_rounded, color: AppColors.warning, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Limite team raggiunto',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                'Il piano ${plan.label} permette massimo ${plan.maxTeamMembers} membro/i nel team.\nAttualmente hai $currentCount membro/i. Passa a un piano superiore per aggiungerne altri.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Chiudi'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        context.go('/subscription');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Vedi Piani', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInviteMemberDialog(BuildContext context, Organization org) {
    final emailCtrl = TextEditingController();
    OrgRole selectedRole = OrgRole.staff;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(AppLocalizations.of(context)['invite_team_member'], style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('${AppLocalizations.of(context)['add_to_team_subtitle']} ${org.name}', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)['email_field'],
                      prefixIcon: const Icon(Icons.email_outlined),
                      hintText: 'member@example.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  Text(AppLocalizations.of(context)['role_label'], style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  ...OrgRole.values
                      .where((r) => r != OrgRole.owner)
                      .map((role) => RadioListTile<OrgRole>(
                            title: Text(role.label),
                            subtitle: Text(_roleDescription(role), style: const TextStyle(fontSize: 12)),
                            value: role,
                            groupValue: selectedRole,
                            activeColor: AppColors.primary,
                            onChanged: (v) => setSheetState(() => selectedRole = v!),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          )),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final email = emailCtrl.text.trim();
                        if (email.isEmpty || !email.contains('@')) return;

                        // Create member doc directly with email
                        // In a production app you'd send an invite email
                        final memberRef = FirebaseFirestore.instance
                            .collection('organizations')
                            .doc(org.id)
                            .collection('members')
                            .doc();

                        await memberRef.set({
                          'orgId': org.id,
                          'userId': '', // Will be linked when user accepts
                          'email': email,
                          'displayName': null,
                          'role': selectedRole.name,
                          'joinedAt': Timestamp.now(),
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$email ${AppLocalizations.of(context)['added_as_member']} ${selectedRole.label}'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      child: Text(AppLocalizations.of(context)['add_member_btn']),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _roleDescription(OrgRole role) {
    switch (role) {
      case OrgRole.admin: return AppLocalizations.of(context)['role_admin_desc'];
      case OrgRole.staff: return AppLocalizations.of(context)['role_staff_desc'];
      case OrgRole.viewer: return AppLocalizations.of(context)['role_viewer_desc'];
      case OrgRole.owner: return AppLocalizations.of(context)['role_owner_desc'];
    }
  }
}

class _TeamStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _TeamStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 22),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  final OrgMember member;
  final bool isCurrentUser;
  final ValueChanged<OrgRole> onRoleChange;
  final VoidCallback onRemove;

  const _MemberCard({
    required this.member,
    required this.isCurrentUser,
    required this.onRoleChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isCurrentUser ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _roleColor(member.role).withValues(alpha: 0.1),
            child: Text(
              (member.displayName ?? member.email).isNotEmpty
                  ? (member.displayName ?? member.email)[0].toUpperCase()
                  : '?',
              style: TextStyle(color: _roleColor(member.role), fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member.displayName ?? member.email,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(AppLocalizations.of(context)['you_label'], style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                if (member.displayName != null)
                  Text(member.email, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _roleColor(member.role).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              member.role.label,
              style: TextStyle(color: _roleColor(member.role), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          if (!isCurrentUser && member.role != OrgRole.owner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textTertiary),
              itemBuilder: (_) => [
                ...OrgRole.values
                    .where((r) => r != OrgRole.owner && r != member.role)
                    .map((r) => PopupMenuItem(value: 'role_${r.name}', child: Text('${AppLocalizations.of(context)['make_role']} ${r.label}'))),
                PopupMenuItem(
                  value: 'remove',
                  child: Text(AppLocalizations.of(context)['remove'], style: const TextStyle(color: AppColors.error)),
                ),
              ],
              onSelected: (value) {
                if (value == 'remove') {
                  onRemove();
                } else if (value.startsWith('role_')) {
                  final roleName = value.replaceFirst('role_', '');
                  final role = OrgRole.values.firstWhere((r) => r.name == roleName);
                  onRoleChange(role);
                }
              },
            ),
        ],
      ),
    );
  }

  Color _roleColor(OrgRole role) {
    switch (role) {
      case OrgRole.owner: return AppColors.warning;
      case OrgRole.admin: return AppColors.primary;
      case OrgRole.staff: return AppColors.accent;
      case OrgRole.viewer: return AppColors.textSecondary;
    }
  }
}
