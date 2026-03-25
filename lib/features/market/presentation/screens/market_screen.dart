import 'dart:ui';
import 'package:intl/intl.dart';
import 'dart:async' as async;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/main_scaffold.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../models/jugador.dart';

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
  List<Map<String, dynamic>> _misOfertasP2P = [];
  List<Map<String, dynamic>> _ofertasP2PRecibidas = [];
  List<Map<String, dynamic>> _ofertasLigaRecibidas = [];
  List<Map<String, dynamic>> _misVentas = [];
  List<Map<String, dynamic>> _ofertasMercado = []; // Ofertas de la liga para MIS ventas
  List<Map<String, dynamic>> _pujasRecibidas = []; // Pujas de otros usuarios para MIS ventas
  List<Map<String, dynamic>> _historial = [];
  List<Map<String, dynamic>> _allTeams = [];
  Map<String, String> _playerOwners = {}; // jugador_id -> username
  String _ligaNombre = 'CARGANDO...';
  double _presupuesto = 0;
  double _totalPujado = 0;
  int _playerCount = 0;
  
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

      // 1. Cargar presupuesto y nombre de la liga
      final membership = await Supabase.instance.client
          .from('usuarios_ligas')
          .select('presupuesto, liga:liga_id(nombre)')
          .eq('user_id', user.id)
          .eq('liga_id', ligaId)
          .single();
      
      final ligaData = membership['liga'] as Map?;
      final String ligaNombre = (ligaData?['nombre'] ?? 'LIGA FANTASY').toString().toUpperCase();

      // 1b. Cargar total pujado para esta liga
      final bidsResponse = await Supabase.instance.client
          .from('pujas')
          .select('monto, mercado:mercado_id(liga_id)')
          .eq('usuario_id', user.id);
      
      double totalBids = 0;
      for (var b in bidsResponse) {
        final m = b['mercado'] as Map?;
        if (m != null && m['liga_id'] == ligaId) {
          totalBids += (b['monto'] as num).toDouble();
        }
      }

      // 2. Cargar EQUIPOS REALES para el filtro
      final teamsResponse = await Supabase.instance.client
          .from('equipos_reales')
          .select('id, nombre, escudo_url')
          .order('nombre');
      // 3. Cagar jugadores del MERCADO (los que están a la venta en esta liga)
      List<Map<String, dynamic>> allMarketResponse = List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('mercado')
            .select('*, jugador:jugador_id(*, equipo_id(id, nombre, escudo_url))')
            .eq('liga_id', ligaId)
      );
          
      // Comprobar si debemos refrescar (mercado vacío o jugadores de Liga caducados)
      bool needsRefresh = allMarketResponse.isEmpty;
      if (!needsRefresh) {
        final now = DateTime.now();
        needsRefresh = allMarketResponse.any((p) {
          if (p['vendedor_id'] != null) return false; // Ignorar jugadores de usuarios
          final fechaFinStr = p['fecha_fin']?.toString();
          if (fechaFinStr == null) return true;
          return now.isAfter(DateTime.parse(fechaFinStr));
        });
      }

      if (needsRefresh) {
        try {
          await Supabase.instance.client.rpc('refrescar_mercado_liga', params: {'p_liga_id': ligaId});
          final freshResponse = await Supabase.instance.client
              .from('mercado')
              .select('*, jugador:jugador_id(*, equipo_id(id, nombre, escudo_url))')
              .eq('liga_id', ligaId);
          allMarketResponse = List<Map<String, dynamic>>.from(freshResponse);
        } catch (e) {
          debugPrint('Aviso: No se pudo refrescar el mercado automáticamente: $e');
        }
      }
           // 2. Jugadores en el mercado (con info de vendedor si existe)
      final marketResponse = await Supabase.instance.client
          .from('mercado')
          .select('*, jugador:jugador_id(*, equipo_id(*)), vendedor:vendedor_id(username), pujas(count)')
          .eq('liga_id', ligaId);
      
      final List<Map<String, dynamic>> marketList = List<Map<String, dynamic>>.from(marketResponse);
      final List<Map<String, dynamic>> mercadoPlayers = List<Map<String, dynamic>>.from(marketList.where((p) => p['vendedor_id'] != user.id));
      final List<Map<String, dynamic>> misVentas = List<Map<String, dynamic>>.from(marketList.where((p) => p['vendedor_id'] == user.id));

      // 3. Mis pujas Realizadas
      final myBidsResponse = await Supabase.instance.client
          .from('pujas')
          .select('*, mercado:mercado_id(*, jugador:jugador_id(*, equipo_id(*)))')
          .eq('usuario_id', user.id);
      
      final List<Map<String, dynamic>> misPujas = List<Map<String, dynamic>>.from(myBidsResponse);

      // 3b. Pujas recibidas por MIS jugadores en venta
      List<Map<String, dynamic>> pujasRecibidas = [];
      if (misVentas.isNotEmpty) {
        final incomingBidsResponse = await Supabase.instance.client
            .from('pujas')
            .select('*, usuario:usuario_id(username)')
            .inFilter('mercado_id', misVentas.map((v) => v['id']).toList());
        pujasRecibidas = List<Map<String, dynamic>>.from(incomingBidsResponse);
      }

      // 4. Cargar MIS OFERTAS P2P (Hechas a otros usuarios)
      final p2pOffersResponse = await Supabase.instance.client
          .from('ofertas_jugadores')
          .select('*, jugador:jugador_id(*, equipo_id(nombre, escudo_url)), vendedor:vendedor_id(username)')
          .eq('comprador_id', user.id)
          .eq('liga_id', ligaId)
          .eq('estado', 'pendiente');

      final List<Map<String, dynamic>> misOfertasP2P = List<Map<String, dynamic>>.from(p2pOffersResponse);

      // 4b. Cargar OFERTAS P2P RECIBIDAS (De otros usuarios para mis jugadores)
      final p2pReceivedResponse = await Supabase.instance.client
          .from('ofertas_jugadores')
          .select('*, jugador:jugador_id(*, equipo_id(nombre, escudo_url)), comprador:comprador_id(username)')
          .eq('vendedor_id', user.id)
          .eq('liga_id', ligaId)
          .eq('estado', 'pendiente');

      final List<Map<String, dynamic>> ofertasP2PRecibidas = List<Map<String, dynamic>>.from(p2pReceivedResponse);

      // 4c. Cargar OFERTAS DE LA LIGA (De la "máquina")
      final ligaOffersResponse = await Supabase.instance.client
          .from('ofertas_mercado')
          .select('*, mercado:mercado_id(*, jugador:jugador_id(*, equipo_id(nombre, escudo_url)))')
          .eq('usuario_id', user.id)
          .eq('estado', 'pendiente');
      
      final List<Map<String, dynamic>> ofertasLigaRecibidas = List<Map<String, dynamic>>.from(ligaOffersResponse);

      // 5. Cargar HISTORIAL de la liga
      final historyResponse = await Supabase.instance.client
          .from('transferencias')
          .select('*, jugador:jugador_id(*, equipo_id(nombre, escudo_url)), vendedor:vendedor_id(username), comprador:comprador_id(username)')
          .eq('liga_id', ligaId)
          .order('fecha', ascending: false)
          .limit(20);

      // 6. Cagar OFERTAS de la liga para este usuario
      final offersResponse = await Supabase.instance.client
          .from('ofertas_mercado')
          .select('*')
          .eq('usuario_id', user.id)
          .eq('estado', 'pendiente');

      // 7. Cargar titulares/propietarios en esta liga
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

      // 8. Cargar número de jugadores en plantilla
      final efResponse = await Supabase.instance.client
          .from('equipos_fantasy')
          .select('id')
          .eq('user_id', user.id)
          .eq('liga_id', ligaId)
          .single();
      
      final teamPlayersResponse = await Supabase.instance.client
          .from('equipo_fantasy_jugadores')
          .select('id')
          .eq('equipo_fantasy_id', efResponse['id']);
      
      final squadSize = (teamPlayersResponse as List).length;

      if (mounted) {
        setState(() {
          _presupuesto = (membership['presupuesto'] as num?)?.toDouble() ?? 0;
          _ligaNombre = ligaNombre;
          _totalPujado = totalBids;
          _playerCount = squadSize;
          _allTeams = List<Map<String, dynamic>>.from(teamsResponse);
          _mercadoPlayers = mercadoPlayers;
          _misVentas = misVentas;
          _misPujas = misPujas;
          _misOfertasP2P = misOfertasP2P;
          _ofertasP2PRecibidas = ofertasP2PRecibidas;
          _ofertasLigaRecibidas = ofertasLigaRecibidas.where((o) => !misVentas.any((v) => v['id'] == o['mercado_id'])).toList();
          _pujasRecibidas = pujasRecibidas;
          _ofertasMercado = List<Map<String, dynamic>>.from(offersResponse);
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
                  Tab(text: 'Operaciones'),
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
                
                // Comprobar si ya hemos pujado por este jugador
                final puja = _misPujas.firstWhere(
                  (p) => p['mercado_id'] == item['id'],
                  orElse: () => {}
                );
                final bool yaPujado = puja.isNotEmpty;
                
                final String? ownerName = item['vendedor']?['username'];
                final countData = item['pujas'] as List?;
                final bidCount = (countData != null && countData.isNotEmpty) ? countData[0]['count'] as int : 0;
                
                return _PremiumMarketTile(
                  jugador: jugadorData,
                  precioSalida: (item['precio_minimo'] as num?)?.toDouble(),
                  fechaFin: fechaFin,
                  isOwner: item['vendedor_id'] == Supabase.instance.client.auth.currentUser?.id,
                  ownerName: ownerName,
                  actionLabel: yaPujado ? 'Acciones' : null,
                  bidCount: bidCount,
                  onAction: () {
                    if (yaPujado) {
                      _showBidActionsMenu(item, puja);
                    } else {
                      _showBidModal(item);
                    }
                  },
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
    
    if (_misPujas.isEmpty && _misVentas.isEmpty && _misOfertasP2P.isEmpty && _ofertasP2PRecibidas.isEmpty && _ofertasLigaRecibidas.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.gavel_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text('No tienes operaciones activas', style: TextStyle(color: AppColors.textMuted)),
        ],
      ));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_misVentas.isNotEmpty) ...[
          _buildTabHeader('VENTAS EN CURSO'),
          ..._misVentas.map((venta) {
            final jugador = venta['jugador'] ?? {};
            final precio = (venta['precio_minimo'] as num?)?.toDouble();
            final fechaFinStr = venta['fecha_fin']?.toString();
            final fechaFin = fechaFinStr != null ? DateTime.parse(fechaFinStr) : null;
            
            // Buscar oferta si existe
            final oferta = _ofertasMercado.firstWhere(
              (o) => o['mercado_id'] == venta['id'], 
              orElse: () => {}
            );
            
            // Buscar pujas de otros usuarios
            final pujasDeOtros = _pujasRecibidas.where((p) => p['mercado_id'] == venta['id']).toList();
            
            return Column(
              children: [
                _PremiumMarketTile(
                  jugador: jugador,
                  precioSalida: precio,
                  fechaFin: fechaFin,
                  isOwner: true,
                  onAction: () => _showVentaActions(venta),
                ),
                if (oferta.isNotEmpty)
                  _buildLeagueOfferBox(oferta, venta),
                if (pujasDeOtros.isNotEmpty)
                  ...pujasDeOtros.map((p) => _buildUserBidBox(p, venta)),
                const SizedBox(height: 12),
              ],
            );
          }),
          const SizedBox(height: 24),
        ],
        if (_misPujas.isNotEmpty) ...[
          _buildTabHeader('MIS PUJAS ACTIVAS'),
          ..._misPujas.map((puja) {
            final mercado = puja['mercado'] ?? {};
            final jugador = mercado['jugador'] ?? {};
            final monto = (puja['monto'] as num?)?.toDouble() ?? 0.0;
            final fechaFinStr = mercado['fecha_fin']?.toString();
            final fechaFin = fechaFinStr != null ? DateTime.parse(fechaFinStr) : null;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PremiumMarketTile(
                jugador: jugador,
                precioSalida: monto,
                fechaFin: fechaFin,
                actionLabel: 'Acciones',
                onAction: () => _showBidActionsMenu(mercado, puja),
              ),
            );
          }),
        ],

        if (_ofertasLigaRecibidas.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildTabHeader('OFERTAS DE LA LIGA'),
          ..._ofertasLigaRecibidas.map((oferta) {
            final mercadoRow = oferta['mercado'] ?? {};
            final jugador = mercadoRow['jugador'] ?? {};
            final monto = (oferta['monto'] as num?)?.toDouble() ?? 0.0;

            return Column(
              children: [
                _PremiumMarketTile(
                  jugador: jugador,
                  precioSalida: monto,
                  fechaFin: null,
                  ownerName: 'Liga Fantasy',
                  actionLabel: 'Gestionar',
                  onAction: () => _showLigaOfferDialog(oferta),
                ),
                _buildLigaActionBox(oferta),
                const SizedBox(height: 12),
              ],
            );
          }),
        ],

        if (_ofertasP2PRecibidas.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildTabHeader('OFERTAS P2P RECIBIDAS'),
          ..._ofertasP2PRecibidas.map((oferta) {
            final jugador = oferta['jugador'] ?? {};
            final monto = (oferta['monto'] as num?)?.toDouble() ?? 0.0;
            final comprador = oferta['comprador']?['username'] ?? 'Usuario';

            return Column(
              children: [
                _PremiumMarketTile(
                  jugador: jugador,
                  precioSalida: monto,
                  fechaFin: null,
                  ownerName: comprador,
                  actionLabel: 'Gestionar',
                  onAction: () => _showP2PManagementDialog(oferta),
                ),
                _buildP2PActionBox(oferta),
                const SizedBox(height: 12),
              ],
            );
          }),
        ],

        if (_misOfertasP2P.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildTabHeader('MIS OFERTAS A OTROS'),
          ..._misOfertasP2P.map((oferta) {
            final jugador = oferta['jugador'] ?? {};
            final monto = (oferta['monto'] as num?)?.toDouble() ?? 0.0;
            final String? ownerName = oferta['vendedor']?['username'];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PremiumMarketTile(
                jugador: jugador,
                precioSalida: monto,
                fechaFin: null, // P2P no tiene tiempo fin de la liga
                ownerName: ownerName ?? 'Otro usuario',
                actionLabel: 'Cancelar',
                onAction: () => _confirmarCancelarOfertaP2P(oferta['id']),
              ),
            );
          }),
        ],
      ],
    );
  }

  void _confirmarCancelarOfertaP2P(String ofertaId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Cancelar Oferta'),
        content: const Text('¿Estás seguro de que deseas retirar esta oferta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cancelarOfertaP2P(ofertaId);
            },
            child: const Text('Sí, Cancelar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelarOfertaP2P(String ofertaId) async {
    try {
      setState(() => _isLoading = true);
      final response = await Supabase.instance.client.from('ofertas_jugadores').delete().eq('id', ofertaId).select();
      
      if (response.isEmpty) {
        throw 'No se pudo cancelar la oferta. Puede que ya no exista o no tengas permisos.';
      }

      await _loadInitialData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Oferta cancelada con éxito')));
      }
    } catch (e) {
      debugPrint('Error al cancelar oferta P2P: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
      setState(() => _isLoading = false);
    }
  }

  void _showP2PManagementDialog(Map<String, dynamic> oferta) {
    final monto = (oferta['monto'] as num?)?.toDouble() ?? 0.0;
    final comprador = oferta['comprador']?['username'] ?? 'Usuario';
    final jugador = oferta['jugador']?['nombre'] ?? 'Jugador';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Gestionar Oferta por $jugador', style: const TextStyle(color: Colors.white)),
        content: Text('¿Deseas aceptar la oferta de $comprador por ${CurrencyFormatter.format(monto)}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _rejectP2POffer(oferta['id']);
            },
            child: const Text('Rechazar', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _acceptP2POffer(oferta['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Widget _buildP2PActionBox(Map<String, dynamic> oferta) {
    return Container(
      margin: const EdgeInsets.only(top: 0, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _rejectP2POffer(oferta['id']),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
              child: const Text('Rechazar', style: TextStyle(color: Colors.white70)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _acceptP2POffer(oferta['id']),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
              child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptP2POffer(String ofertaId) async {
    try {
      setState(() => _isLoading = true);
      final response = await Supabase.instance.client.rpc('aceptar_oferta_p2p', params: {'p_oferta_id': ofertaId});
      
      if (response['success'] == true) {
        await _loadInitialData();
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta P2P realizada con éxito!')));
        }
      } else {
        throw response['mensaje'] ?? 'Error desconocido';
      }
    } catch (e) {
      debugPrint('Error al aceptar P2P: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectP2POffer(String ofertaId) async {
    try {
      setState(() => _isLoading = true);
      await Supabase.instance.client
          .from('ofertas_jugadores')
          .update({'estado': 'rechazada'})
          .eq('id', ofertaId);
      
      await _loadInitialData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Oferta rechazada')));
      }
    } catch (e) {
      debugPrint('Error al rechazar P2P: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildLeagueOfferBox(Map<String, dynamic> oferta, Map<String, dynamic> venta) {
    final monto = (oferta['monto'] as num?)?.toDouble() ?? 0.0;
    return Container(
      margin: const EdgeInsets.only(top: 0, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on_rounded, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Oferta de la Liga recibida:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
              Text(
                CurrencyFormatter.format(monto),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _rejectLeagueOffer(oferta['id']),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Rechazar', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptLeagueOffer(oferta['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                  ),
                  child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserBidBox(Map<String, dynamic> puja, Map<String, dynamic> mercado) {
    final monto = (puja['monto'] as num?)?.toDouble() ?? 0.0;
    final username = puja['usuario']?['username'] ?? 'Usuario';
    
    return Container(
      margin: const EdgeInsets.only(top: 0, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.gavel_rounded, color: Colors.orangeAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Oferta de $username:', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
              Text(
                CurrencyFormatter.format(monto),
                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _rejectUserBid(puja['id']),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Rechazar', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptUserBid(puja['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                  ),
                  child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _acceptUserBid(String pujaId) async {
    try {
      setState(() => _isLoading = true);
      final response = await Supabase.instance.client.rpc('aceptar_puja_mercado', params: {'p_puja_id': pujaId});
      
      if (response != null && response['error'] != null) {
        throw response['error'];
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta realizada con éxito'), backgroundColor: AppColors.success));
        _loadInitialData();
      }
    } catch (e) {
      debugPrint('Error al aceptar puja: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rejectUserBid(String pujaId) async {
    try {
      await Supabase.instance.client.from('pujas').delete().eq('id', pujaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Oferta rechazada')));
        _loadInitialData();
      }
    } catch (e) {
      debugPrint('Error al rechazar puja: $e');
    }
  }

  Future<void> _acceptLeagueOffer(String ofertaId) async {
    try {
      setState(() => _isLoading = true);
      final response = await Supabase.instance.client
          .rpc('aceptar_oferta_liga_mercado', params: {'p_oferta_id': ofertaId});
      
      if (response['success'] == true) {
        await _loadInitialData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta realizada con éxito')));
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['mensaje'] ?? 'Error')));
        }
      }
    } catch (e) {
      debugPrint('Error al aceptar oferta: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectLeagueOffer(String ofertaId) async {
    try {
      await Supabase.instance.client
          .from('ofertas_mercado')
          .update({'estado': 'rechazada'})
          .eq('id', ofertaId);
      
      _loadInitialData();
    } catch (e) {
      debugPrint('Error al rechazar oferta: $e');
    }
  }

  void _showVentaActions(Map<String, dynamic> venta) {
    final jugador = venta['jugador'] ?? {};
    final marketId = venta['id'];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 16),
              child: Text(
                jugador['nombre'] ?? 'Gestión de Venta',
                style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline_rounded, color: Colors.orange),
              title: const Text('Quitar del mercado', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _removeFromMarket(marketId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flash_on_rounded, color: Colors.redAccent),
              title: const Text('Venta rápida (50%)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('Recibes ${CurrencyFormatter.format(((jugador['precio'] ?? 0) as num) / 2)}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _quickSale(venta);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeFromMarket(String marketId) async {
    try {
      await Supabase.instance.client.from('mercado').delete().eq('id', marketId);
      _loadInitialData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jugador retirado del mercado')));
      }
    } catch (e) {
      debugPrint('Error al quitar del mercado: $e');
    }
  }

  Future<void> _quickSale(Map<String, dynamic> venta) async {
    try {
      final supabase = Supabase.instance.client;
      final jugador = venta['jugador'] ?? {};
      final marketId = venta['id'];
      final jugadorId = jugador['id'];
      final ligaId = ref.read(selectedLeagueIdProvider);
      final user = supabase.auth.currentUser;
      final salePrice = ((jugador['precio'] ?? 0) as num).toDouble() / 2;

      if (user == null || ligaId == null) return;

      // 1. Eliminar del mercado
      await supabase.from('mercado').delete().eq('id', marketId);

      // 2. Eliminar del equipo
      // Primero buscamos el equipo_fantasy_id
      final ef = await supabase.from('equipos_fantasy').select('id').eq('user_id', user.id).eq('liga_id', ligaId).single();
      final equipoId = ef['id'];

      await supabase.from('equipo_fantasy_jugadores').delete().eq('equipo_fantasy_id', equipoId).eq('jugador_id', jugadorId);

      // 3. Actualizar presupuesto
      await supabase.rpc('vender_jugador_inmediato', params: {
          'p_user_id': user.id,
          'p_liga_id': ligaId,
          'p_precio': salePrice,
      });

      // 4. Registrar transferencia
      await supabase.from('transferencias').insert({
        'liga_id': ligaId,
        'jugador_id': jugadorId,
        'vendedor_id': user.id,
        'comprador_id': null,
        'precio': salePrice,
      });

      _loadInitialData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta rápida realizada con éxito')));
      }
    } catch (e) {
      debugPrint('Error en venta rápida: $e');
    }
  }

  Widget _buildTabHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
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
        final pos = jugador['posicion'] ?? '';
        final color = _getPosColor(pos);
        
        final buyerId = trans['comprador_id'];
        final sellerId = trans['vendedor_id'];
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        
        String prefix = '';
        Color priceColor = Colors.yellow;
        
        if (sellerId == currentUserId) {
          prefix = '+';
          priceColor = AppColors.success;
        } else if (buyerId == currentUserId) {
          prefix = '-';
          priceColor = Colors.redAccent;
        }
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 70,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Mini foto del jugador con fondo de color de posición
              Container(
                width: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.2), Colors.transparent],
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  ),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                ),
                child: (jugador['foto_url'] != null && (jugador['foto_url'] as String).isNotEmpty)
                    ? Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                          ),
                          child: ClipOval(
                            child: Transform.scale(
                              scale: 1.4,
                              child: Image.network(
                                jugador['foto_url'],
                                fit: BoxFit.cover,
                                alignment: const Alignment(0, -0.3),
                              ),
                            ),
                          ),
                        ),
                      )
                    : Icon(Icons.person, color: Colors.white.withOpacity(0.1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jugador['nombre'] ?? 'Jugador',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            vendedor, 
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward_rounded, size: 10, color: Colors.white24),
                        ),
                        Flexible(
                          child: Text(
                            comprador, 
                            style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '$prefix${CurrencyFormatter.format(precio)}',
                  style: TextStyle(color: priceColor, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
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
              Text(_ligaNombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Presupuesto: ${CurrencyFormatter.format(_presupuesto - _totalPujado)}', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  if (_totalPujado > 0)
                    Text(' (-${CurrencyFormatter.format(_totalPujado)})', style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
                ],
              ),
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

  Color _getPosColor(String pos) {
    if (pos == 'portero') return AppColors.goalkeeper;
    if (pos == 'defensa') return AppColors.defender;
    if (pos == 'centrocampista') return AppColors.midfielder;
    if (pos == 'delantero') return AppColors.forward;
    return AppColors.primary;
  }

  void _showBidActionsMenu(Map<String, dynamic> item, Map<String, dynamic> puja) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('GESTIONAR PUJA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
            const SizedBox(height: 24),
            _buildActionItem(
              icon: Icons.edit_rounded,
              title: 'Editar puja',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(ctx);
                _showBidModal(item, existingBid: puja);
              },
            ),
            _buildActionItem(
              icon: Icons.delete_outline_rounded,
              title: 'Eliminar puja',
              color: Colors.redAccent,
              onTap: () {
                Navigator.pop(ctx);
                _deleteBid(puja['id']);
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white10),
        onTap: onTap,
      ),
    );
  }

  void _showLigaOfferDialog(Map<String, dynamic> oferta) {
    final mercadoRow = oferta['mercado'] ?? {};
    final jugador = mercadoRow['jugador'] ?? {};
    final monto = (oferta['monto'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Oferta de la Liga por ${jugador['nombre']}', style: const TextStyle(color: Colors.white)),
        content: Text('La liga te ofrece ${CurrencyFormatter.format(monto)} por este jugador. ¿Deseas aceptar?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _rechazarOfertaLiga(oferta['id']);
            },
            child: const Text('Rechazar', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _aceptarOfertaLiga(oferta['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
            child: const Text('Vender'),
          ),
        ],
      ),
    );
  }

  Widget _buildLigaActionBox(Map<String, dynamic> oferta) {
    return Container(
      margin: const EdgeInsets.only(top: 0, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.yellow.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border.all(color: Colors.yellow.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _rechazarOfertaLiga(oferta['id']),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
              child: const Text('Rechazar', style: TextStyle(color: Colors.white70)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _aceptarOfertaLiga(oferta['id']),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black),
              child: const Text('Vender a Liga', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _aceptarOfertaLiga(String ofertaId) async {
    try {
      setState(() => _isLoading = true);
      final response = await Supabase.instance.client.rpc('aceptar_oferta_liga_mercado', params: {'p_oferta_id': ofertaId});
      
      if (response['success'] == true) {
        await _loadInitialData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta a la liga realizada con éxito!')));
        }
      } else {
        throw response['mensaje'] ?? 'Error desconocido';
      }
    } catch (e) {
      debugPrint('Error al aceptar oferta liga: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rechazarOfertaLiga(String ofertaId) async {
    try {
      setState(() => _isLoading = true);
      await Supabase.instance.client
          .from('ofertas_mercado')
          .update({'estado': 'rechazada'})
          .eq('id', ofertaId);
      
      await _loadInitialData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Oferta de la liga rechazada')));
      }
    } catch (e) {
      debugPrint('Error al rechazar oferta liga: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBid(String pujaId) async {
    try {
      await Supabase.instance.client.from('pujas').delete().eq('id', pujaId);
      _loadInitialData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Puja eliminada con éxito')));
      }
    } catch (e) {
      debugPrint('Error al eliminar puja: $e');
    }
  }

  void _showBidModal(Map<String, dynamic> item, {Map<String, dynamic>? existingBid}) {
    final jugadorMap = item['jugador'] ?? {};
    final jugador = Jugador.fromJson(jugadorMap);
    final marketId = item['id'];
    final requestedPrice = (item['precio_minimo'] as num?)?.toDouble() ?? jugador.precio;
    
    final initialBid = existingBid != null ? (existingBid['monto'] as num).toDouble() : requestedPrice;
    final String initialValue = NumberFormat.decimalPattern('es_ES').format(initialBid.toInt());
    final controller = TextEditingController(text: initialValue);
    final posColor = _getPosColor(jugador.posicion.name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgDark,
      barrierColor: Colors.black.withOpacity(0.8),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentBid = double.tryParse(controller.text.replaceAll('.', '')) ?? 0;
          final bool isSquadFull = _playerCount >= 26;
          final bool isUpdating = existingBid != null;
          final bool isValid = currentBid >= requestedPrice && (isUpdating || !isSquadFull);

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Header
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                'Puja por ${jugador.nombre}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 32),
                        
                        // Player Image
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: posColor.withOpacity(0.4), width: 2),
                            boxShadow: [
                              BoxShadow(color: posColor.withOpacity(0.2), blurRadius: 15, spreadRadius: 2),
                            ],
                          ),
                          child: ClipOval(
                            child: (jugador.fotoUrl != null && jugador.fotoUrl!.isNotEmpty)
                              ? Transform.scale(
                                  scale: 1.4,
                                  child: Image.network(
                                    jugador.fotoUrl!, 
                                    fit: BoxFit.cover, 
                                    alignment: const Alignment(0, -0.3),
                                  ),
                                )
                              : Center(child: Text(jugador.initials, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Info Rows
                        _buildBidInfoRow(Icons.monetization_on_rounded, 'VALOR DE MERCADO', CurrencyFormatter.format(jugador.precio), Colors.yellow),
                        if (isSquadFull && !isUpdating)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Plantilla completa (26/26). No puedes fichar más.',
                              style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: 16),
                        _buildBidInfoRow(Icons.lock_rounded, 'PRECIO SOLICITADO', CurrencyFormatter.format(requestedPrice), AppColors.success),
                        
                        const SizedBox(height: 40),

                        // Input Box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Text('€', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('IMPORTE', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                                    TextField(
                                      controller: controller,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [CurrencyInputFormatter()],
                                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (v) => setModalState(() {}),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  controller.clear();
                                  setModalState(() {});
                                },
                                child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.3), size: 22),
                              ),
                            ],
                          ),
                        ),
                        
                        if (!isValid && controller.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'La puja mínima es de ${CurrencyFormatter.format(requestedPrice)}',
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (isValid && currentBid <= (_presupuesto - _totalPujado + (existingBid != null ? (existingBid['monto'] as num).toDouble() : 0))) 
                      ? () => _placeBid(marketId, currentBid, bidId: existingBid?['id']) 
                      : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      existingBid != null ? 'Editar Puja' : 'Hacer puja',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Tu saldo: ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CurrencyFormatter.format(_presupuesto - _totalPujado),
                          style: TextStyle(
                            color: currentBid > (_presupuesto - _totalPujado) ? Colors.redAccent : AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (_totalPujado > 0)
                          Text(
                            'Pujado: -${CurrencyFormatter.format(_totalPujado)}',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 10),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBidInfoRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _placeBid(String marketId, double amount, {String? bidId}) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      if (bidId != null) {
        // Actualizar puja existente
        await supabase.from('pujas').update({
          'monto': amount,
          'fecha': DateTime.now().toIso8601String(),
        }).eq('id', bidId);
      } else {
        // Insertar nueva puja
        await supabase.from('pujas').insert({
          'mercado_id': marketId,
          'usuario_id': user.id,
          'monto': amount,
        });
      }

      if (mounted) {
        Navigator.pop(context); // Cerrar modal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(bidId != null 
              ? 'Puja actualizada a ${CurrencyFormatter.format(amount)}' 
              : 'Puja de ${CurrencyFormatter.format(amount)} realizada correctamente'),
          ),
        );
        _loadInitialData(); // Recargar para mostrar en operaciones
      }
    } catch (e) {
      debugPrint('Error al realizar puja: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al procesar la puja.')),
        );
      }
    }
  }
}


class _PremiumMarketTile extends StatefulWidget {
  final Map<String, dynamic> jugador;
  final double? precioSalida;
  final DateTime? fechaFin;
  final bool isOwner;
  final String? ownerName;
  final String? actionLabel;
  final int? bidCount;
  final VoidCallback? onAction;
  const _PremiumMarketTile({
    required this.jugador, 
    this.precioSalida, 
    this.fechaFin,
    this.isOwner = false,
    this.ownerName,
    this.actionLabel,
    this.bidCount,
    this.onAction,
  });

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
    final dynamic rawEquipo = jugador['equipo_id'];
    final Map<String, dynamic>? equipoData = rawEquipo is Map<String, dynamic> ? rawEquipo : null;
    final precio = widget.precioSalida ?? (jugador['precio'] as num?)?.toDouble() ?? 0.0;
    final valor = (jugador['precio'] as num?)?.toDouble() ?? 0.0;
    final pos = jugador['posicion'] ?? '';
    final color = _getPosColor(pos);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 160,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Fila 1: Pos, Nombre y Puntos (PFSY)
                  Row(
                    children: [
                      _PosTag(pos: pos, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          jugador['nombre'] ?? '', 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const Text('PTS ', style: TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.bold)),
                      Text('${jugador['puntos_totales'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  
                  // Fila 2: Equipo y Estatus "Alineable"
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (equipoData?['escudo_url'] != null)
                        Image.network(equipoData!['escudo_url'], width: 12, height: 12),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          equipoData?['nombre'] ?? 'LALIGA', 
                          style: const TextStyle(color: Colors.white54, fontSize: 9),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Alineable', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  
                  // Tiempo restante (DINÁMICO)
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.white30, size: 12),
                      const SizedBox(width: 3),
                      Text(_timeLeft, style: const TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),

                  if (widget.ownerName != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 11),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            widget.ownerName!, 
                            style: const TextStyle(color: AppColors.primary, fontSize: 8, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const Spacer(),
                  
                  // Fila inferior: Valor, Precio y Botón de Fichar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Valor: ${CurrencyFormatter.format(valor as num)}', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 8)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                CurrencyFormatter.format(precio as num), 
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (widget.bidCount != null)
                               Padding(
                                 padding: const EdgeInsets.only(bottom: 4),
                                 child: Text(
                                   'Pujas: ${widget.bidCount}',
                                   style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
                                   overflow: TextOverflow.ellipsis,
                                 ),
                               ),
                            ElevatedButton(
                              onPressed: widget.onAction ?? () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.actionLabel == 'Acciones' ? AppColors.primary : (widget.isOwner ? AppColors.accent : AppColors.success),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                widget.actionLabel ?? (widget.isOwner ? 'Quitar' : 'Fichar'),
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
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
    final dynamic rawEquipo = jugador['equipo_id'];
    final Map<String, dynamic>? equipoData = rawEquipo is Map<String, dynamic> ? rawEquipo : null;
    final equipoNombre = equipoData?['nombre'] ?? 'Sin equipo';
    final precio = (jugador['precio'] as num?)?.toDouble() ?? 0.0;
    final pos = jugador['posicion'] ?? '';
    final color = _getPosColor(pos);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 110,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.2), Colors.transparent],
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
              ),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
            ),
            child: (jugador['foto_url'] != null && (jugador['foto_url'] as String).isNotEmpty)
                ? Center(
                    child: Container(
                      width: 54, height: 54,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
                      child: ClipOval(
                        child: Transform.scale(
                          scale: 1.4,
                          child: Image.network(
                            jugador['foto_url'],
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.3),
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(child: Icon(Icons.account_circle, size: 60, color: Colors.white.withOpacity(0.1))),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _PosTag(pos: pos, color: color),
                      const SizedBox(width: 8),
                      Expanded(child: Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                      const Text('PTS ', style: TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.bold)),
                      Text('${jugador['puntos_totales'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (equipoData?['escudo_url'] != null) ...[
                        Image.network(equipoData!['escudo_url'], width: 12, height: 12),
                        const SizedBox(width: 4),
                      ],
                      Expanded(child: Text(equipoNombre, style: const TextStyle(color: Colors.white54, fontSize: 10), overflow: TextOverflow.ellipsis)),
                      if (ownerName != null) ...[
                        const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 10),
                        const SizedBox(width: 2),
                        Text(ownerName!, style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      CurrencyFormatter.format(precio), 
                      style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 16)
                    ),
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
