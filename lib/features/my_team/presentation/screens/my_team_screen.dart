import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/pitch_view.dart';
import '../../../../core/widgets/main_scaffold.dart';

class MyTeamScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const MyTeamScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends ConsumerState<MyTeamScreen> {
  List<Map<String, dynamic>> _titulares = [];
  List<Map<String, dynamic>> _suplentes = [];
  List<Map<String, dynamic>> _allOwnedPlayers = [];
  String _formacion = '4-4-2';
  bool _isLoading = true;
  double _presupuesto = 0;
  int _puntosTotales = 0;
  int _posicion = 0;

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final ligaId = ref.read(selectedLeagueIdProvider);
      if (ligaId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 1. Obtener datos de la membresía (presupuesto, puntos, etc)
      final membership = await Supabase.instance.client
          .from('usuarios_ligas')
          .select('presupuesto, puntos_totales, posicion')
          .eq('user_id', user.id)
          .eq('liga_id', ligaId)
          .single();

      // 2. Obtener el equipo fantasy del usuario en esta liga
      final equipo = await Supabase.instance.client
          .from('equipos_fantasy')
          .select('id, formacion')
          .eq('user_id', user.id)
          .eq('liga_id', ligaId)
          .maybeSingle();

      if (equipo == null) {
         if (mounted) {
           setState(() {
            _presupuesto = (membership['presupuesto'] as num?)?.toDouble() ?? 50000000.0;
            _puntosTotales = (membership['puntos_totales'] as num?)?.toInt() ?? 0;
            _posicion = membership['posicion'] ?? 0;
            _titulares = [];
            _suplentes = [];
            _allOwnedPlayers = [];
            _isLoading = false;
           });
         }
         return;
      }

      final equipoId = equipo['id'];
      final formacion = equipo['formacion'] ?? '4-4-2';

      final jugadoresRel = await Supabase.instance.client
          .from('equipo_fantasy_jugadores')
          .select('es_titular, orden_suplente, jugador_id, clausula, clausula_abierta_hasta, jugadores(*, equipos_reales(nombre, escudo_url), estadisticas_jugadores(puntos_calculados, created_at))')
          .eq('equipo_fantasy_id', equipoId);

      final List<Map<String, dynamic>> allOwn = [];
      final List<Map<String, dynamic>> tits = [];
      final List<Map<String, dynamic>> sups = [];

      for (var rel in jugadoresRel) {
        final j = rel['jugadores'] as Map<String, dynamic>;
        final playerData = {
          'id': j['id'],
          'name': j['nombre'],
          'initials': _getInitials(j['nombre']),
          'pos': _mapPos(j['posicion']),
          'pts': 0, 
          'es_titular': rel['es_titular'],
          'orden_suplente': rel['orden_suplente'],
          'foto_url': j['foto_url'],
          'equipo_escudo': j['equipos_reales']?['escudo_url'],
          'precio': (j['precio'] as num?)?.toDouble() ?? 0.0,
          'clausula': (rel['clausula'] as num?)?.toDouble() ?? ((j['precio'] ?? 0) * 1.25),
          'clausula_abierta_hasta': rel['clausula_abierta_hasta'],
          'puntos_totales': j['puntos'] ?? 0,
          'ultimos_puntos': (j['estadisticas_jugadores'] as List?)
                  ?.map((s) => (s['puntos_calculados'] as num).toInt())
                  .toList()
                  .reversed
                  .take(5)
                  .toList() ??
              [],
        };
        
        allOwn.add(playerData);
        if (rel['es_titular'] == true) {
          tits.add(playerData);
        } else if (rel['orden_suplente'] != null) {
          sups.add(playerData);
        }
      }

      if (mounted) {
        setState(() {
          _presupuesto = (membership['presupuesto'] as num?)?.toDouble() ?? 0;
          _puntosTotales = (membership['puntos_totales'] as num?)?.toInt() ?? 0;
          _posicion = membership['posicion'] ?? 0;
          _formacion = formacion;
          _titulares = tits;
          _suplentes = sups;
          _allOwnedPlayers = allOwn;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ERROR MyTeam: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0].substring(0, 2).toUpperCase();
  }

  String _mapPos(String pos) {
    switch (pos.toLowerCase()) {
      case 'portero': return 'PT';
      case 'defensa': return 'DF';
      case 'centrocampista': return 'CC';
      case 'delantero': return 'DL';
      default: return '??';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.bgGradient),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                TabBar(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  dividerColor: Colors.transparent,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  unselectedLabelColor: AppColors.textMuted,
                  tabs: const [
                    Tab(text: 'Alineación'),
                    Tab(text: 'Plantilla'),
                    Tab(text: 'Puntos'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // SECCIÓN 1: ALINEACIÓN
                      RefreshIndicator(
                        onRefresh: _loadTeamData,
                        color: AppColors.primary,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildTeamStats(context),
                              const SizedBox(height: 8),
                              PitchView(
                                players: _titulares, 
                                formacion: _formacion,
                                onSlotTap: (pos, p) => _handleSlotTap(pos, p, esTitular: true),
                                showPoints: false,
                              ),
                              const SizedBox(height: 16),
                              _buildFixedBench(context),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                      // SECCIÓN 2: PLANTILLA
                      _buildSquadList(),
                      // SECCIÓN 3: PUNTOS
                      RefreshIndicator(
                        onRefresh: _loadTeamData,
                        color: AppColors.primary,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              const Text('JORNADA ACTUAL', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                              const SizedBox(height: 16),
                              PitchView(
                                players: _titulares, 
                                formacion: _formacion,
                                onSlotTap: null, 
                                showPoints: true,
                              ),
                              const SizedBox(height: 16),
                              _buildFixedBench(context, showPoints: true),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go('/market'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text(
            'Gestionar',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Mi Equipo',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          PopupMenuButton<String>(
            initialValue: _formacion,
            onSelected: (String value) async {
              setState(() => _formacion = value);
              final user = Supabase.instance.client.auth.currentUser;
              if (user != null) {
                await Supabase.instance.client
                    .from('equipos_fantasy')
                    .update({'formacion': value})
                    .eq('user_id', user.id);
              }
            },
            offset: const Offset(0, 40),
            color: AppColors.bgCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            itemBuilder: (context) => [
              '5-4-1', '5-3-2', '5-2-3',
              '4-6-0', '4-5-1', '4-4-2', '4-3-3', '4-2-4',
              '3-6-1', '3-5-2', '3-4-3', '3-3-4',
            ].map((f) => PopupMenuItem(
                  value: f,
                  child: Text(f, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.grid_view_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _formacion,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamStats(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              label: 'Puntos totales',
              value: '$_puntosTotales pts',
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatChip(
              label: 'Presupuesto',
              value: '${(_presupuesto / 1000000).toStringAsFixed(1)}M',
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatChip(
              label: 'Posición',
              value: '$_posicionº',
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedBench(BuildContext context, {bool showPoints = false}) {
    final gk = _suplentes.firstWhere((p) => p['pos'] == 'PT', orElse: () => {});
    final def = _suplentes.firstWhere((p) => p['pos'] == 'DF', orElse: () => {});
    final mid = _suplentes.firstWhere((p) => p['pos'] == 'CC', orElse: () => {});
    final fwd = _suplentes.firstWhere((p) => p['pos'] == 'DL', orElse: () => {});

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, color: AppColors.textMuted, size: 16),
              const SizedBox(width: 8),
              Text(
                'SUPLENTES',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BenchSlot(pos: 'PT', player: gk.isEmpty ? null : gk, onTap: (p) => _handleSlotTap('PT', p, esTitular: false), showPoints: showPoints),
              _BenchSlot(pos: 'DF', player: def.isEmpty ? null : def, onTap: (p) => _handleSlotTap('DF', p, esTitular: false), showPoints: showPoints),
              _BenchSlot(pos: 'CC', player: mid.isEmpty ? null : mid, onTap: (p) => _handleSlotTap('CC', p, esTitular: false), showPoints: showPoints),
              _BenchSlot(pos: 'DL', player: fwd.isEmpty ? null : fwd, onTap: (p) => _handleSlotTap('DL', p, esTitular: false), showPoints: showPoints),
            ],
          ),
        ],
      ),
    );
  }

  void _handleSlotTap(String pos, Map<String, dynamic>? currentPlayer, {required bool esTitular}) {
    // Filtrar jugadores: 
    // - Si pulsamos en el 11 inicial (esTitular=true), NO mostramos otros titulares.
    // - Si pulsamos en el BANQUILLO (esTitular=false), SÍ mostramos a los titulares (para poder bajarlos al banquillo).
    // - EXCLUIMOS al jugador que ya está en este puesto concreto para no ofrecer el cambio por sí mismo.
    final clubPlayers = _allOwnedPlayers
        .where((p) => 
            p['pos'] == pos && 
            (esTitular ? p['es_titular'] != true : true) &&
            p['id'] != currentPlayer?['id']
        )
        .toList();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currentPlayer == null ? 'ELEGIR $pos' : 'CAMBIAR A ${currentPlayer['name']}',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 16),
                ),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white24)),
              ],
            ),
            const Divider(color: Colors.white10, height: 20),
            // Opción para dejar hueco libre si ya hay alguien
            if (currentPlayer != null)
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                  child: const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 18),
                ),
                title: const Text('Dejar hueco libre', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                subtitle: const Text('Quitar jugador del puesto', style: TextStyle(color: Colors.white24, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _removePlayerFromSlot(currentPlayer['id']);
                },
              ),
            if (clubPlayers.isEmpty && currentPlayer == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Text('No tienes jugadores de esta posición disponibles (que no sean ya titulares)', 
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted)),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: clubPlayers.length,
                  itemBuilder: (c, i) {
                    final p = clubPlayers[i];
                    final isSuplente = _suplentes.any((s) => s['id'] == p['id']);

                    return ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: ClipOval(
                          child: p['foto_url'] != null
                              ? Transform.scale(
                                  scale: 1.4,
                                  child: Image.network(
                                    p['foto_url'],
                                    fit: BoxFit.cover,
                                    alignment: const Alignment(0, -0.3),
                                  ),
                                )
                              : Center(child: Text(p['initials'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                        ),
                      ),
                      title: Text(p['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        isSuplente ? 'Suplente' : 'En el Club',
                        style: TextStyle(color: isSuplente ? Colors.orange : AppColors.textMuted, fontSize: 11),
                      ),
                      trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _updatePlayerStatus(p['id'], esTitular, currentPlayer?['id']);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _removePlayerFromSlot(String playerId) async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final ligaId = ref.read(selectedLeagueIdProvider);
      final equipo = await Supabase.instance.client
          .from('equipos_fantasy')
          .select('id')
          .eq('user_id', user.id)
          .eq('liga_id', ligaId!)
          .single();

      await Supabase.instance.client
          .from('equipo_fantasy_jugadores')
          .update({'es_titular': false, 'orden_suplente': null})
          .eq('equipo_fantasy_id', equipo['id'])
          .eq('jugador_id', playerId);

      await _loadTeamData();
    } catch (e) {
      debugPrint('Error al quitar jugador: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePlayerStatus(String newPlayerId, bool esTitular, String? playerOutId) async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final ligaId = ref.read(selectedLeagueIdProvider);
      final equipo = await Supabase.instance.client
          .from('equipos_fantasy')
          .select('id')
          .eq('user_id', user.id)
          .eq('liga_id', ligaId!)
          .single();

      final equipoId = equipo['id'];

      if (playerOutId != null) {
        await Supabase.instance.client
            .from('equipo_fantasy_jugadores')
            .update({'es_titular': false, 'orden_suplente': null})
            .eq('equipo_fantasy_id', equipoId)
            .eq('jugador_id', playerOutId);
      }

      if (esTitular) {
        await Supabase.instance.client
            .from('equipo_fantasy_jugadores')
            .update({'es_titular': true, 'orden_suplente': null})
            .eq('equipo_fantasy_id', equipoId)
            .eq('jugador_id', newPlayerId);
      } else {
        final p = _allOwnedPlayers.firstWhere((x) => x['id'] == newPlayerId);
        int orden = 0;
        if (p['pos'] == 'DF') orden = 1;
        if (p['pos'] == 'CC') orden = 2;
        if (p['pos'] == 'DL') orden = 3;

        await Supabase.instance.client
            .from('equipo_fantasy_jugadores')
            .update({'es_titular': false, 'orden_suplente': orden})
            .eq('equipo_fantasy_id', equipoId)
            .eq('jugador_id', newPlayerId);
      }

      await _loadTeamData();
    } catch (e) {
      debugPrint('Error al actualizar estado: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSquadList() {
    final allPlayers = [..._allOwnedPlayers];
    if (allPlayers.isEmpty) {
      return const Center(child: Text('No tienes jugadores en tu plantilla', style: TextStyle(color: Colors.white54)));
    }

    allPlayers.sort((a, b) {
      int getPriority(String pos) {
        if (pos == 'PT') return 0;
        if (pos == 'DF') return 1;
        if (pos == 'CC') return 2;
        if (pos == 'DL') return 3;
        return 4;
      }
      return getPriority(a['pos'] as String? ?? '').compareTo(getPriority(b['pos'] as String? ?? ''));
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allPlayers.length,
      itemBuilder: (context, index) {
        final p = allPlayers[index];
        final isTitular = p['es_titular'] == true;
        final isSuplente = p['orden_suplente'] != null;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                  ),
                  child: ClipOval(
                    child: p['foto_url'] != null
                        ? Transform.scale(
                            scale: 1.4,
                            child: Image.network(p['foto_url'], fit: BoxFit.cover, alignment: const Alignment(0, -0.3)),
                          )
                        : Center(child: Text(p['initials'] ?? '??', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ),
                ),
                if (isTitular || isSuplente)
                   Positioned(
                     right: 0,
                     bottom: 0,
                     child: Container(
                       padding: const EdgeInsets.all(2),
                       decoration: BoxDecoration(color: isTitular ? AppColors.primary : Colors.orange, shape: BoxShape.circle),
                       child: Icon(isTitular ? Icons.star : Icons.groups_rounded, size: 10, color: Colors.black),
                     ),
                   ),
              ],
            ),
            title: Text(p['name'] ?? 'Sin nombre', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p['pos']} • ${isTitular ? 'Titular' : (isSuplente ? 'Suplente' : 'En el Club')}', 
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                      child: Text('${p['puntos_totales']} pts', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    if (p['ultimos_puntos'] != null && (p['ultimos_puntos'] as List).isNotEmpty)
                      ...((p['ultimos_puntos'] as List).map((pts) => Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: pts >= 5 ? Colors.green : (pts > 0 ? Colors.orange : Colors.grey.withOpacity(0.3)),
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Text('$pts', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
                        ),
                      )))
                  ],
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'V. Merc.: ${((p['precio'] ?? 0) / 1000000).toStringAsFixed(1)}M',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                ),
                Text(
                  'Cláusula: ${((p['clausula'] ?? 0) / 1000000).toStringAsFixed(1)}M',
                  style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                _buildClauseCooldown(p['clausula_abierta_hasta']),
              ],
            ),
            onTap: () => context.push('/player/${p['id']}'),
          ),
        );
      },
    );
  }

  Widget _buildClauseCooldown(String? dateStr) {
    if (dateStr == null) return const SizedBox.shrink();
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    
    if (date.isAfter(now)) {
      final diff = date.difference(now);
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      
      return Text(
        days > 0 ? 'BLOQUEADA: $days d $hours h' : 'BLOQUEADA: $hours h rest.',
        style: const TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.bold),
      );
    }
    
    return const Text('CLÁUSULA ABIERTA', style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold));
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BenchSlot extends StatelessWidget {
  final String pos;
  final Map<String, dynamic>? player;
  final Function(Map<String, dynamic>? current) onTap;
  final bool showPoints;

  const _BenchSlot({
    required this.pos,
    required this.player,
    required this.onTap,
    this.showPoints = false,
  });

  Color get _color {
    if (pos == 'PT') return AppColors.goalkeeper;
    if (pos == 'DF') return AppColors.defender;
    if (pos == 'CC') return AppColors.midfielder;
    return AppColors.forward;
  }

  @override
  Widget build(BuildContext context) {
    if (player == null) {
      return GestureDetector(
        onTap: () => onTap(null),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.black12,
                shape: BoxShape.circle,
                border: Border.all(color: _color.withOpacity(0.3), width: 1.5, style: BorderStyle.solid),
              ),
              child: Icon(Icons.add, color: _color.withOpacity(0.4), size: 20),
            ),
            const SizedBox(height: 6),
            Text(pos, style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final p = player!;
    return GestureDetector(
      onTap: () => onTap(p),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _color, width: 2),
              boxShadow: [
                BoxShadow(color: _color.withOpacity(0.2), blurRadius: 6, spreadRadius: 1),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: ClipOval(
                child: p['foto_url'] != null
                    ? Transform.scale(
                        scale: 1.4,
                        child: Image.network(p['foto_url'], fit: BoxFit.cover, alignment: const Alignment(0, -0.3)),
                      )
                    : Center(child: Text(p['initials'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(4)),
            child: Text(
              p['name'],
              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (showPoints) ...[
            const SizedBox(height: 2),
            const Text('0 pts', style: TextStyle(color: AppColors.primary, fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }
}
