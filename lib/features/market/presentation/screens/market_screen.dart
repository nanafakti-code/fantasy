import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/main_scaffold.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedPosition;
  String? _selectedTeamId;
  String? _selectedTeamName;
  String _sortBy = 'Precio';
  
  List<Map<String, dynamic>> _allPlayers = [];
  List<Map<String, dynamic>> _allTeams = [];
  double _presupuesto = 0;
  
  final _searchController = TextEditingController();

  final List<String> _sortOptions = [
    'Puntos', 'Precio', 'Nombre', 'Equipo', 'Posición', 'Estado'
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
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

      // 1. Cargar presupuesto
      final membership = await Supabase.instance.client
          .from('usuarios_ligas')
          .select('presupuesto')
          .eq('user_id', user.id)
          .eq('liga_id', ligaId)
          .single();

      // 2. Cargar EQUIPOS REALES para el filtro
      final teamsResponse = await Supabase.instance.client
          .from('equipos_reales')
          .select('id, nombre, escudo_url')
          .order('nombre');

      // 3. Cargar TODOS los jugadores
      final playersResponse = await Supabase.instance.client
          .from('jugadores')
          .select('*, equipo_id(id, nombre, escudo_url)')
          .order('nombre');

      if (mounted) {
        setState(() {
          _presupuesto = (membership['presupuesto'] as num?)?.toDouble() ?? 0;
          _allTeams = List<Map<String, dynamic>>.from(teamsResponse);
          _allPlayers = List<Map<String, dynamic>>.from(playersResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ERROR Mercado: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _displayPlayers {
    Iterable<Map<String, dynamic>> pool = _allPlayers;
    
    if (_searchQuery.isNotEmpty) {
      pool = pool.where((j) {
        final name = j['nombre'].toString().toLowerCase();
        final apps = (j['apellidos'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery.toLowerCase()) || apps.contains(_searchQuery.toLowerCase());
      });
    }

    if (_selectedPosition != null) {
      pool = pool.where((j) => j['posicion'] == _selectedPosition);
    }

    if (_selectedTeamName != null) {
      pool = pool.where((j) {
        final equipoNombre = j['equipo_id']?['nombre']?.toString() ?? '';
        return equipoNombre == _selectedTeamName;
      });
    }

    List<Map<String, dynamic>> result = pool.toList();
    switch (_sortBy) {
      case 'Precio':
        result.sort((a, b) => ((b['precio'] ?? 0) as num).compareTo((a['precio'] ?? 0) as num));
        break;
      case 'Puntos':
        result.sort((a, b) => ((b['puntos_totales'] ?? 0) as num).compareTo((a['puntos_totales'] ?? 0) as num));
        break;
      case 'Nombre':
        result.sort((a, b) => (a['nombre'] ?? '').toString().compareTo((b['nombre'] ?? '').toString()));
        break;
      case 'Equipo':
        result.sort((a, b) {
          final ea = a['equipo_id']?['nombre']?.toString() ?? '';
          final eb = b['equipo_id']?['nombre']?.toString() ?? '';
          return ea.compareTo(eb);
        });
        break;
      case 'Posición':
        const posOrder = {
          'portero': 1,
          'defensa': 2,
          'centrocampista': 3,
          'delantero': 4,
        };
        result.sort((a, b) {
          final rankA = posOrder[a['posicion']] ?? 5;
          final rankB = posOrder[b['posicion']] ?? 5;
          if (rankA != rankB) return rankA.compareTo(rankB);
          return (a['nombre'] ?? '').toString().compareTo((b['nombre'] ?? '').toString());
        });
        break;
    }
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedLeagueIdProvider, (prev, next) {
      if (mounted && next != prev && next != null) _loadInitialData();
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.2)),
                    child: Column(
                      children: [
                        _buildCreativeHeader(),
                        Expanded(
                          child: _isLoading 
                            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                            : _buildPlayerList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 10, left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Navigator.canPop(context) 
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              )
            : const SizedBox(width: 48),
          Column(
            children: [
              const Text('MERCADO DE FICHAJES', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
              Text('Presupuesto: ${(_presupuesto/1000000).toStringAsFixed(1)}M €', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildCreativeHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Container(
            height: 50,
            decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 15)]),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Busca a tu estrella...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCreativeFilterBox('Favoritos', Icons.star_rounded, null)),
              const SizedBox(width: 12),
              Expanded(child: _buildCreativeFilterBox('Equipo', Icons.shield_rounded, _selectedTeamName, hasMore: true, onTap: _showTeamPicker)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildCreativeFilterBox('Posición', Icons.grid_view_rounded, _selectedPosition?.toUpperCase(), hasMore: true, onTap: _showPositionPicker)),
              const SizedBox(width: 12),
              Expanded(child: _buildSortBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreativeFilterBox(String title, IconData icon, String? value, {bool hasMore = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(value ?? title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
            if (hasMore) Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withOpacity(0.3), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSortBox() {
    return PopupMenuButton<String>(
      onSelected: (val) => setState(() => _sortBy = val),
      color: AppColors.bgCard,
      offset: const Offset(0, 50),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF10B981)]), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.sort_rounded, color: Colors.black, size: 18),
            Text(_sortBy, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
            const Icon(Icons.unfold_more_rounded, color: Colors.black, size: 18),
          ],
        ),
      ),
      itemBuilder: (ctx) => _sortOptions.map((opt) => PopupMenuItem(value: opt, child: Text(opt, style: const TextStyle(color: Colors.white, fontSize: 14)))).toList(),
    );
  }

  void _showPositionPicker() {
    final positions = {'portero':'PORTEROS', 'defensa':'DEFENSAS', 'centrocampista':'MEDIOS', 'delantero':'DELANTEROS'};
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('TODOS', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)), onTap: () { setState(() => _selectedPosition = null); Navigator.pop(ctx); }),
            ...positions.entries.map((e) => ListTile(title: Text(e.value, style: const TextStyle(color: Colors.white)), onTap: () { setState(() => _selectedPosition = e.key); Navigator.pop(ctx); })),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showTeamPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const Text('SELECCIONAR EQUIPO', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('TODOS LOS EQUIPOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onTap: () { setState(() { _selectedTeamId = null; _selectedTeamName = null; }); Navigator.pop(ctx); },
                  ),
                  const Divider(color: Colors.white10),
                  ..._allTeams.map((t) => ListTile(
                    leading: (t['escudo_url'] != null && t['escudo_url'].toString().isNotEmpty)
                        ? Image.network(t['escudo_url'], width: 24, height: 24, errorBuilder: (c, e, s) => const Text('🏟️', style: TextStyle(fontSize: 20)))
                        : const Text('🏟️', style: TextStyle(fontSize: 20)),
                    title: Text(t['nombre'], style: const TextStyle(color: Colors.white)),
                    onTap: () { setState(() { _selectedTeamId = t['id']; _selectedTeamName = t['nombre']; }); Navigator.pop(ctx); },
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerList() {
    final players = _displayPlayers;
    if (players.isEmpty) {
       return ListView(children: [SizedBox(height: 100, child: Center(child: Text('No hay resultados', style: TextStyle(color: Colors.white.withOpacity(0.3))))),]);
    }

    // Calcular duplicados de nombres para decidir si mostrar apellidos
    final nameCounts = <String, int>{};
    for (var p in players) {
      final name = p['nombre']?.toString() ?? '';
      nameCounts[name] = (nameCounts[name] ?? 0) + 1;
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: players.length,
      itemBuilder: (ctx, i) {
        final j = players[i];
        final name = j['nombre']?.toString() ?? '';
        final isDuplicate = (nameCounts[name] ?? 0) > 1;
        
        return _CreativePlayerTile(
          jugador: j, 
          showFullName: isDuplicate,
        );
      },
    );
  }
}

class _CreativePlayerTile extends StatelessWidget {
  final Map<String, dynamic> jugador;
  final bool showFullName;
  const _CreativePlayerTile({required this.jugador, this.showFullName = false});

  @override
  Widget build(BuildContext context) {
    final nombre = jugador['nombre'] ?? '';
    final apellidos = jugador['apellidos'] ?? '';
    final displayName = showFullName ? '$nombre $apellidos' : nombre;
    final equipoData = jugador['equipo_id'] as Map<String, dynamic>?;
    final equipoNombre = equipoData?['nombre'] ?? 'Sin equipo';
    final precio = (jugador['precio'] as num?)?.toDouble() ?? 0.0;
    final pos = jugador['posicion'] ?? '';
    final color = _getPosColor(pos);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.03))),
      child: Row(
        children: [
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: (equipoData?['escudo_url'] != null)
                  ? Image.network(
                      equipoData!['escudo_url'],
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Center(child: Text('⚽', style: TextStyle(fontSize: 24))),
                    )
                  : const Center(child: Text('⚽', style: TextStyle(fontSize: 24))),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(equipoNombre, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                _CreativePosTag(pos: pos, color: color),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Text('PTS ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 9)),
                    Text('0', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('${(precio / 1000000).toStringAsFixed(1)}M €', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPosColor(String pos) {
    if (pos == 'portero') return AppColors.goalkeeper;
    if (pos == 'defensa') return AppColors.defender;
    if (pos == 'centrocampista') return AppColors.midfielder;
    return AppColors.forward;
  }
}

class _CreativePosTag extends StatelessWidget {
  final String? pos;
  final Color color;
  const _CreativePosTag({this.pos, required this.color});
  @override
  Widget build(BuildContext context) {
    String label = 'PT';
    if (pos == 'defensa') label = 'DF';
    if (pos == 'centrocampista') label = 'CC';
    if (pos == 'delantero') label = 'DL';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10)),
    );
  }
}
