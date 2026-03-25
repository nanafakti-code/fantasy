import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/my_team/presentation/screens/my_team_screen.dart';
import '../../features/market/presentation/screens/market_screen.dart';
import '../../features/league/presentation/screens/league_screen.dart';
import '../../features/league/presentation/screens/create_league_screen.dart';
import '../../features/league/presentation/screens/join_league_screen.dart';
import '../../features/league/presentation/screens/user_team_screen.dart';
import '../../features/player_detail/presentation/screens/player_detail_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/account_settings_screen.dart';
import '../../features/activity/presentation/screens/activity_screen.dart';
import '../widgets/main_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/my-team',
            name: 'my-team',
            builder: (context, state) {
              final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
              return MyTeamScreen(initialTab: tab);
            },
          ),
          GoRoute(
            path: '/market',
            name: 'market',
            builder: (context, state) => const MarketScreen(),
          ),
          GoRoute(
            path: '/activity',
            name: 'activity',
            builder: (context, state) => const ActivityScreen(),
          ),
          GoRoute(
            path: '/league',
            name: 'league',
            builder: (context, state) => const LeagueScreen(),
            routes: [
              GoRoute(
                path: 'create',
                name: 'create-league',
                builder: (context, state) => const CreateLeagueScreen(),
              ),
              GoRoute(
                path: 'join',
                name: 'join-league',
                builder: (context, state) {
                  final code = state.uri.queryParameters['code'];
                  return JoinLeagueScreen(codigo: code);
                },
              ),
              GoRoute(
                path: 'user-team',
                name: 'user-team',
                builder: (context, state) {
                  final userId = state.uri.queryParameters['userId']!;
                  final username = state.uri.queryParameters['username']!;
                  return UserTeamScreen(userId: userId, username: username);
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/join/:code',
        name: 'join-via-link',
        builder: (context, state) {
          final code = state.pathParameters['code'];
          return JoinLeagueScreen(codigo: code);
        },
      ),
      GoRoute(
        path: '/player/:id',
        name: 'player-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PlayerDetailScreen(jugadorId: id);
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: 'settings',
            name: 'account-settings',
            builder: (context, state) => const AccountSettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
