import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/auth/presentation/screens/guest_login_screen.dart';
import 'package:app/features/auth/presentation/screens/login_screen.dart';
import 'package:app/features/auth/presentation/screens/register_screen.dart';
import 'package:app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:app/features/expenses/presentation/screens/add_expense_screen.dart';
import 'package:app/features/expenses/presentation/screens/expense_detail_screen.dart';
import 'package:app/features/expenses/presentation/screens/expense_list_screen.dart';
import 'package:app/features/expenses/presentation/screens/expense_stats_screen.dart';
import 'package:app/features/groups/presentation/screens/create_group_screen.dart';
import 'package:app/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:app/features/groups/presentation/screens/group_list_screen.dart';
import 'package:app/features/profile/presentation/screens/profile_screen.dart';
import 'package:app/features/settlements/presentation/screens/balance_screen.dart';
import 'package:app/features/settlements/presentation/screens/settlement_history_screen.dart';
import 'package:app/features/shell/main_shell.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ─── Custom page with iOS swipe-back support ────────────────────────────────

/// A [Page] that uses a slide-from-right + fade transition and preserves the
/// iOS interactive pop gesture (swipe from left edge to go back).
class _SlidePage<T> extends Page<T> {
  const _SlidePage({required this.child, super.key, super.name});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) =>
      _SlidePageRoute<T>(settings: this, child: child);
}

class _SlidePageRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin<T> {
  _SlidePageRoute({required super.settings, required this.child});

  final Widget child;

  @override
  Widget buildContent(BuildContext context) => child;

  @override
  bool get maintainState => true;

  @override
  String? get title => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);
}

_SlidePage<void> _slidePage(GoRouterState state, Widget child) =>
    _SlidePage<void>(key: state.pageKey, child: child);

final appRouterProvider = Provider<GoRouter>((ref) {
  // Track auth state without rebuilding the Provider on every change.
  // ValueNotifier acts as refreshListenable so GoRouter re-runs redirect.
  bool isLoggedIn = ref.read(authStateProvider).valueOrNull != null;
  bool isGuest = ref.read(authStateProvider).valueOrNull?.isGuest ?? false;
  final ticker = ValueNotifier<int>(0);

  ref.listen(authStateProvider, (prev, next) {
    final wasGuest = prev?.valueOrNull?.isGuest ?? false;
    final signedOut = next.valueOrNull == null;
    if (wasGuest && signedOut) {
      Hive.box('groups_cache').delete('guest_group_id');
    }
    isLoggedIn = next.valueOrNull != null;
    isGuest = next.valueOrNull?.isGuest ?? false;
    ticker.value++;
  });

  final router = GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: ticker,
    redirect: (context, state) {
      // ── Deep link from iOS widget ─────────────────────────────────────────
      // iOS delivers the full custom-scheme URL to go_router's route info
      // provider. Without this branch go_router throws "no routes for
      // location: com.raycat.okaerisplit://add-expense?groupId=...".
      if (state.uri.scheme == 'com.raycat.okaerisplit') {
        if (!isLoggedIn) return '/login';
        if (state.uri.host == 'add-expense') {
          final gid = state.uri.queryParameters['groupId'];
          if (gid != null && gid.isNotEmpty) {
            return '/groups/$gid/add-expense';
          }
        }
        return '/dashboard';
      }

      // ── Normal auth redirect ──────────────────────────────────────────────
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/guest-login';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      // Guests should not access the main shell (dashboard/groups list/profile)
      if (isLoggedIn && isGuest) {
        final loc = state.matchedLocation;
        final isShellRoot =
            loc == '/dashboard' || loc == '/groups' || loc == '/profile';
        if (isAuthRoute || isShellRoot) {
          // Redirect to persisted group, fall back to login
          final gid = Hive.box('groups_cache').get('guest_group_id') as String?;
          if (gid != null) return '/groups/$gid';
          return '/login';
        }
        return null;
      }
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/guest-login', builder: (_, _) => const GuestLoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/groups',
                builder: (_, _) => const GroupListScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    pageBuilder: (_, state) =>
                        _slidePage(state, const CreateGroupScreen()),
                  ),
                  GoRoute(
                    path: ':groupId',
                    pageBuilder: (_, state) => _slidePage(
                      state,
                      GroupDetailScreen(
                        groupId: state.pathParameters['groupId']!,
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'expenses',
                        pageBuilder: (_, state) => _slidePage(
                          state,
                          ExpenseListScreen(
                            groupId: state.pathParameters['groupId']!,
                          ),
                        ),
                        routes: [
                          GoRoute(
                            path: ':expenseId',
                            pageBuilder: (_, state) => _slidePage(
                              state,
                              ExpenseDetailScreen(
                                groupId: state.pathParameters['groupId']!,
                                expenseId: state.pathParameters['expenseId']!,
                              ),
                            ),
                            routes: [
                              GoRoute(
                                path: 'edit',
                                pageBuilder: (_, state) => _slidePage(
                                  state,
                                  AddExpenseScreen(
                                    groupId: state.pathParameters['groupId']!,
                                    expenseId:
                                        state.pathParameters['expenseId'],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'add-expense',
                        pageBuilder: (_, state) => _slidePage(
                          state,
                          AddExpenseScreen(
                            groupId: state.pathParameters['groupId']!,
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'balances',
                        pageBuilder: (_, state) => _slidePage(
                          state,
                          BalanceScreen(
                            groupId: state.pathParameters['groupId']!,
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'settlements',
                        pageBuilder: (_, state) => _slidePage(
                          state,
                          SettlementHistoryScreen(
                            groupId: state.pathParameters['groupId']!,
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'stats',
                        pageBuilder: (_, state) => _slidePage(
                          state,
                          ExpenseStatsScreen(
                            groupId: state.pathParameters['groupId']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ), // profile uses default builder (root tab, no slide)
        ],
      ),
    ],
  );

  // Fallback listener for warm-start deep links (app in background).
  // On warm start iOS may deliver the URL only through app_links, not through
  // go_router's routeInformationProvider, so both paths are needed.
  final sub = AppLinks().uriLinkStream.listen((uri) {
    if (uri.host == 'add-expense') {
      final gid = uri.queryParameters['groupId'];
      if (gid != null && gid.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          router.go('/groups/$gid/add-expense');
        });
      }
    }
  });

  ref.onDispose(() {
    sub.cancel();
    ticker.dispose();
    router.dispose();
  });

  return router;
});
