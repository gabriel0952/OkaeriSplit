import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/providers/connectivity_provider.dart';
import 'package:app/core/services/connectivity_service.dart';
import 'package:app/core/services/home_widget_service.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/core/theme/theme_provider.dart';
import 'package:app/routing/app_router.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns a [HiveAesCipher] backed by a persistent key in secure storage.
/// Creates and stores a new 32-byte key on first call.
Future<HiveAesCipher> _getOrCreateHiveCipher() async {
  const storage = FlutterSecureStorage();
  const _kHiveKey = 'hive_encryption_key';
  final encoded = await storage.read(key: _kHiveKey);
  if (encoded != null) {
    return HiveAesCipher(base64Decode(encoded));
  }
  final key = Hive.generateSecureKey();
  await storage.write(key: _kHiveKey, value: base64Encode(key));
  return HiveAesCipher(key);
}

/// Opens a Hive box with encryption.
/// If the box already exists without encryption (e.g. migrating from an older
/// build), deletes it and opens a fresh encrypted box.
Future<void> _openEncryptedBox(String name, HiveAesCipher cipher) async {
  try {
    await Hive.openBox(name, encryptionCipher: cipher);
  } catch (_) {
    await Hive.deleteBoxFromDisk(name);
    await Hive.openBox(name, encryptionCipher: cipher);
  }
}

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize Supabase
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );

      // Initialize Hive with encryption.
      // The AES key is stored in FlutterSecureStorage (iOS Keychain /
      // Android Keystore) and generated once on first launch.
      // If an existing unencrypted box is found (e.g. app update from older
      // version), it is deleted and re-opened clean — all boxes are caches
      // whose source of truth lives in Supabase.
      await Hive.initFlutter();
      final cipher = await _getOrCreateHiveCipher();
      await Future.wait([
        _openEncryptedBox('settings', cipher),
        _openEncryptedBox('groups_cache', cipher),
        _openEncryptedBox('expenses_cache', cipher),
        _openEncryptedBox('group_members_cache', cipher),
        _openEncryptedBox('pending_expenses', cipher),
      ]);

      // Check real connectivity before runApp so isOnline is accurate from start.
      await ConnectivityService.instance.init();

      // Initialize HomeWidget App Group
      await HomeWidgetService.instance.init();

      runApp(const ProviderScope(child: OkaeriSplitApp()));
    },
    (error, stack) {
      // supabase_flutter 2.x re-processes the recovery deep link via
      // uriLinkStream after already consuming it via getInitialAppLink,
      // causing an unhandled otp_expired AuthException. Suppress it.
      if (error is AuthException && error.statusCode == 'otp_expired') return;
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    },
  );
}

class OkaeriSplitApp extends ConsumerStatefulWidget {
  const OkaeriSplitApp({super.key});

  @override
  ConsumerState<OkaeriSplitApp> createState() => _OkaeriSplitAppState();
}

class _OkaeriSplitAppState extends ConsumerState<OkaeriSplitApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen to connectivity changes and flush pending expenses when back online.
    ref.listenManual(connectivityProvider, (prev, next) {
      next.whenData((isOnline) {
        if (isOnline) {
          ref.read(syncServiceProvider).flush();
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final isOnline = ref.read(isOnlineProvider);
      if (isOnline) {
        ref.read(syncServiceProvider).flush();
      }
      // If current user is a guest, validate session against server.
      // admin.deleteUser() invalidates the refresh token immediately.
      // refreshSession() will fail with AuthException → force local sign-out
      // → SIGNED_OUT event → router redirects to /login.
      final isGuest = ref.read(isGuestProvider);
      if (isGuest && isOnline) {
        _checkGuestSession();
      }
    }
  }

  Future<void> _checkGuestSession() async {
    try {
      await Supabase.instance.client.auth.refreshSession();
    } on AuthException catch (_) {
      // Refresh token rejected — account was deleted. Sign out locally so
      // SIGNED_OUT is emitted and the router redirects to /login.
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    }
    // Other exceptions (e.g. network) are ignored — don't sign out offline users.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'TW'),
      supportedLocales: const [Locale('zh', 'TW'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
