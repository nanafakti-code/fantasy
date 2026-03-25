import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';

class AdminMatchPointsScreen extends StatefulWidget {
  final Map<String, dynamic> match;
  const AdminMatchPointsScreen({super.key, required this.match});

  @override
  State<AdminMatchPointsScreen> createState() => _AdminMatchPointsScreenState();
}

class _AdminMatchPointsScreenState extends State<AdminMatchPointsScreen> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  late TabController _tabController;
  final _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _localPlayers = [];
  List<Map<String, dynamic>> _visitPlayers = [];
  Map<String, Map<String, dynamic>> _playerStats = {}; // player_id -> stats_data

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMatchData();
  }

  Future<void> _loadMatchData() async {
    try {
      final localId = widget.match['equipo_local_id'];
      final visitId = widget.match['equipo_visit_id'];
      final matchId = widget.match['id'];

      // 1. Fetch Players
      final localRes = await supabase.from('jugadores').select('*').eq('equipo_id', localId).order('posicion', ascending: true);
      final visitRes = await supabase.from('jugadores').select('*').eq('equipo_id', visitId).order('posicion', ascending: true);

      // 2. Fetch Existing Stats
      final statsRes = await supabase.from('estadisticas_jugadores').select('*').eq('partido_id', matchId);
      final List statsList = statsRes as List;
      
      final Map<String, Map<String, dynamic>> statsMap = {};
      for (var s in statsList) {
        statsMap[s['jugador_id'].toString()] = Map<String, dynamic>.from(s);
      }

      if (mounted) {
        setState(() {
          _localPlayers = List<Map<String, dynamic>>.from(localRes);
          _visitPlayers = List<Map<String, dynamic>>.from(visitRes);
          _playerStats = statsMap;
          
          // Pre-populate missing stats with defaults
          _initializeStats([..._localPlayers, ..._visitPlayers]);
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading match data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initializeStats(List<Map<String, dynamic>> allPlayers) {
    final localId = widget.match['equipo_local_id'];
    for (var p in allPlayers) {
      final id = p['id'].toString();
      if (!_playerStats.containsKey(id)) {
        // Default initial stat
        _playerStats[id] = {
          'jugador_id': p['id'],
          'partido_id': widget.match['id'],
          'convocado': false,
          'titular': false,
          'goles': 0,
          'goles_propia': 0,
          'tarjetas_amarillas': 0,
          'tarjetas_rojas': 0,
          'porteria_cero': false,
          'goles_recibidos': 0,
          'asistencias': 0,
        };
      }
      
      // Auto-logic for clean sheet and goals received (only if they played)
      final isLocal = p['equipo_id'] == localId;
      final stats = _playerStats[id]!;
      
      // We only auto-set if the stats are new or if we want to force refresh
      // For now, let's keep it as a helper that runs when "convocado" is checked
      if (stats['convocado'] == true) {
        _applyTeamResults(id, isLocal);
      }
    }
  }

  void _applyTeamResults(String playerId, bool isLocal) {
    final stats = _playerStats[playerId]!;
    final localGoals = widget.match['goles_local'] ?? 0;
    final visitGoals = widget.match['goles_visitante'] ?? 0;
    
    if (isLocal) {
      stats['goles_recibidos'] = visitGoals;
      stats['porteria_cero'] = visitGoals == 0;
    } else {
      stats['goles_recibidos'] = localGoals;
      stats['porteria_cero'] = localGoals == 0;
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isLoading = true);
    try {
      // 1. Update Match Header (Score and Status)
      await supabase
          .from('partidos')
          .update({
            'goles_local': widget.match['goles_local'],
            'goles_visitante': widget.match['goles_visitante'],
            'estado': widget.match['estado'],
          })
          .eq('id', widget.match['id']);

      // 2. Update Player Stats
      final List<Map<String, dynamic>> toInsert = [];
      final List<Map<String, dynamic>> toUpdate = [];
      
      for (var s in _playerStats.values) {
        if (s['convocado'] == true) {
          int mins = s['titular'] == true ? 90 : 45;
          s['minutos_jugados'] = mins;
          
          final data = Map<String, dynamic>.from(s);
          // Remove all null values to avoid sparse matrix filling nulls in PostgREST
          data.removeWhere((key, value) => value == null);
          
          if (s['id'] == null) {
            toInsert.add(data);
          } else {
            toUpdate.add(data);
          }
        } else {
          if (s['id'] != null) {
            await supabase.from('estadisticas_jugadores').delete().eq('id', s['id']);
          }
        }
      }

      if (toInsert.isNotEmpty) {
        await supabase.from('estadisticas_jugadores').upsert(toInsert, onConflict: 'jugador_id,partido_id');
      }
      if (toUpdate.isNotEmpty) {
        await supabase.from('estadisticas_jugadores').upsert(toUpdate, onConflict: 'jugador_id,partido_id');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Partido y estadísticas guardados con éxito')));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Gestión del Partido'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveAll,
            child: const Text('GUARDAR TODO', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                _buildMatchHeader(),
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.white60,
                  tabs: [
                    Tab(text: widget.match['equipo_local']['nombre']),
                    Tab(text: widget.match['equipo_visit']['nombre']),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Buscar jugador...',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.white24, size: 20),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPlayerList(_localPlayers, true),
                      _buildPlayerList(_visitPlayers, false),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMatchHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTeamHeader(widget.match['equipo_local']),
              Column(
                children: [
                  Row(
                    children: [
                      _MatchCounter(
                        value: widget.match['goles_local'] ?? 0, 
                        onChanged: (v) => setState(() {
                          widget.match['goles_local'] = v;
                          _initializeStats([..._localPlayers, ..._visitPlayers]);
                        })
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('-', style: TextStyle(color: Colors.white54, fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      _MatchCounter(
                        value: widget.match['goles_visitante'] ?? 0, 
                        onChanged: (v) => setState(() {
                          widget.match['goles_visitante'] = v;
                          _initializeStats([..._localPlayers, ..._visitPlayers]);
                        })
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Goles', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              _buildTeamHeader(widget.match['equipo_visit']),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatusDropdown(),
        ],
      ),
    );
  }

  Widget _buildTeamHeader(dynamic team) {
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          if (team['escudo_url'] != null)
            Container(
              height: 40,
              padding: const EdgeInsets.all(4),
              child: Image.network(
                team['escudo_url'], 
                fit: BoxFit.contain, 
                errorBuilder: (c,e,s) => const Icon(Icons.shield, color: Colors.white10),
              ),
            ),
          const SizedBox(height: 6),
          Text(team['nombre'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: widget.match['estado'],
          dropdownColor: AppColors.bgCard,
          items: const [
            DropdownMenuItem(value: 'programado', child: Text('PROGRAMADO', style: TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 'en_curso', child: Text('EN CURSO', style: TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 'finalizado', child: Text('FINALIZADO', style: TextStyle(fontSize: 12))),
          ],
          onChanged: (v) => setState(() => widget.match['estado'] = v!),
          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  int _getAssignedRegularGoals(bool isLocal) {
    final players = isLocal ? _localPlayers : _visitPlayers;
    int total = 0;
    for (var p in players) {
      final id = p['id'].toString();
      total += (_playerStats[id]?['goles'] ?? 0) as int;
    }
    return total;
  }

  int _getAssignedOwnGoals(bool isLocal) {
    final players = isLocal ? _localPlayers : _visitPlayers;
    int total = 0;
    for (var p in players) {
      final id = p['id'].toString();
      total += (_playerStats[id]?['goles_propia'] ?? 0) as int;
    }
    return total;
  }

  Widget _buildPlayerList(List<Map<String, dynamic>> players, bool isLocal) {
    final query = _searchController.text.toLowerCase();
    
    // Total goals for THIS team = Regular goals from THIS team + Own goals from OPPONENT
    final matchScoreThisTeam = (isLocal ? widget.match['goles_local'] : widget.match['goles_visitante']) ?? 0;
    final assignedRegularThisTeam = _getAssignedRegularGoals(isLocal);
    final assignedOwnOpponent = _getAssignedOwnGoals(!isLocal);
    
    // Total goals for OPPONENT = Regular goals from OPPONENT + Own goals from THIS team
    final matchScoreOpponent = (!isLocal ? widget.match['goles_local'] : widget.match['goles_visitante']) ?? 0;
    final assignedRegularOpponent = _getAssignedRegularGoals(!isLocal);
    final assignedOwnThisTeam = _getAssignedOwnGoals(isLocal);

    final canAddRegular = (assignedRegularThisTeam + assignedOwnOpponent) < matchScoreThisTeam;
    final canAddOwn = (assignedRegularOpponent + assignedOwnThisTeam) < matchScoreOpponent;
    
    final filtered = players.where((p) {
      final name = '${p['nombre']} ${p['apellidos'] ?? ''}'.toLowerCase();
      return name.contains(query);
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final p = filtered[index];
        final id = p['id'].toString();
        final stats = _playerStats[id]!;
        
        return _PlayerEventTile(
          player: p,
          stats: stats,
          canAddGoal: canAddRegular,
          canAddOwnGoal: canAddOwn,
          showOwnGoal: matchScoreOpponent > 0, // Request: hide if opponent has 0 goals
          onChanged: () {
            setState(() {
              if (stats['convocado'] == true) {
                _applyTeamResults(id, isLocal);
              }
            });
          },
        );
      },
    );
  }
}

class _PlayerEventTile extends StatelessWidget {
  final Map<String, dynamic> player;
  final Map<String, dynamic> stats;
  final bool canAddGoal;
  final bool canAddOwnGoal;
  final bool showOwnGoal;
  final VoidCallback onChanged;

  const _PlayerEventTile({
    required this.player, 
    required this.stats, 
    required this.canAddGoal, 
    required this.canAddOwnGoal,
    required this.showOwnGoal,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isPlayed = stats['convocado'] == true;
    final pos = player['posicion'] ?? '';
    final shortPos = pos == 'portero' ? 'PT' : pos == 'defensa' ? 'DF' : pos == 'centrocampista' ? 'CC' : 'DL';
    
    // Position colors matching rest of app
    Color posColor;
    if (pos == 'portero') posColor = AppColors.goalkeeper;
    else if (pos == 'defensa') posColor = AppColors.defender;
    else if (pos == 'centrocampista') posColor = AppColors.midfielder;
    else posColor = AppColors.forward;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPlayed ? AppColors.primary.withOpacity(0.05) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPlayed ? AppColors.primary.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: posColor.withOpacity(0.1),
                  border: Border.all(color: posColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: posColor.withOpacity(0.15), blurRadius: 8, spreadRadius: 0),
                  ],
                ),
                child: (player['foto_url'] != null && (player['foto_url'] as String).isNotEmpty) 
                    ? ClipOval(
                        child: Transform.scale(
                          scale: 1.3,
                          alignment: const Alignment(0, -0.2),
                          child: Image.network(
                            player['foto_url'],
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          player['nombre'][0], 
                          style: TextStyle(color: posColor, fontWeight: FontWeight.bold, fontSize: 16)
                        ),
                      ),
              ),
              // Team Shield Overlay
              if (player['escudo_url'] != null || player['team_escudo_url'] != null)
                Positioned(
                  right: 0,
                  bottom: 2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.bgCardLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                      boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Image.network(
                        player['escudo_url'] ?? player['team_escudo_url'],
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              if (isPlayed)
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: 12, height: 12, 
                    decoration: BoxDecoration(
                      color: AppColors.primary, 
                      shape: BoxShape.circle, 
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text('${player['nombre']} ${player['apellidos'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
            if (stats['goles'] > 0)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: List.generate(stats['goles'], (i) => const Icon(Icons.sports_soccer_rounded, color: AppColors.primary, size: 14)),
                ),
              ),
            if (stats['tarjetas_amarillas'] > 0)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.rectangle_rounded, color: Colors.yellow, size: 14),
              ),
            if (stats['tarjetas_rojas'] > 0)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.rectangle_rounded, color: Colors.red, size: 14),
              ),
          ],
        ),
        subtitle: Text('$shortPos • ${stats['titular'] == true ? 'Titular' : (isPlayed ? 'Suplente' : 'No jugó')}', style: TextStyle(color: isPlayed ? AppColors.primary : Colors.white38, fontSize: 10)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                const Divider(color: Colors.white10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _EventChip(
                          label: 'JUGÓ', 
                          icon: Icons.check_circle_outline, 
                          active: stats['convocado'], 
                          onTap: () {
                            stats['convocado'] = !stats['convocado'];
                            if (!stats['convocado']) stats['titular'] = false;
                            onChanged();
                          }
                        ),
                        const SizedBox(width: 8),
                        _EventChip(
                          label: 'TITULAR', 
                          icon: Icons.flash_on_rounded, 
                          active: stats['titular'], 
                          onTap: stats['convocado'] ? () {
                            stats['titular'] = !stats['titular'];
                            onChanged();
                          } : null
                        ),
                      ],
                    ),
                    if (stats['porteria_cero'] == true)
                      const Row(
                        children: [
                          Icon(Icons.shield_rounded, color: AppColors.primary, size: 14),
                          SizedBox(width: 4),
                          Text('PORTR. 0', style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (canAddGoal || (showOwnGoal && (canAddOwnGoal || stats['goles_propia'] > 0)) || stats['goles'] > 0)
                  Row(
                    children: [
                      if (canAddGoal || stats['goles'] > 0)
                        Expanded(child: _StatControl(label: 'Goles', value: stats['goles'], icon: Icons.sports_soccer_rounded, canAdd: canAddGoal, onUpdate: (v) { stats['goles'] = v; onChanged(); })),
                      if ((canAddGoal || stats['goles'] > 0) && (showOwnGoal && (canAddOwnGoal || stats['goles_propia'] > 0)))
                        const SizedBox(width: 16),
                      if (showOwnGoal && (canAddOwnGoal || stats['goles_propia'] > 0))
                        Expanded(child: _StatControl(label: 'P.Propia', value: stats['goles_propia'], icon: Icons.error_outline_rounded, canAdd: canAddOwnGoal, onUpdate: (v) { stats['goles_propia'] = v; onChanged(); })),
                      if (canAddGoal || stats['goles'] > 0)
                        if (!showOwnGoal || (!canAddOwnGoal && stats['goles_propia'] == 0))
                          const Expanded(child: SizedBox()),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CardToggle(
                      label: 'Yel', 
                      color: Colors.yellow, 
                      active: stats['tarjetas_amarillas'] == 1, 
                      onTap: () {
                        stats['tarjetas_amarillas'] = stats['tarjetas_amarillas'] == 1 ? 0 : 1;
                        onChanged();
                      }
                    ),
                    _CardToggle(
                      label: '2nd Yel', 
                      color: Colors.yellow, 
                      active: stats['tarjetas_amarillas'] == 2, 
                      isDouble: true,
                      onTap: () {
                        stats['tarjetas_amarillas'] = stats['tarjetas_amarillas'] == 2 ? 0 : 2;
                        onChanged();
                      }
                    ),
                    _CardToggle(
                      label: 'Red', 
                      color: Colors.red, 
                      active: stats['tarjetas_rojas'] > 0, 
                      onTap: () {
                        stats['tarjetas_rojas'] = stats['tarjetas_rojas'] > 0 ? 0 : 1;
                        onChanged();
                      }
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _EventChip({required this.label, required this.icon, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? Colors.black : Colors.white38),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: active ? Colors.black : Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _StatControl extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final bool canAdd;
  final Function(int) onUpdate;

  const _StatControl({required this.label, required this.value, required this.icon, this.canAdd = true, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.white38),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: value > 0 ? () => onUpdate(value - 1) : null,
                child: const Icon(Icons.remove_circle_outline, color: Colors.white24, size: 20),
              ),
              Text('$value', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: canAdd ? () => onUpdate(value + 1) : null,
                child: Icon(Icons.add_circle_outline, color: canAdd ? AppColors.primary : Colors.white10, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardToggle extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final bool isDouble;
  final VoidCallback onTap;

  const _CardToggle({required this.label, required this.color, required this.active, this.isDouble = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : Colors.transparent),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Icon(Icons.rectangle_rounded, color: color, size: 16),
                if (isDouble) Positioned(right: -4, child: Icon(Icons.rectangle_rounded, color: color, size: 16)),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: active ? Colors.white : Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _MatchCounter extends StatelessWidget {
  final int value;
  final Function(int) onChanged;
  const _MatchCounter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: value > 0 ? () => onChanged(value - 1) : null,
          child: const Icon(Icons.remove_circle_outline, color: Colors.white24, size: 22),
        ),
        const SizedBox(width: 8),
        Text('$value', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => onChanged(value + 1),
          child: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 22),
        ),
      ],
    );
  }
}
