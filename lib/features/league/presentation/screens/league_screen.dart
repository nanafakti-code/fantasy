import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/main_scaffold.dart';

class LeagueScreen extends ConsumerStatefulWidget {
  const LeagueScreen({super.key});

  @override
  ConsumerState<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends ConsumerState<LeagueScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _liga;
  List<dynamic> _miembros = [];

  @override
  void initState() {
    super.initState();
    _loadLeague();
  }

  Future<void> _loadLeague() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Leer la liga seleccionada del provider global
      String? ligaId = ref.read(selectedLeagueIdProvider);

      // Si no hay liga seleccionada aún, buscamos la primera del usuario
      if (ligaId == null) {
        final membership = await Supabase.instance.client
            .from('usuarios_ligas')
            .select('liga_id')
            .eq('user_id', user.id)
            .maybeSingle(); // Esto fallará si tiene varias, pero cargará el home antes
            
        if (membership == null) {
          if (mounted) setState(() { _liga = null; _isLoading = false; });
          return;
        }
        ligaId = membership['liga_id'];
      }

      // Cargar DATOS DE LA LIGA
      final ligaData = await Supabase.instance.client
          .from('ligas')
          .select('*')
          .eq('id', ligaId!)
          .single();

      // Cargar MIEMBROS de esta liga
      final miembros = await Supabase.instance.client
          .from('usuarios_ligas')
          .select('user_id, puntos_totales, posicion, usuarios(username, avatar_url)')
          .eq('liga_id', ligaId!)
          .order('puntos_totales', ascending: false);

      if (mounted) {
        setState(() {
          _liga = ligaData;
          _miembros = miembros;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios en la liga seleccionada para recargar si el usuario swipéo en el Home
    ref.listen(selectedLeagueIdProvider, (previous, next) {
      if (next != previous && next != null) {
        _loadLeague();
      }
    });

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: _liga == null ? _buildEmptyState(context) : _buildLeagueContent(context),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_outlined, size: 72, color: AppColors.textMuted),
            const SizedBox(height: 24),
            Text('Sin liga activa', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(
              'No perteneces a ninguna liga todavía. Crea una nueva o únete con un código.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            AppButton(
              label: 'Crear liga',
              icon: const Icon(Icons.add_rounded, color: Colors.black),
              onPressed: () async {
                await context.push('/league/create');
                _loadLeague();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeagueContent(BuildContext context) {
    final liga = _liga!;
    final codigo = liga['codigo_invitacion'] as String? ?? '--------';
    final nombre = liga['nombre'] as String? ?? 'Mi Liga';
    final maxP = liga['max_participantes'] as int? ?? 20;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Clasificación', style: Theme.of(context).textTheme.headlineLarge),
                    Text(
                      '$nombre · ${_miembros.length}/$maxP participantes',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (liga['creador_id'] == currentUserId) ...[
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary, size: 22),
                  onPressed: _showAdminSettings,
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: codigo));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, color: Colors.black, size: 14),
                          ),
                          const SizedBox(width: 10),
                          Text('Código $codigo copiado', style: const TextStyle(color: AppColors.textPrimary)),
                        ],
                      ),
                      backgroundColor: AppColors.bgCardLight,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        codigo,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(width: 36, child: Text('#', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center)),
              const Expanded(flex: 3, child: Text('')),
              Expanded(child: Text('Pts', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadLeague,
            child: _miembros.isEmpty
                ? const Center(child: Text('Aún no hay más participantes', style: TextStyle(color: AppColors.textMuted)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _miembros.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      final m = _miembros[i];
                      final user = m['usuarios'] as Map<String, dynamic>?;
                      final username = user?['username'] as String? ?? 'Jugador';
                      final pts = (m['puntos_totales'] as num?)?.toInt() ?? 0;
                      final avatarUrl = user?['avatar_url'] as String?;
                      final initials = username.length >= 2 ? username.substring(0, 2).toUpperCase() : username.toUpperCase();
                      final isMe = currentUserId == m['user_id'];
                      final bool isAdminOfLeague = liga['creador_id'] == currentUserId;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.primary.withOpacity(0.1) : AppColors.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isMe ? AppColors.primary : const Color(0xFF1E293B),
                            width: isMe ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: i == 0 ? const Color(0xFFFFD700) : i == 1 ? const Color(0xFFC0C0C0) : i == 2 ? const Color(0xFFCD7F32) : AppColors.textMuted,
                                  fontSize: i < 3 ? 18 : 15,
                                  fontWeight: FontWeight.w800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.bgCardLight,
                                image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                              ),
                              child: avatarUrl == null
                                  ? Center(child: Text(initials, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)))
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: Text(
                                username + (isMe ? ' (tú)' : ''),
                                style: Theme.of(context).textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$pts pts',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.right,
                            ),
                            if (isAdminOfLeague && !isMe) ...[
                              const SizedBox(width: 12),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.person_remove_outlined, color: AppColors.error, size: 18),
                                onPressed: () => _confirmKickUser(m['user_id'] as String, username),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  void _showAdminSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ajustes de Administrador', style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
              title: const Text('Eliminar Liga', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
              subtitle: const Text('Se borrarán todos los datos permanentemente'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteLeague();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteLeague() {
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
              await _deleteLeague();
            },
            child: const Text('ELIMINAR', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLeague() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.rpc('eliminar_liga_completa', params: {'p_liga_id': _liga!['id']});
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _confirmKickUser(String userId, String username) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('¿Expulsar usuario?'),
        content: Text('¿Estás seguro de que quieres expulsar a $username de la liga?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _kickUser(userId);
            },
            child: const Text('EXPULSAR', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _kickUser(String userId) async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('usuarios_ligas').delete().eq('liga_id', _liga!['id']).eq('user_id', userId);
      await _loadLeague();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
