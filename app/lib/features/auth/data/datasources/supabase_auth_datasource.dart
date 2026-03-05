import 'dart:convert';
import 'dart:math';

import 'package:app/features/auth/domain/entities/user_entity.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthDataSource {
  const SupabaseAuthDataSource(this._client);
  final SupabaseClient _client;

  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return _mapUser(response.user!);
  }

  Future<UserEntity> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
    return _mapUser(response.user!);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  UserEntity? getCurrentUser() {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _mapUser(user);
  }

  Stream<UserEntity?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      if (user == null) return null;
      return _mapUser(user);
    });
  }

  Future<void> signInWithGoogle() async {
    final res = await _client.auth.getOAuthSignInUrl(
      provider: OAuthProvider.google,
      redirectTo: 'com.raycat.okaerisplit://login-callback',
    );

    final result = await FlutterWebAuth2.authenticate(
      url: res.url,
      callbackUrlScheme: 'com.raycat.okaerisplit',
    );

    await _client.auth.getSessionFromUrl(Uri.parse(result));
  }

  Future<void> signInWithApple() async {
    final rawNonce = _generateRandomString();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) throw AuthException('No ID token from Apple');

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  Future<void> deleteAccount() async {
    await _client.rpc('delete_user_account');
    await _client.auth.signOut();
  }

  UserEntity _mapUser(User user) {
    return UserEntity(
      id: user.id,
      email: user.email ?? '',
      displayName:
          user.userMetadata?['display_name'] as String? ??
          user.email?.split('@').first ??
          '',
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
    );
  }

  static String _generateRandomString([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}
