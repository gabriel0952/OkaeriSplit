import 'package:app/features/auth/presentation/providers/auth_provider.dart';
import 'package:app/features/auth/presentation/screens/login_screen.dart';
import 'package:app/features/auth/presentation/screens/register_screen.dart';
import 'package:app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:app/features/expenses/presentation/screens/add_expense_screen.dart';
import 'package:app/features/expenses/presentation/screens/expense_detail_screen.dart';
import 'package:app/features/expenses/presentation/screens/expense_list_screen.dart';
import 'package:app/features/groups/presentation/screens/create_group_screen.dart';
import 'package:app/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:app/features/groups/presentation/screens/group_list_screen.dart';
import 'package:app/features/profile/presentation/screens/profile_screen.dart';
import 'package:app/features/shell/main_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
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
                    builder: (_, _) => const CreateGroupScreen(),
                  ),
                  GoRoute(
                    path: ':groupId',
                    builder: (_, state) => GroupDetailScreen(
                      groupId: state.pathParameters['groupId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'expenses',
                        builder: (_, state) => ExpenseListScreen(
                          groupId: state.pathParameters['groupId']!,
                        ),
                        routes: [
                          GoRoute(
                            path: ':expenseId',
                            builder: (_, state) => ExpenseDetailScreen(
                              groupId: state.pathParameters['groupId']!,
                              expenseId: state.pathParameters['expenseId']!,
                            ),
                            routes: [
                              GoRoute(
                                path: 'edit',
                                builder: (_, state) => AddExpenseScreen(
                                  groupId: state.pathParameters['groupId']!,
                                  expenseId: state.pathParameters['expenseId'],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'add-expense',
                        builder: (_, state) => AddExpenseScreen(
                          groupId: state.pathParameters['groupId']!,
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
          ),
        ],
      ),
    ],
  );
});
