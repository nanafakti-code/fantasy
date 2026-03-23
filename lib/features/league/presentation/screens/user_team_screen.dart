import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/main_scaffold.dart';

class UserTeamScreen extends ConsumerStatefulWidget {
  final String userId;
  final String username;

  const UserTeamScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  ConsumerState<UserTeamScreen> createState() => _UserTeamScreenState();
}

class _UserTeamScreenState extends ConsumerState<UserTeamScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _jugadores = [];
  double _presupuestoPropio = 0;
  String? _ligaId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      _ligaId = ref.read(selectedLeagueIdProvider);

      if (myId == null || _ligaId == null) return;

      // 1. Cargar mi presupuesto
      final myMembership = await Supabase.instance.client
          .from('usuarios_ligas')
          .select('presupuesto')
          .eq('user_id', myId)
          .eq('liga_id', _ligaId!)
          .single();
      _presupuestoPropio = (myMembership['presupuesto'] as num?)?.toDouble() ?? 0;

      // 2. Cargar el equipo del rival
      final equipoRival = await Supabase.instance.client
          .from('equipos_fantasy')
          .select('id')
          .eq('user_id', widget.userId)
          .eq('liga_id', _ligaId!)
          .single();

      final jugadoresRel = await Supabase.instance.client
          .from('equipo_fantasy_jugadores')
          .select('es_titular, orden_suplente, jugador_id, clausula, clausula_abierta_hasta, jugadores(*, equipos_reales(nombre, escudo_url), estadisticas_jugadores(puntos_calculados, created_at))')
          .eq('equipo_fantasy_id', equipoRival['id']);

      final List<Map<String, dynamic>> loadedPlayers = [];
      for (var rel in jugadoresRel) {
        final j = rel['jugadores'];
        loadedPlayers.add({
          'id': j['id'],
          'name': j['nombre'],
          'pos': j['posicion'],
          'precio': j['precio'],
          'clausula': rel['clausula'] ?? (j['precio'] * 1.25),
          'clausula_abierta_hasta': rel['clausula_abierta_hasta'],
          'es_titular': rel['es_titular'],
          'foto_url': j['foto_url'],
          'equipo_nombre': j['equipos_reales']?['nombre'],
          'puntos_totales': j['puntos'] ?? 0,
          'ultimos_puntos': (j['estadisticas_jugadores'] as List?)
                  ?.map((s) => (s['puntos_calculados'] as num).toInt())
                  .toList()
                  .reversed
                  .take(5)
                  .toList() ??
              [],
        });
      }

      if (mounted) {
        // Ordenar por posicion
        loadedPlayers.sort((a, b) {
          int getPriority(String pos) {
            if (pos == 'portero') return 0;
            if (pos == 'defensa') return 1;
            if (pos == 'centrocampista') return 2;
            if (pos == 'delantero') return 3;
            return 4;
          }
          return getPriority(a['pos'] as String).compareTo(getPriority(b['pos'] as String));
        });

        setState(() {
          _jugadores = loadedPlayers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rival team: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showActionModal(Map<String, dynamic> p) {
    final now = DateTime.now();
    final abiertaHastaStr = p['clausula_abierta_hasta'];
    final DateTime? abiertaHasta = abiertaHastaStr != null ? DateTime.parse(abiertaHastaStr) : null;
    final bool canClausulazo = abiertaHasta != null && now.isAfter(abiertaHasta);
    final double clausula = (p['clausula'] as num).toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32), // Más padding abajo para evitar cortes
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                    ),
                    child: p['foto_url'] != null
                        ? ClipOval(
                            child: Transform.scale(
                              scale: 1.4,
                              child: Image.network(
                                p['foto_url'],
                                fit: BoxFit.cover,
                                alignment: const Alignment(0, -0.3),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              p['name'][0],
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(p['equipo_nombre'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20), // Reducido de 24
              Row(
                children: [
                  _InfoBox(label: 'Precio', value: '${(p['precio'] / 1000000).toStringAsFixed(1)}M'),
                  const SizedBox(width: 12),
                  _InfoBox(label: 'Cláusula', value: '${(clausula / 1000000).toStringAsFixed(1)}M', color: AppColors.accent),
                ],
              ),
              const SizedBox(height: 24), // Reducido de 32
              AppButton(
                label: 'Hacer Oferta',
                icon: const Icon(Icons.history_edu_rounded, color: Colors.black),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showOfferDialog(p);
                },
              ),
              const SizedBox(height: 12),
              AppButton(
                label: canClausulazo ? 'CLAUSULAZO' : 'CLÁUSULA BLOQUEADA',
                backgroundColor: canClausulazo ? AppColors.error : Colors.grey,
                icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
                onPressed: canClausulazo 
                  ? () {
                      Navigator.pop(ctx);
                      _confirmClausulazo(p);
                    }
                  : null,
              ),
              if (!canClausulazo)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: Text(
                      'Este jugador tiene la cláusula bloqueada actualmente.',
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOfferDialog(Map<String, dynamic> p) {
    final controller = TextEditingController(text: (p['precio']).toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Oferta por ${p['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Cuánto quieres ofrecer por este jugador?', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                prefixText: '€ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final monto = double.tryParse(controller.text) ?? 0;
              if (monto <= 0) return;
              Navigator.pop(ctx);
              _submitOffer(p, monto);
            },
            child: const Text('ENVIAR OFERTA', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOffer(Map<String, dynamic> p, double monto) async {
    if (monto > _presupuestoPropio) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes presupuesto suficiente')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('ofertas_jugadores').insert({
        'liga_id': _ligaId,
        'jugador_id': p['id'],
        'vendedor_id': widget.userId,
        'comprador_id': myId,
        'monto': monto,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Oferta enviada con éxito')));
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error submit offer: $e');
      setState(() => _isLoading = false);
    }
  }

  void _confirmClausulazo(Map<String, dynamic> p) {
    final double clausula = (p['clausula'] as num).toDouble();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Confirmar Clausulazo'),
        content: Text('¿Estás seguro de pagar ${(clausula / 1000000).toStringAsFixed(1)}M por ${p['name']}? El fichaje será inmediato.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _executeClausulazo(p);
            },
            child: const Text('SÍ, FICHAR', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeClausulazo(Map<String, dynamic> p) async {
    setState(() => _isLoading = true);
    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      final res = await Supabase.instance.client.rpc('ejecutar_clausulazo', params: {
        'p_jugador_id': p['id'],
        'p_vendedor_id': widget.userId,
        'p_comprador_id': myId,
        'p_liga_id': _ligaId,
      });

      if (res['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'])));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Jugador fichado con éxito!')));
        context.go('/my-team');
      }
    } catch (e) {
      debugPrint('Error execution clausulazo: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Equipo de ${widget.username}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Presupuesto: ${(_presupuestoPropio / 1000000).toStringAsFixed(1)}M', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        backgroundColor: AppColors.bgDark,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _jugadores.length,
              itemBuilder: (context, index) {
                final p = _jugadores[index];
                return _PlayerRivalTile(
                  player: p,
                  onTap: () => _showActionModal(p),
                );
              },
            ),
      ),
    );
  }
}

class _PlayerRivalTile extends StatelessWidget {
  final Map<String, dynamic> player;
  final VoidCallback onTap;

  const _PlayerRivalTile({required this.player, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double price = (player['precio'] as num).toDouble();
    final double clausula = (player['clausula'] as num).toDouble();

    final rawPos = player['pos'] ?? '';
    final pos = rawPos == 'portero' ? 'PT' :
                rawPos == 'defensa' ? 'DF' :
                rawPos == 'centrocampista' ? 'CC' :
                rawPos == 'delantero' ? 'DL' : rawPos;

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
        onTap: onTap,
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withOpacity(0.5)),
          ),
          child: (player['foto_url'] != null && (player['foto_url'] as String).isNotEmpty)
              ? ClipOval(
                  child: Transform.scale(
                    scale: 1.4,
                    child: Image.network(
                      player['foto_url'],
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.3),
                    ),
                  ),
                )
              : Center(child: Text(player['name'][0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ),
        title: Text(player['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$pos • ${player['equipo_nombre']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                  child: Text('${player['puntos_totales']} pts', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                if (player['ultimos_puntos'] != null && (player['ultimos_puntos'] as List).isNotEmpty)
                  ...((player['ultimos_puntos'] as List).map((pts) => Padding(
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
              'V. Merc.: ${(price / 1000000).toStringAsFixed(1)}M',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
            ),
            Text(
              'Cláusula: ${(clausula / 1000000).toStringAsFixed(1)}M',
              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 11),
            ),
            _buildClauseCooldown(player['clausula_abierta_hasta']),
          ],
        ),
      ),
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

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoBox({required this.label, required this.value, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
