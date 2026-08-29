import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:eventflow/core/models.dart';
import 'package:eventflow/core/constants/app_constants.dart';
import 'package:eventflow/core/analytics/analytics_service.dart';

// ─── Firebase Auth State Provider ──────────────────────────────────

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// ─── Current AppUser Provider ──────────────────────────────────────

final appUserProvider = StreamProvider<AppUser?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  final user = authAsync.value;
  if (user == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection(Collections.users)
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
});

// ─── Current Organization Provider ─────────────────────────────────

final currentOrgProvider = StreamProvider<Organization?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser?.activeOrgId == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection(Collections.organizations)
      .doc(appUser!.activeOrgId)
      .snapshots()
      .map((doc) => doc.exists ? Organization.fromFirestore(doc) : null);
});

// ─── Current User Role Provider ────────────────────────────────────

final currentRoleProvider = StreamProvider<OrgRole?>((ref) {
  final appUser = ref.watch(appUserProvider).value;
  if (appUser?.activeOrgId == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection(Collections.organizations)
      .doc(appUser!.activeOrgId)
      .collection('members')
      .where('userId', isEqualTo: appUser.id)
      .limit(1)
      .snapshots()
      .map((snap) {
        if (snap.docs.isEmpty) return null;
        final data = snap.docs.first.data();
        return OrgRole.values.firstWhere(
          (r) => r.name == data['role'],
          orElse: () => OrgRole.viewer,
        );
      });
});

// ─── Auth Service Provider ─────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      return _signInWithGoogleWeb();
    } else {
      return _signInWithGoogleNative();
    }
  }

  // ─── Web: Use Firebase Auth popup directly ───────────────────
  Future<User?> _signInWithGoogleWeb() async {
    final provider = GoogleAuthProvider();
    provider.addScope('email');
    provider.addScope('profile');
    
    final userCredential = await _auth.signInWithPopup(provider);
    if (userCredential.user != null) {
      await _ensureUserDocument(userCredential.user!);
      // Track sign_up or login based on isNewUser
      final isNew = userCredential.additionalUserInfo?.isNewUser ?? false;
      final uid = userCredential.user!.uid;
      await AnalyticsService.instance.setUserId(uid);
      await AnalyticsService.instance.logEvent(
        isNew ? 'sign_up' : 'login',
        params: {'method': 'google'},
      );
    }
    return userCredential.user;
  }

  // ─── Native (iOS/Android): Use google_sign_in package ────────
  Future<User?> _signInWithGoogleNative() async {
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize();

    final GoogleSignInAccount account;
    try {
      account = await googleSignIn.authenticate();
    } on GoogleSignInException {
      return null;
    }

    final auth = account.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: auth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    if (userCredential.user != null) {
      await _ensureUserDocument(userCredential.user!);
      // Track sign_up or login based on isNewUser
      final isNew = userCredential.additionalUserInfo?.isNewUser ?? false;
      final uid = userCredential.user!.uid;
      await AnalyticsService.instance.setUserId(uid);
      await AnalyticsService.instance.logEvent(
        isNew ? 'sign_up' : 'login',
        params: {'method': 'google'},
      );
    }
    return userCredential.user;
  }

  // Sign in with email/password
  Future<User?> signInWithEmail(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (userCredential.user != null) {
      await AnalyticsService.instance.setUserId(userCredential.user!.uid);
      await AnalyticsService.instance.logEvent('login', params: {'method': 'email'});
    }
    return userCredential.user;
  }

  // Sign up with email/password
  Future<User?> signUpWithEmail(String email, String password, String displayName) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (userCredential.user != null) {
      await userCredential.user!.updateDisplayName(displayName);
      await _ensureUserDocument(userCredential.user!);
      await AnalyticsService.instance.setUserId(userCredential.user!.uid);
      await AnalyticsService.instance.logEvent('sign_up', params: {'method': 'email'});
    }
    return userCredential.user;
  }

  // Sign out
  Future<void> signOut() async {
    await AnalyticsService.instance.setUserId(null);
    await _auth.signOut();
  }

  // Create user document if not exists
  Future<void> _ensureUserDocument(User firebaseUser) async {
    final docRef = _db.collection(Collections.users).doc(firebaseUser.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      final appUser = AppUser(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName,
        photoUrl: firebaseUser.photoURL,
      );
      await docRef.set(appUser.toFirestore());
    }
  }

  // Create organization and set user as owner
  Future<String> createOrganization(String name, String userId, String userEmail) async {
    // Prevent duplicate organizations for the same user
    final userDoc = await _db.collection(Collections.users).doc(userId).get();
    final existingOrgIds = (userDoc.data()?['organizationIds'] as List<dynamic>?)?.cast<String>() ?? [];
    if (existingOrgIds.isNotEmpty) {
      // User already has an org — just make the first one active
      final activeOrgId = existingOrgIds.first;
      await _db.collection(Collections.users).doc(userId).update({
        'activeOrgId': activeOrgId,
      });
      return activeOrgId;
    }

    final orgRef = _db.collection(Collections.organizations).doc();
    final org = Organization(id: orgRef.id, name: name);
    await orgRef.set(org.toFirestore());

    // Add user as owner
    final memberRef = orgRef.collection('members').doc(userId);
    final member = OrgMember(
      id: userId,
      orgId: orgRef.id,
      userId: userId,
      email: userEmail,
      role: OrgRole.owner,
    );
    await memberRef.set(member.toFirestore());

    // Update user's organization list
    await _db.collection(Collections.users).doc(userId).update({
      'organizationIds': FieldValue.arrayUnion([orgRef.id]),
      'activeOrgId': orgRef.id,
    });

    await AnalyticsService.instance.logEvent('organization_created');
    return orgRef.id;
  }

  // Switch active organization
  Future<void> switchOrganization(String userId, String orgId) async {
    await _db.collection(Collections.users).doc(userId).update({
      'activeOrgId': orgId,
    });
  }
}
