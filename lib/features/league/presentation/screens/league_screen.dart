import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
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
  List<Map<String, dynamic>> _miembros = [];
  List<Map<String, dynamic>> _jornadas = [];
  String? _selectedJornadaId; // null = General

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

      final ligaId = ref.read(selectedLeagueIdProvider);
      if (ligaId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 1. Cargar info de la LIGA
      final ligaData = await Supabase.instance.client
          .from('ligas')
          .select('*, creador_id')
          .eq('id', ligaId)
          .single();

      // 2. Cargar JORNADAS de esa división
      final jornadasData = await Supabase.instance.client
          .from('jornadas')
          .select('id, numero')
          .eq('division', ligaData['division'])
          .order('numero', ascending: true);

      // 3. Cargar MIEMBROS según la selección (General o Jornada)
      List<Map<String, dynamic>> members = [];
      
      if (_selectedJornadaId == null) {
        // CLASIFICACIÓN GENERAL
        members = await Supabase.instance.client
            .from('usuarios_ligas')
            .select('user_id, puntos_totales, posicion, valor_equipo, usuarios(username, avatar_url)')
            .eq('liga_id', ligaId)
            .order('puntos_totales', ascending: false)
            .order('valor_equipo', ascending: false);
      } else {
        // CLASIFICACIÓN POR JORNADA
        final puntosJornada = await Supabase.instance.client
            .from('puntos_jornada')
            .select('user_id, puntos, usuarios(username, avatar_url)')
            .eq('liga_id', ligaId)
            .eq('jornada_id', _selectedJornadaId!)
            .order('puntos', ascending: false);

        // Mapear al formato esperado, incluyendo el valor_equipo (que sigue siendo útil ver)
        // Necesitamos valor_equipo de usuarios_ligas para cada usuario
        final membersExtra = await Supabase.instance.client
            .from('usuarios_ligas')
            .select('user_id, valor_equipo')
            .eq('liga_id', ligaId);
        
        final valorMap = { for (var m in membersExtra) m['user_id']: m['valor_equipo'] };

        members = puntosJornada.map((pj) => {
          'user_id': pj['user_id'],
          'puntos_totales': pj['puntos'],
          'usuarios': pj['usuarios'],
          'valor_equipo': valorMap[pj['user_id']] ?? 0,
          'posicion': (puntosJornada.indexOf(pj) + 1),
        }).toList();
      }

      if (mounted) {
        setState(() {
          _liga = ligaData;
          _miembros = members;
          _jornadas = jornadasData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading league: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedLeagueIdProvider, (previous, next) {
      if (next != previous && next != null) {
        _selectedJornadaId = null;
        _loadLeague();
      }
    });

    final currentSelectedId = ref.watch(selectedLeagueIdProvider);
    if (currentSelectedId != null && _liga != null && _liga!['id'] != currentSelectedId && !_isLoading) {
      Future.microtask(() {
        _selectedJornadaId = null;
        _loadLeague();
      });
    }

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
        // CABECERA
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
                      margin: const EdgeInsets.all(16),
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
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Text(codigo, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // SELECTOR DE JORNADA
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildJornadaChip(null, 'General'),
              ..._jornadas.map((j) => _buildJornadaChip(j['id'], 'J.${j['numero']}')),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // LISTA DE CLASIFICACIÓN
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadLeague,
            color: AppColors.primary,
            child: _miembros.isEmpty
                ? const Center(child: Text('Aún no hay puntos registrados', style: TextStyle(color: AppColors.textMuted)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    itemCount: _miembros.length,
                    itemBuilder: (context, index) {
                      final m = _miembros[index];
                      final isMe = m['user_id'] == currentUserId;
                      final username = (m['usuarios']?['username'] as String?) ?? 'Usuario';
                      final avatarUrl = m['usuarios']?['avatar_url'] as String?;
                      final pts = (m['puntos_totales'] as num?)?.toInt() ?? 0;
                      final pos = m['posicion'] ?? (index + 1);
                      final valor = (m['valor_equipo'] as num?)?.toDouble() ?? 0.0;
                      final isAdminOfLeague = liga['creador_id'] == currentUserId;
                      return GestureDetector(
                        onTap: () {
                          if (isMe) {
                            context.push('/my-team?tab=1');
                          } else {
                            context.push(
                              '/league/user-team?userId=${m['user_id']}&username=${Uri.encodeComponent(username)}',
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isMe ? AppColors.primary.withOpacity(0.05) : AppColors.bgCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isMe ? AppColors.primary.withOpacity(0.5) : Colors.white.withOpacity(0.05),
                              width: isMe ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 30,
                                child: Text(
                                  '#$pos',
                                  style: TextStyle(
                                    color: pos <= 3 ? AppColors.primary : AppColors.textMuted,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.bgDark,
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null ? const Icon(Icons.person_rounded, size: 20, color: Colors.white24) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      username + (isMe ? ' (tú)' : ''),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Valor: ${(valor / 1000000).toStringAsFixed(1)}M',
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '$pts pts',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
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
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildJornadaChip(String? id, String label) {
    final isSelected = _selectedJornadaId == id;
    return GestureDetector(
      onTap: () {
        if (isSelected) return;
        setState(() {
          _selectedJornadaId = id;
          _loadLeague();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
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
        title: Text('¿Expulsar a $username?'),
        content: const Text('El usuario perderá todo su equipo y progreso en esta liga.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _kickUser(userId);
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
      await Supabase.instance.client
          .from('usuarios_ligas')
          .delete()
          .eq('user_id', userId)
          .eq('liga_id', _liga!['id']);
      
      await _loadLeague();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al expulsar: $e')));
      }
    }
  }
}
