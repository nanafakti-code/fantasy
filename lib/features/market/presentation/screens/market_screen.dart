import 'dart:ui';
import 'dart:async' as async;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
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
  List<Map<String, dynamic>> _mercadoPlayers = [];
  List<Map<String, dynamic>> _misPujas = [];
  List<Map<String, dynamic>> _historial = [];
  List<Map<String, dynamic>> _allTeams = [];
  Map<String, String> _playerOwners = {}; // jugador_id -> username
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
        setState(() => _isLoading = false);
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

      // 3. Cagar jugadores del MERCADO (los que están a la venta en esta liga)
      var marketResponse = await Supabase.instance.client
          .from('mercado')
          .select('*, jugador:jugador_id(*, equipo_id(id, nombre, escudo_url))')
          .eq('liga_id', ligaId);

      // Si está vacío, generamos los 12 iniciales para esta liga (demo/primera vez)
      if (marketResponse.isEmpty) {
        await Supabase.instance.client.rpc('refrescar_mercado_liga', params: {'p_liga_id': ligaId});
        marketResponse = await Supabase.instance.client
            .from('mercado')
            .select('*, jugador:jugador_id(*, equipo_id(id, nombre, escudo_url))')
            .eq('liga_id', ligaId);
      }

      // 4. Cargar MIS PUJAS
      final pujasResponse = await Supabase.instance.client
          .from('pujas')
          .select('*, mercado(id, precio_minimo, fecha_fin, jugador:jugador_id(*, equipo_id(nombre, escudo_url)))')
          .eq('usuario_id', user.id);

      // 5. Cargar HISTORIAL de la liga
      final historyResponse = await Supabase.instance.client
          .from('transferencias')
          .select('*, jugador:jugador_id(*, equipo_id(nombre, escudo_url)), vendedor:vendedor_id(username), comprador:comprador_id(username)')
          .eq('liga_id', ligaId)
          .order('fecha', ascending: false)
          .limit(20);

      // 6. Cargar titulares/propietarios en esta liga
      final ownersResponse = await Supabase.instance.client
          .from('equipo_fantasy_jugadores')
          .select('jugador_id, equipos_fantasy(user_id, usuarios(username))')
          .filter('equipos_fantasy.liga_id', 'eq', ligaId);

      final Map<String, String> ownersMap = {};
      for (var row in (ownersResponse as List)) {
          final jugadorId = row['jugador_id']?.toString();
          final equipo = row['equipos_fantasy'];
          if (jugadorId != null && equipo != null) {
            final username = equipo['usuarios']?['username']?.toString() ?? 'Míster';
            ownersMap[jugadorId] = username;
          }
        }

      // 7. Cargar TODOS los jugadores para la búsqueda global
      final playersResponse = await Supabase.instance.client
          .from('jugadores')
          .select('*, equipo_id(id, nombre, escudo_url)')
          .order('nombre');

      if (mounted) {
        setState(() {
          _presupuesto = (membership['presupuesto'] as num?)?.toDouble() ?? 0;
          _allTeams = List<Map<String, dynamic>>.from(teamsResponse);
          _mercadoPlayers = List<Map<String, dynamic>>.from(marketResponse);
          _misPujas = List<Map<String, dynamic>>.from(pujasResponse as List);
          _historial = List<Map<String, dynamic>>.from(historyResponse as List);
          _playerOwners = ownersMap;
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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.bgGradient),
          child: Column(
            children: [
              _buildAppBar(context),
              TabBar(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                dividerColor: Colors.transparent,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelColor: AppColors.textMuted,
                tabs: const [
                  Tab(text: 'Mercado'),
                  Tab(text: 'Mis Pujas'),
                  Tab(text: 'Historial'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildMercadoTab(),
                    _buildOperacionesTab(),
                    _buildHistoricoTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMercadoTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    
    if (_mercadoPlayers.isEmpty) {
      return Center(child: Text('Mercado vacío para esta liga', style: TextStyle(color: Colors.white.withOpacity(0.3))));
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadInitialData,
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _mercadoPlayers.length,
              itemBuilder: (ctx, i) {
                final item = _mercadoPlayers[i];
                final jugadorData = item['jugador'] ?? {};
                final fechaFinStr = item['fecha_fin']?.toString();
                final fechaFin = fechaFinStr != null ? DateTime.parse(fechaFinStr) : null;
                
                return _PremiumMarketTile(
                  jugador: jugadorData,
                  precioSalida: (item['precio_minimo'] as num?)?.toDouble(),
                  fechaFin: fechaFin,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOperacionesTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    
    if (_misPujas.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.gavel_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text('No tienes pujas activas', style: TextStyle(color: AppColors.textMuted)),
        ],
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _misPujas.length,
      itemBuilder: (ctx, i) {
        final puja = _misPujas[i];
        final mercado = puja['mercado'] ?? {};
        final jugador = mercado['jugador'] ?? {};
        final monto = (puja['monto'] as num?)?.toDouble() ?? 0.0;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.gavel_rounded, color: AppColors.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(jugador['nombre'] ?? 'Jugador', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('Tu puja: ${(monto/1000000).toStringAsFixed(2)}M €', style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoricoTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

    if (_historial.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text('Aún no hay movimientos', style: TextStyle(color: AppColors.textMuted)),
        ],
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _historial.length,
      itemBuilder: (ctx, i) {
        final trans = _historial[i];
        final jugador = trans['jugador'] ?? {};
        final precio = (trans['precio'] as num?)?.toDouble() ?? 0.0;
        final comprador = trans['comprador']?['username'] ?? 'Liga';
        final vendedor = trans['vendedor']?['username'] ?? 'Liga';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.bgCardLight,
                child: Icon(Icons.swap_horiz_rounded, color: Colors.white54),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(jugador['nombre'] ?? 'Jugador', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('$vendedor ➔ $comprador', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Text('${(precio/1000000).toStringAsFixed(1)}M', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.accent)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 10, left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 48),
          Column(
            children: [
              const Text('LIGA FANTASY CHIPIONA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
              Text('Presupuesto: ${(_presupuesto/1000000).toStringAsFixed(1)}M €', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
            onPressed: () => _showSearchSheet(context),
          ),
        ],
      ),
    );
  }

  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateSheet) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              children: [
                _buildCreativeHeader(setStateSheet),
                Expanded(child: _buildPlayerList()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreativeHeader(StateSetter setStateSheet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.1),
                  blurRadius: 15,
                )
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                setState(() => _searchQuery = v);
                setStateSheet(() {}); // Forzar el repintado del BottomSheet
              },
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
              Expanded(
                child: _buildCreativeFilterBox(
                  'Equipo', 
                  Icons.shield_rounded, 
                  _selectedTeamName, 
                  hasMore: true, 
                  onTap: () => _showTeamPicker(setStateSheet)
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildCreativeFilterBox(
                  'Posición', 
                  Icons.grid_view_rounded, 
                  _selectedPosition?.toUpperCase(), 
                  hasMore: true, 
                  onTap: () => _showPositionPicker(setStateSheet)
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildSortBox(setStateSheet)),
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

  Widget _buildSortBox(StateSetter setStateSheet) {
    return PopupMenuButton<String>(
      onSelected: (val) {
        setState(() => _sortBy = val);
        setStateSheet(() {});
      },
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

  void _showPositionPicker(StateSetter setStateSheet) {
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
            ListTile(
              title: const Text('TODOS', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)), 
              onTap: () { 
                setState(() => _selectedPosition = null); 
                setStateSheet(() {});
                Navigator.pop(ctx); 
              }
            ),
            ...positions.entries.map((e) => ListTile(
              title: Text(e.value, style: const TextStyle(color: Colors.white)), 
              onTap: () { 
                setState(() => _selectedPosition = e.key); 
                setStateSheet(() {});
                Navigator.pop(ctx); 
              }
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showTeamPicker(StateSetter setStateSheet) {
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
                    onTap: () { 
                      setState(() { _selectedTeamId = null; _selectedTeamName = null; }); 
                      setStateSheet(() {});
                      Navigator.pop(ctx); 
                    },
                  ),
                  const Divider(color: Colors.white10),
                  ..._allTeams.map((t) => ListTile(
                    leading: (t['escudo_url'] != null && t['escudo_url'].toString().isNotEmpty)
                        ? Image.network(t['escudo_url'], width: 24, height: 24, errorBuilder: (c, e, s) => const Text('🏟️', style: TextStyle(fontSize: 20)))
                        : const Text('🏟️', style: TextStyle(fontSize: 20)),
                    title: Text(t['nombre'], style: const TextStyle(color: Colors.white)),
                    onTap: () { 
                      setState(() { _selectedTeamId = t['id']; _selectedTeamName = t['nombre']; }); 
                      setStateSheet(() {});
                      Navigator.pop(ctx); 
                    },
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
          ownerName: _playerOwners[j['id']?.toString()],
        );
      },
    );
  }
}


class _PremiumMarketTile extends StatefulWidget {
  final Map<String, dynamic> jugador;
  final double? precioSalida;
  final DateTime? fechaFin;
  const _PremiumMarketTile({required this.jugador, this.precioSalida, this.fechaFin});

  @override
  State<_PremiumMarketTile> createState() => _PremiumMarketTileState();
}

class _PremiumMarketTileState extends State<_PremiumMarketTile> {
  late async.Timer _timer;
  String _timeLeft = '23:59:59';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = async.Timer.periodic(const Duration(seconds: 1), (timer) {
      if (widget.fechaFin == null) return;
      
      final now = DateTime.now();
      final diff = widget.fechaFin!.difference(now);
      
      if (diff.isNegative) {
        if (mounted) setState(() => _timeLeft = '00:00:00');
        _timer.cancel();
      } else {
        final hours = diff.inHours.toString().padLeft(2, '0');
        final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
        if (mounted) {
          setState(() => _timeLeft = '$hours:$minutes:$seconds');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final jugador = widget.jugador;
    final equipoData = jugador['equipo_id'] as Map<String, dynamic>?;
    final precio = widget.precioSalida ?? (jugador['precio'] as num?)?.toDouble() ?? 0.0;
    final valor = (jugador['precio'] as num?)?.toDouble() ?? 0.0;
    final pos = jugador['posicion'] ?? '';
    final color = _getPosColor(pos);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          // Imagen del jugador decorada con degradado de posición
          Container(
            width: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.3), Colors.transparent],
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
              ),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
            ),
            child: (jugador['foto_url'] != null && (jugador['foto_url'] as String).isNotEmpty)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: color.withOpacity(0.4), width: 2),
                          boxShadow: [
                            BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, spreadRadius: 1),
                          ],
                        ),
                        child: ClipOval(
                          child: Transform.scale(
                            scale: 1.4,
                            child: Image.network(
                              jugador['foto_url'],
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -0.3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Icon(Icons.account_circle, size: 90, color: Colors.white.withOpacity(0.15)),
                  ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila 1: Pos, Nombre y Puntos (PFSY)
                  Row(
                    children: [
                      _PosTag(pos: pos, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          jugador['nombre'] ?? '', 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Text('PTS ', style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold)),
                      Text('${jugador['puntos_totales'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  
                  // Fila 2: Equipo y Estatus "Alineable"
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (equipoData?['escudo_url'] != null)
                        Image.network(equipoData!['escudo_url'], width: 14, height: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          equipoData?['nombre'] ?? 'LALIGA', 
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.check_circle, color: Colors.green, size: 14),
                      const SizedBox(width: 4),
                      const Text('Alineable', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  
                  // Tiempo restante (DINÁMICO)
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.white30, size: 14),
                      const SizedBox(width: 4),
                      Text(_timeLeft, style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),

                  const Spacer(),
                  
                  // Fila inferior: Valor, Precio y Botón de Fichar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Valor: ${(valor/1000000).toStringAsFixed(1)}M', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                          Text('${(precio/1000000).toStringAsFixed(1)}M €', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Fichar', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPosColor(String pos) {
    if (pos == 'portero') return AppColors.goalkeeper;
    if (pos == 'defensa') return AppColors.defender;
    if (pos == 'centrocampista') return AppColors.midfielder;
    if (pos == 'delantero') return AppColors.forward;
    return AppColors.primary;
  }
}

class _PosTag extends StatelessWidget {
  final String? pos;
  final Color color;
  const _PosTag({this.pos, required this.color});
  @override
  Widget build(BuildContext context) {
    String label = 'PT';
    if (pos == 'defensa') label = 'DF';
    if (pos == 'centrocampista') label = 'CC';
    if (pos == 'delantero') label = 'DL';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 9)),
    );
  }
}

class _CreativePlayerTile extends StatelessWidget {
  final Map<String, dynamic> jugador;
  final bool showFullName;
  final String? ownerName;
  const _CreativePlayerTile({required this.jugador, this.showFullName = false, this.ownerName});

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
            child: (jugador['foto_url'] != null && (jugador['foto_url'] as String).isNotEmpty)
                ? Padding(
                    padding: const EdgeInsets.all(4.0), // Margen interno para que la imagen sea más pequeña que el fondo
                    child: ClipOval(
                      child: Transform.scale(
                        scale: 1.4,
                        child: Image.network(
                          jugador['foto_url'],
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.3),
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: (equipoData?['escudo_url'] != null && (equipoData!['escudo_url'] as String).isNotEmpty)
                      ? Image.network(
                          equipoData['escudo_url'],
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
                if (ownerName != null)
                   Container(
                     margin: const EdgeInsets.only(top: 4),
                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                     decoration: BoxDecoration(
                       color: AppColors.primary.withOpacity(0.1), 
                       borderRadius: BorderRadius.circular(4),
                       border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                     ),
                     child: Text(
                       ownerName!.toUpperCase(), 
                       style: const TextStyle(
                         color: AppColors.primary, 
                         fontSize: 9, 
                         fontWeight: FontWeight.bold
                       )
                     ),
                   ),
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
                child: Row(
                  children: [
                    const Text('PTS ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 9)),
                    Text('${jugador['puntos_totales'] ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
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
