import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int _activeLeagueIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _fetchLeagues();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeagues() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final profileResponse = await Supabase.instance.client
          .from('usuarios')
          .select('avatar_url, username, rol')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _userProfile = profileResponse;
        });
      }

      try {
        if (_leagues.isEmpty) setState(() => _isLoading = true);
        final leaguesResponse = await Supabase.instance.client
            .from('usuarios_ligas')
            .select('*, ligas(*)')
            .eq('user_id', user.id);
            
        if (mounted) {
          setState(() {
            _leagues = leaguesResponse as List<dynamic>;
            _isLoading = false;
            
            // Sincronizar el provider con el índice activo
            if (_leagues.isNotEmpty) {
              if (_activeLeagueIndex >= _leagues.length) {
                _activeLeagueIndex = 0;
              }
              final currentId = _leagues[_activeLeagueIndex]['liga_id'];
              ref.read(selectedLeagueIdProvider.notifier).state = currentId;
              
              // Reflejar en el carrusel
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(_activeLeagueIndex);
                }
              });
            } else {
              ref.read(selectedLeagueIdProvider.notifier).state = null;
            }
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
                    await _fetchLeagues();
                  },
                  child: Stack(
                    children: [
                      _leagues.isEmpty && _isLoading
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                          : _leagues.isEmpty
                              ? _buildEmptyState(context)
                              : ListView(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              children: [
                                // CARRUSEL DE LIGAS
                                SizedBox(
                                  height: 235,
                                  child: PageView.builder(
                                    controller: _pageController,
                                    itemCount: _leagues.length,
                                    onPageChanged: (idx) {
                                      setState(() => _activeLeagueIndex = idx);
                                      ref.read(selectedLeagueIdProvider.notifier).state = _leagues[idx]['liga_id'];
                                    },
                                    itemBuilder: (context, index) {
                                      final leagueEntry = _leagues[index];
                                      final liga = leagueEntry['ligas'] as Map<String, dynamic>;
                                      final user = Supabase.instance.client.auth.currentUser;
                                      final bool isAdmin = liga['creador_id'] == user?.id;

                                      return AnimatedScale(
                                        scale: _activeLeagueIndex == index ? 1.0 : 0.95,
                                        duration: const Duration(milliseconds: 300),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: LeagueStatusCard(
                                            nombre: liga['nombre'] ?? 'Mi Liga',
                                            jornada: (liga['jornada_actual'] == null || liga['jornada_actual'] == 1) ? 27 : liga['jornada_actual'],
                                            posicion: leagueEntry['posicion'] ?? 0,
                                            puntos: (leagueEntry['puntos_totales'] as num?)?.toDouble() ?? 0.0,
                                            ultimaJornada: 0.0,
                                            isActive: _activeLeagueIndex == index,
                                            isAdmin: isAdmin,
                                            onDelete: isAdmin ? () => _confirmDeleteLeague(liga['id']) : null,
                                            onLeave: () => _confirmLeaveLeague(liga['id'], isAdmin),
                                            onInvite: () => _inviteToLeague(liga['codigo_invitacion']),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                
                                // INDICADORES DE PÁGINA
                                if (_leagues.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(_leagues.length, (index) {
                                        return AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          margin: const EdgeInsets.symmetric(horizontal: 3),
                                          height: 6,
                                          width: _activeLeagueIndex == index ? 16 : 6,
                                          decoration: BoxDecoration(
                                            color: _activeLeagueIndex == index 
                                              ? AppColors.primary 
                                              : AppColors.textMuted.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),

                                const SizedBox(height: 16),
                                
                                // PASAR CONTENIDO DINÁMICO SEGÚN LA LIGA ACTIVA
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    children: [
                                      NextMatchCard(ligaId: _leagues[_activeLeagueIndex]['liga_id']),
                                      const SizedBox(height: 16),
                                      const PointsSummaryCard(),
                                      const SizedBox(height: 16),
                                      _buildQuickActions(context),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                      if (_isLoading && _leagues.isNotEmpty)
                        Positioned(
                          top: 8, left: 16, right: 16,
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            color: AppColors.primary.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
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
    final bool isAdmin = _userProfile?['rol'] == 'admin';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isAdmin ? Icons.admin_panel_settings_outlined : Icons.sports_soccer_outlined, 
            size: 80, 
            color: isAdmin ? AppColors.primary.withOpacity(0.5) : AppColors.textMuted.withOpacity(0.5)
          ),
          const SizedBox(height: 24),
          Text(
            isAdmin ? 'MODO ADMINISTRADOR' : '¡Bienvenido al césped!',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            isAdmin 
              ? 'Has accedido como Superadmin. Desde aquí puedes gestionar todas las ligas del sistema y los puntos de los jugadores.'
              : 'Actualmente no estás participando en ninguna liga. Crea una liga nueva y sé el administrador, o únete a una existente con un código de invitación.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (isAdmin)
             AppButton(
               label: 'IR AL PANEL DE CONTROL',
               onPressed: () => context.push('/admin'),
             )
          else
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
              _fetchLeagues(); 
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
        const Text(
          'Acciones rápidas',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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

  void _confirmLeaveLeague(String ligaId, bool isAdmin) async {
    if (!isAdmin) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('¿Abandonar liga?'),
          content: const Text('Dejarás de participar en esta liga. Tu equipo y puntos se perderán.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _leaveLeague(ligaId);
              },
              child: const Text('ABANDONAR', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      return;
    }

    // LÓGICA PARA ADMIN: Debe elegir sucesor
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final membersResponse = await Supabase.instance.client
          .from('usuarios_ligas')
          .select('user_id, usuarios(username)')
          .eq('liga_id', ligaId)
          .neq('user_id', user?.id ?? '');
      
      setState(() => _isLoading = false);
      final List<dynamic> otherMembers = membersResponse as List<dynamic>;

      if (otherMembers.isEmpty) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.bgCard,
            title: const Text('¿Abandonar liga?'),
            content: const Text('Eres el único miembro. Al salir, la liga quedará sin administrador. Se recomienda eliminarla si no habrá más jugadores.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _leaveLeague(ligaId);
                },
                child: const Text('ABANDONAR', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
        return;
      }

      // Mostrar selector de sucesor
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('Elegir nuevo Administrador'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Como administrador, debes designar a un sucesor antes de marcharte:'),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: otherMembers.length,
                    itemBuilder: (ctx, i) {
                      final member = otherMembers[i];
                      final userData = member['usuarios'] as Map<String, dynamic>;
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.black)),
                        title: Text(userData['username'] ?? 'Usuario', style: const TextStyle(color: Colors.white)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _transferAdminAndLeave(ligaId, member['user_id']);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar miembros: $e')));
      }
    }
  }

  Future<void> _transferAdminAndLeave(String ligaId, String newAdminId) async {
    setState(() => _isLoading = true);
    try {
      // 1. Transferir el mando via RPC (evita errores de RLS)
      await Supabase.instance.client.rpc('transferir_admin', params: {
        'p_liga_id': ligaId,
        'p_nuevo_admin_id': newAdminId,
      });
      // 2. Abandonar
      await _leaveLeague(ligaId);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al transferir: $e')));
      }
    }
  }

  void _inviteToLeague(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Invitar a la liga'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Comparte este código con tus amigos para que se unan:'),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('¡Código copiado al portapapeles!'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26, 
                  borderRadius: BorderRadius.circular(12), 
                  border: Border.all(color: AppColors.primary),
                ),
                child: Text(
                  code, 
                  style: const TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold, 
                    color: AppColors.primary, 
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pulsa sobre el código para copiar',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
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

  Future<void> _leaveLeague(String ligaId) async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.from('usuarios_ligas').delete().eq('user_id', user.id).eq('liga_id', ligaId);
        await _fetchLeagues();
      }
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
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
