import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/providers/connectivity_provider.dart';
import 'package:app/core/services/connectivity_service.dart';
import 'package:app/core/services/home_widget_service.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/expenses/presentation/providers/expense_provider.dart';
import 'package:app/core/theme/theme_provider.dart';
import 'package:app/routing/app_router.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

      // Initialize Hive
      await Hive.initFlutter();
      await Future.wait([
        Hive.openBox('settings'),
        Hive.openBox('groups_cache'),
        Hive.openBox('expenses_cache'),
        Hive.openBox('group_members_cache'),
        Hive.openBox('pending_expenses'),
      ]);

      // Check real connectivity before runApp so isOnline is accurate from start.
      await ConnectivityService.instance.init();

      // Initialize FlutterGemma (required before any model API call)
      const hfToken = String.fromEnvironment('HF_TOKEN', defaultValue: '');
      await FlutterGemma.initialize(
        huggingFaceToken: hfToken.isNotEmpty ? hfToken : null,
      );

      // Initialize HomeWidget App Group
      await HomeWidgetService.instance.init();

      runApp(const ProviderScope(child: OkaeriSplitApp()));
    },
    (error, stack) {
      // supabase_flutter 2.x re-processes the recovery deep link via
      // uriLinkStream after already consuming it via getInitialAppLink,
      // causing an unhandled otp_expired AuthException. Suppress it.
      if (error is AuthException && error.statusCode == 'otp_expired') return;
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
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
      await Supabase.instance.client.auth.signOut(
        scope: SignOutScope.local,
      );
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
      supportedLocales: const [
        Locale('zh', 'TW'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
