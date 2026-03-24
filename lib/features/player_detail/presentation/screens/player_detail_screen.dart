import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../models/models.dart';
import '../../../../core/widgets/main_scaffold.dart';
import '../../../../core/utils/currency_formatter.dart';

class PlayerDetailScreen extends ConsumerStatefulWidget {
  final String jugadorId;
  const PlayerDetailScreen({super.key, required this.jugadorId});

  @override
  ConsumerState<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends ConsumerState<PlayerDetailScreen> {
  bool _isLoading = true;
  Jugador? _jugador;
  List<Map<String, dynamic>> _stats = [];
  bool _isOwner = false;
  double? _clausula;
  String? _equipoFantasyId;
  String? _marketId;
  double? _precioMinimoMercado;
  double _userBudget = 0;
  double _totalPujado = 0;
  int _playerCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPlayerData();
  }

  Future<void> _loadPlayerData() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);
      
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      final ligaId = ref.read(selectedLeagueIdProvider);

      // 1. Cargar datos del jugador con su equipo real
      final playerResponse = await supabase
          .from('jugadores')
          .select('*, equipos_reales(*)')
          .eq('id', widget.jugadorId)
          .maybeSingle();

      if (playerResponse == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. Comprobar si es propiedad del usuario y si está en el mercado
      if (user != null && ligaId != null) {
        final equipoFantasy = await supabase
            .from('equipos_fantasy')
            .select('id')
            .eq('user_id', user.id)
            .eq('liga_id', ligaId)
            .maybeSingle();
        
        if (equipoFantasy != null) {
          _equipoFantasyId = equipoFantasy['id'];
          final ownershipResponse = await supabase
              .from('equipo_fantasy_jugadores')
              .select('clausula')
              .eq('equipo_fantasy_id', _equipoFantasyId!)
              .eq('jugador_id', widget.jugadorId)
              .maybeSingle();
          
          if (ownershipResponse != null) {
            _isOwner = true;
            _clausula = (ownershipResponse['clausula'] as num?)?.toDouble();
          }
        }
      }

      // 3. Comprobar si está en el mercado
      if (ligaId != null) {
        final marketResponse = await supabase
            .from('mercado')
            .select('id, precio_minimo')
            .eq('liga_id', ligaId)
            .eq('jugador_id', widget.jugadorId)
            .maybeSingle();
        
        if (marketResponse != null) {
          _marketId = marketResponse['id'];
          _precioMinimoMercado = (marketResponse['precio_minimo'] as num?)?.toDouble();
        }

        // Cargar presupuesto actual
        if (user != null) {
          final budgetResponse = await supabase
              .from('usuarios_ligas')
              .select('presupuesto')
              .eq('user_id', user.id)
              .eq('liga_id', ligaId)
              .single();
          _userBudget = (budgetResponse['presupuesto'] as num).toDouble();

          // 1b. Cargar total pujado para esta liga
          final bidsResponse = await supabase
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
          _totalPujado = totalBids;

          // 1c. Contar jugadores en plantilla
          final userEF = await supabase.from('equipos_fantasy').select('id').eq('user_id', user.id).eq('liga_id', ligaId).single();
          final teamResponse = await supabase.from('equipo_fantasy_jugadores').select('id').eq('equipo_fantasy_id', userEF['id']);
          _playerCount = (teamResponse as List).length;
        }
      }

      // 4. Cargar estadísticas recientes (últimos 5 partidos)
      final statsResponse = await supabase
          .from('estadisticas_jugadores')
          .select('''
            *,
            partidos!inner (
              jornada_id,
              jornadas!inner (numero)
            )
          ''')
          .eq('jugador_id', widget.jugadorId)
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _jugador = Jugador.fromJson(playerResponse);
          
          final List rawStats = statsResponse as List;
          _stats = rawStats.map((s) {
            final jornadaNum = s['partidos']?['jornadas']?['numero'] ?? '?';
            return {
              'jornada': 'J$jornadaNum',
              'goles': s['goles'] ?? 0,
              'amarillas': s['tarjetas_amarillas'] ?? 0,
              'rojas': s['tarjetas_rojas'] ?? 0,
              'titular': s['titular'] ?? false,
              'pts': (s['puntos_calculados'] as num?)?.toInt() ?? 0,
            };
          }).toList();
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error en PlayerDetailScreen: $e');
      if (mounted) setState(() => _isLoading = false);
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

    if (_jugador == null) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: AppBar(title: const Text('Ops!')),
        body: const Center(child: Text('No hemos encontrado los datos del jugador', style: TextStyle(color: Colors.white70))),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPlayerCard(context, _jugador!),
                      const SizedBox(height: 24),
                      _buildStatsTable(context),
                      const SizedBox(height: 24),
                      _buildPointsChart(context),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: (_isOwner || _marketId != null) ? FloatingActionButton.extended(
        onPressed: _isOwner ? _showActionsMenu : _showBidModal,
        backgroundColor: _isOwner ? AppColors.accent : AppColors.primary,
        foregroundColor: Colors.black,
        icon: Icon(_isOwner ? Icons.settings_rounded : Icons.gavel_rounded),
        label: Text(
          _isOwner ? 'Acciones' : 'Fichar',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ) : null,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Ficha del Jugador',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(BuildContext context, Jugador jugador) {
    // Color según posición
    Color posColor;
    switch (jugador.posicion) {
      case Posicion.portero: posColor = AppColors.goalkeeper; break;
      case Posicion.defensa: posColor = AppColors.defender; break;
      case Posicion.centrocampista: posColor = AppColors.midfielder; break;
      case Posicion.delantero: posColor = AppColors.forward; break;
    }

    return AppCard(
      child: Row(
        children: [
          Hero(
            tag: 'player-${jugador.id}',
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: posColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: posColor, width: 2),
                  boxShadow: [
                    BoxShadow(color: posColor.withOpacity(0.2), blurRadius: 15, spreadRadius: 1),
                  ],
                ),
                child: (jugador.fotoUrl != null && jugador.fotoUrl!.isNotEmpty)
                    ? Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: ClipOval(
                          child: Transform.scale(
                            scale: 1.4,
                            child: Image.network(
                              jugador.fotoUrl!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -0.3),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          jugador.initials,
                          style: TextStyle(color: posColor, fontWeight: FontWeight.w800, fontSize: 24),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jugador.nombreCompleto,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  jugador.equipoNombre?.toUpperCase() ?? 'EQUIPO LIBRE',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PositionChip(label: jugador.posicion.fullLabel, color: posColor),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        jugador.precioFormateado,
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                    if (_clausula != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'CL: ${CurrencyFormatter.format(_clausula!)}',
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '${(jugador.puntosPromedio ?? 0).toStringAsFixed(1)}',
                style: const TextStyle(color: AppColors.primary, fontSize: 32, fontWeight: FontWeight.w900),
              ),
              const Text('avg pts', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTable(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Estadísticas recientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('${_stats.length} partidos', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        if (_stats.isEmpty)
          const AppCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No hay estadísticas registradas para este jugador', style: TextStyle(color: AppColors.textMuted)),
              ),
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
                  child: const Row(
                    children: [
                      _TableHeader('Jornada', flex: 2),
                      _TableHeader('⚽', flex: 1),
                      _TableHeader('🟨', flex: 1),
                      _TableHeader('🟥', flex: 1),
                      _TableHeader('Titular', flex: 2),
                      _TableHeader('Pts', flex: 1, alignRight: true),
                    ],
                  ),
                ),
                ..._stats.map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF0F172A)))),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(s['jornada'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      Expanded(child: Text('${s['goles']}', textAlign: TextAlign.center, style: TextStyle(color: (s['goles'] > 0) ? AppColors.success : AppColors.textMuted, fontWeight: FontWeight.bold))),
                      Expanded(child: Text('${s['amarillas']}', textAlign: TextAlign.center, style: TextStyle(color: (s['amarillas'] > 0) ? AppColors.warning : AppColors.textMuted))),
                      Expanded(child: Text('${s['rojas']}', textAlign: TextAlign.center, style: TextStyle(color: (s['rojas'] > 0) ? AppColors.error : AppColors.textMuted))),
                      Expanded(
                        flex: 2,
                        child: Icon(
                          s['titular'] ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: s['titular'] ? AppColors.success : AppColors.textMuted,
                          size: 16,
                        ),
                      ),
                      Expanded(child: Text('${s['pts']}', textAlign: TextAlign.right, style: TextStyle(color: (s['pts'] > 0) ? AppColors.primary : AppColors.textMuted, fontWeight: FontWeight.w900, fontSize: 16))),
                    ],
                  ),
                )),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPointsChart(BuildContext context) {
    if (_stats.length < 2) return const SizedBox.shrink();

    // Invertir para mostrar de más viejo a más nuevo en el gráfico
    final reversedStats = _stats.reversed.toList();
    final maxPts = reversedStats.map((s) => s['pts'] as int).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Evolución de puntos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        AppCard(
          child: SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: reversedStats.map((s) {
                final barHeight = maxPts > 0 ? (s['pts'] as int) / maxPts * 80 : 5.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${s['pts']}', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: barHeight),
                          duration: const Duration(milliseconds: 600),
                          builder: (ctx, val, _) => Container(
                            height: val,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              boxShadow: [
                                BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(s['jornada'], style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  void _showActionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 16),
              child: Text(
                'Acciones de Jugador',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _buildActionItem(
              icon: _marketId != null ? Icons.remove_circle_outline_rounded : Icons.store_rounded,
              label: _marketId != null ? 'Quitar del mercado' : 'Añadir al mercado',
              color: _marketId != null ? Colors.orange : Colors.white,
              onTap: () {
                Navigator.pop(context);
                if (_marketId != null) {
                   _removeFromMarket();
                } else {
                   _addToMarket();
                }
              },
            ),
            _buildActionItem(
              icon: Icons.trending_up_rounded,
              label: 'Subir cláusula',
              onTap: () {
                Navigator.pop(context);
                _raiseClause();
              },
            ),
            _buildActionItem(
              icon: Icons.money_off_rounded,
              label: 'Venta Inmediata',
              subtitle: 'Recibes ${_jugador != null ? CurrencyFormatter.format(_jugador!.precio / 2) : "0€"} (50%)',
              color: Colors.redAccent,
              onTap: () {
                Navigator.pop(context);
                _immediateSale();
              },
            ),
            const Divider(color: Colors.white10, height: 32),
            _buildActionItem(
              icon: Icons.close_rounded,
              label: 'Cerrar',
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: color.withOpacity(0.5), fontSize: 12))
          : null,
      onTap: onTap,
    );
  }

  Future<void> _addToMarket() async {
    try {
      final supabase = Supabase.instance.client;
      final ligaId = ref.read(selectedLeagueIdProvider);
      final user = supabase.auth.currentUser;

      if (ligaId == null || user == null) return;

      // Poner al mercado con precio actual
      final insertResponse = await supabase.from('mercado').insert({
        'liga_id': ligaId,
        'jugador_id': widget.jugadorId,
        'vendedor_id': user.id,
        'precio_minimo': _jugador!.precio,
        'fecha_fin': (DateTime.now().add(const Duration(days: 2))).toIso8601String(),
      }).select('id').single();

      setState(() => _marketId = insertResponse['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jugador añadido al mercado correctamente')),
        );
      }
    } catch (e) {
      debugPrint('Error al añadir al mercado: $e');
    }
  }

  Future<void> _removeFromMarket() async {
    try {
      if (_marketId == null) return;
      final supabase = Supabase.instance.client;
      await supabase.from('mercado').delete().eq('id', _marketId!);

      setState(() => _marketId = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jugador retirado del mercado')),
        );
      }
    } catch (e) {
      debugPrint('Error al quitar del mercado: $e');
    }
  }

  Future<void> _raiseClause() async {
    final controller = TextEditingController(text: (_clausula ?? _jugador!.precio * 1.25).toStringAsFixed(0));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Subir Cláusula', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Introduce el nuevo importe de la cláusula:', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nueva Cláusula',
                prefixText: '€',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final newValue = double.tryParse(controller.text);
              if (newValue != null && newValue > (_clausula ?? 0)) {
                Navigator.pop(context);
                await _updateClause(newValue);
              }
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateClause(double newValue) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('equipo_fantasy_jugadores')
          .update({'clausula': newValue})
          .eq('equipo_fantasy_id', _equipoFantasyId!)
          .eq('jugador_id', widget.jugadorId);

      setState(() => _clausula = newValue);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cláusula actualizada correctamente')),
        );
      }
    } catch (e) {
      debugPrint('Error al actualizar cláusula: $e');
    }
  }

  Future<void> _immediateSale() async {
    final salePrice = _jugador!.precio / 2;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Venta Inmediata', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Estás seguro de vender a ${_jugador!.nombreCompleto} por ${salePrice.toStringAsFixed(0)}€? Esta acción no se puede deshacer.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vender'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final supabase = Supabase.instance.client;
        final ligaId = ref.read(selectedLeagueIdProvider);
        final user = supabase.auth.currentUser;

        if (ligaId == null || user == null) return;

        // 1. Quitar del mercado si estuviera
        if (_marketId != null) {
           await supabase.from('mercado').delete().eq('id', _marketId!);
        }

        // 2. Quitar jugador del equipo
        await supabase
            .from('equipo_fantasy_jugadores')
            .delete()
            .eq('equipo_fantasy_id', _equipoFantasyId!)
            .eq('jugador_id', widget.jugadorId);

        // 2. Sumar dinero al usuario (lo haremos manual si no hay rpc)
        // Obtener presupuesto actual
        final membership = await supabase
            .from('usuarios_ligas')
            .select('presupuesto')
            .eq('user_id', user.id)
            .eq('liga_id', ligaId)
            .single();
        
        final currentBudget = (membership['presupuesto'] as num).toDouble();
        await supabase
            .from('usuarios_ligas')
            .update({'presupuesto': currentBudget + salePrice})
            .eq('user_id', user.id)
            .eq('liga_id', ligaId);

        // 3. Registrar transferencia
        await supabase.from('transferencias').insert({
          'liga_id': ligaId,
          'jugador_id': widget.jugadorId,
          'vendedor_id': user.id,
          'comprador_id': null, // Comprado por "la liga"
          'precio': salePrice,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Jugador vendido correctamente')),
          );
          Navigator.pop(context); // Volver atrás a la plantilla
        }
      } catch (e) {
        debugPrint('Error en venta inmediata: $e');
      }
    }
  }

  Color _getPosColor(Posicion pos) {
    switch (pos) {
      case Posicion.portero: return AppColors.goalkeeper;
      case Posicion.defensa: return AppColors.defender;
      case Posicion.centrocampista: return AppColors.midfielder;
      case Posicion.delantero: return AppColors.forward;
    }
  }

  void _showBidModal() {
    if (_jugador == null) return;
    
    final requestedPrice = (_marketId != null) ? (_precioMinimoMercado ?? _jugador!.precio) : _jugador!.precio;
    final String initialValue = NumberFormat.decimalPattern('es_ES').format(requestedPrice.toInt());
    final controller = TextEditingController(text: initialValue);
    final posColor = _getPosColor(_jugador!.posicion);

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
          final bool isUpdating = (_marketId != null && _totalPujado > 0); // Simplificación
          // Nota: Sería mejor pasar si ya existe una puja por este mercado_id específico.
          final bool isValid = currentBid >= requestedPrice && (!isSquadFull || isUpdating);

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
                                'Puja por ${_jugador!.nombre}',
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
                            child: (_jugador!.fotoUrl != null && _jugador!.fotoUrl!.isNotEmpty)
                              ? Transform.scale(
                                  scale: 1.4,
                                  child: Image.network(
                                    _jugador!.fotoUrl!, 
                                    fit: BoxFit.cover, 
                                    alignment: const Alignment(0, -0.3),
                                  ),
                                )
                              : Center(child: Text(_jugador!.initials, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Info Rows
                        _buildBidInfoRow(Icons.monetization_on_rounded, 'VALOR DE MERCADO', CurrencyFormatter.format(_jugador!.precio), Colors.yellow),
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
                    onPressed: (isValid && currentBid <= _userBudget) 
                      ? () => _placeBid(currentBid) 
                      : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Hacer puja', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          CurrencyFormatter.format(_userBudget - _totalPujado),
                          style: TextStyle(
                            color: currentBid > (_userBudget - _totalPujado) ? Colors.redAccent : AppColors.success,
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

  Future<void> _placeBid(double amount) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null || _marketId == null) return;

      await supabase.from('pujas').insert({
        'mercado_id': _marketId,
        'usuario_id': user.id,
        'monto': amount,
      });

      if (mounted) {
        Navigator.pop(context); // Cerrar modal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Puja de ${CurrencyFormatter.format(amount)} realizada correctamente'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al realizar puja: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al procesar la puja. Inténtalo de nuevo.')),
        );
      }
    }
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  final int flex;
  final bool alignRight;
  const _TableHeader(this.text, {required this.flex, this.alignRight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
      ),
    );
  }
}
