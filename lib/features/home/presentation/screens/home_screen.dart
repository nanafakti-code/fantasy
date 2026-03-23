import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/main_scaffold.dart';
import '../widgets/league_status_card.dart';
import '../widgets/next_match_card.dart';
import '../widgets/points_summary_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;
  List<dynamic> _leagues = [];
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _fetchLeagues();
  }

  Future<void> _fetchLeagues() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final profileResponse = await Supabase.instance.client
          .from('usuarios')
          .select('avatar_url, username')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _userProfile = profileResponse;
        });
      }

      try {
        final leaguesResponse = await Supabase.instance.client
            .from('usuarios_ligas')
            .select('*, ligas(*)')
            .eq('user_id', user.id);
            
        if (mounted) {
          setState(() {
            _leagues = leaguesResponse;
            _isLoading = false;
          });
          ref.read(userHasLeagueProvider.notifier).state = _leagues.isNotEmpty;
        }
      } catch (err) {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.bgCard,
                  onRefresh: () async {
                    await Future.delayed(const Duration(seconds: 1));
                  },
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : _leagues.isEmpty
                          ? _buildEmptyState(context)
                          : ListView(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              children: [
                                Builder(
                                  builder: (context) {
                                    final leagueEntry = _leagues.first;
                                    final liga = leagueEntry['ligas'] as Map<String, dynamic>;
                                    final user = Supabase.instance.client.auth.currentUser;
                                    final bool isAdmin = liga['creador_id'] == user?.id;
                                    
                                    return LeagueStatusCard(
                                      nombre: liga['nombre'] ?? 'Mi Liga',
                                      jornada: liga['jornada_actual'] ?? 1,
                                      posicion: leagueEntry['posicion'] ?? 0,
                                      puntos: (leagueEntry['puntos_totales'] as num?)?.toDouble() ?? 0.0,
                                      ultimaJornada: 0.0,
                                      onSettingsTap: isAdmin ? () => _confirmDeleteLeague(liga['id']) : null,
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                const NextMatchCard(),
                                const SizedBox(height: 16),
                                const PointsSummaryCard(),
                                const SizedBox(height: 16),
                                _buildQuickActions(context),
                                const SizedBox(height: 24),
                              ],
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLeagueOptions(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Liga',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_soccer_outlined, size: 80, color: AppColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text(
            '¡Bienvenido al césped!',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Actualmente no estás participando en ninguna liga. Crea una liga nueva y sé el administrador, o únete a una existente con un código de invitación.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          AppButton(
            label: 'Crear o unirme a una liga',
            onPressed: () => _showLeagueOptions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Hola, ${_userProfile?['username'] ?? 'Míster'}! 👋',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  'Fantasy Andalucía',
                  style:
                      Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                ),
              ],
            ),
          ),
          NotificationBadge(
            count: 2,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () async {
              await context.push('/profile');
              _fetchLeagues(); // Recargar foto al volver
            },
            child: Hero(
              tag: 'profile_avatar',
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    image: _userProfile?['avatar_url'] != null
                        ? DecorationImage(
                            image: NetworkImage(_userProfile!['avatar_url']),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _userProfile?['avatar_url'] == null
                      ? Center(
                          child: Text(
                            ((_userProfile?['username'] ?? 'US').toString().length >= 2 
                                ? (_userProfile?['username'] ?? 'US').toString().substring(0, 2) 
                                : (_userProfile?['username'] ?? 'US').toString()
                            ).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acciones rápidas',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.sports_soccer_rounded,
                label: 'Mi Equipo',
                color: AppColors.primary,
                onTap: () => context.go('/my-team'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.store_rounded,
                label: 'Mercado',
                color: AppColors.info,
                onTap: () => context.go('/market'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.emoji_events_rounded,
                label: 'Liga',
                color: AppColors.accent,
                onTap: () => context.go('/league'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showLeagueOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text('Unirse o crear liga',
                style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: 24),
            AppButton(
              label: 'Crear nueva liga',
              icon: const Icon(Icons.add_rounded, color: Colors.black),
              onPressed: () async {
                Navigator.pop(ctx);
                await context.push('/league/create');
                _fetchLeagues();
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await context.push('/league/join');
                _fetchLeagues();
              },
              icon: const Icon(Icons.link_rounded),
              label: const Text('Unirme con código'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteLeague(String ligaId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('¿Eliminar liga?'),
        content: const Text('Esta acción es irreversible y se borrarán todos los equipos de los participantes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteLeague(ligaId);
            },
            child: const Text('ELIMINAR', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLeague(String ligaId) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.rpc('eliminar_liga_completa', params: {'p_liga_id': ligaId});
      await _fetchLeagues();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
