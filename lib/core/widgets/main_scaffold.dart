import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

// Provider global para controlar la visibilidad del menú
final userHasLeagueProvider = StateProvider<bool>((ref) => false);

class MainScaffold extends ConsumerWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  static const _allTabs = [
    (icon: Icons.home_rounded, label: 'Inicio', route: '/home'),
    (icon: Icons.sports_soccer_rounded, label: 'Mi Equipo', route: '/my-team'),
    (icon: Icons.store_rounded, label: 'Mercado', route: '/market'),
    (icon: Icons.emoji_events_rounded, label: 'Liga', route: '/league'),
  ];

  int _currentIndex(BuildContext context, List<({IconData icon, String label, String route})> tabs) {
    final location = GoRouterState.of(context).uri.toString();
    for (var i = 0; i < tabs.length; i++) {
      if (location.startsWith(tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLeague = ref.watch(userHasLeagueProvider);
    final tabs = hasLeague ? _allTabs : [_allTabs[0]];
    final currentIndex = _currentIndex(context, tabs);

    return Scaffold(
      body: child,
      // Si el usuario no tiene liga, ocultamos la NavigationBar para que
      // no pueda acceder a Mercado, Mi Equipo ni Liga.
      bottomNavigationBar: tabs.length < 2
          ? null
          : Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.bgCardLight,
                    width: 1,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: currentIndex,
                onDestinationSelected: (i) => context.go(tabs[i].route),
                destinations: tabs
                    .map(
                      (t) => NavigationDestination(
                        icon: Icon(t.icon),
                        label: t.label,
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }
}
