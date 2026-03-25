import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/main_scaffold.dart';
import '../../../../core/utils/currency_formatter.dart';
 
bool _isClauseBlockedGlobal(Map<String, dynamic> p) {
  final now = DateTime.now();
  final abiertaHastaStr = p['clausula_abierta_hasta'];
  if (abiertaHastaStr != null) {
    final date = DateTime.tryParse(abiertaHastaStr);
    if (date != null && date.isAfter(now)) return true;
  }
  final fechaFichStr = p['fecha_fichaje'];
  if (fechaFichStr != null) {
    final date = DateTime.tryParse(fechaFichStr);
    if (date != null && date.add(const Duration(days: 14)).isAfter(now)) return true;
  }
  return false;
}

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
  double _totalPujado = 0;
  int _myPlayerCount = 0;
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

      // 1b. Cargar mi equipo para count
      final myTeam = await Supabase.instance.client
          .from('equipos_fantasy')
          .select('id')
          .eq('user_id', myId)
          .eq('liga_id', _ligaId!)
          .maybeSingle();

      double totalPujado = 0;
      int myPC = 0;
      if (myTeam != null) {
        final countRes = await Supabase.instance.client
            .from('equipo_fantasy_jugadores')
            .select('id')
            .eq('equipo_fantasy_id', myTeam['id']);
        myPC = countRes.length;

        // 1c. Cargar pujas activas (tanto en mercado como p2p)
        final p2pPujas = await Supabase.instance.client
            .from('ofertas_jugadores')
            .select('monto')
            .eq('comprador_id', myId)
            .eq('liga_id', _ligaId!)
            .eq('estado', 'pendiente');
        
        final marketPujas = await Supabase.instance.client
            .from('pujas')
            .select('monto, mercado!inner(liga_id)')
            .eq('usuario_id', myId)
            .eq('mercado.liga_id', _ligaId!);

        for (var f in p2pPujas) { totalPujado += (f['monto'] as num).toDouble(); }
        for (var f in marketPujas) { totalPujado += (f['monto'] as num).toDouble(); }
      }

      // 1d. Cargar mis ofertas activas a ESTE rival específico para marcar los jugadores
      final myExistingOffers = await Supabase.instance.client
          .from('ofertas_jugadores')
          .select('jugador_id, monto')
          .eq('comprador_id', myId)
          .eq('vendedor_id', widget.userId)
          .eq('liga_id', _ligaId!)
          .eq('estado', 'pendiente');
      
      final Map<String, double> offersMap = {};
      for (var o in myExistingOffers) {
        offersMap[o['jugador_id'].toString()] = (o['monto'] as num).toDouble();
      }

      // 2. Cargar el equipo del rival
      final equipoRival = await Supabase.instance.client
          .from('equipos_fantasy')
          .select('id')
          .eq('user_id', widget.userId)
          .eq('liga_id', _ligaId!)
          .single();

      final jugadoresRel = await Supabase.instance.client
          .from('equipo_fantasy_jugadores')
          .select('es_titular, orden_suplente, jugador_id, clausula, clausula_abierta_hasta, fecha_fichaje, jugadores(*, equipos_reales(nombre, escudo_url), estadisticas_jugadores(puntos_calculados, created_at))')
          .eq('equipo_fantasy_id', equipoRival['id']);

      // 1. Contar ocurrencias de nombres para detectar duplicados en esta pantalla
      final nameCounts = <String, int>{};
      for (var rel in jugadoresRel) {
        final nombre = rel['jugadores']?['nombre'] ?? '';
        nameCounts[nombre] = (nameCounts[nombre] ?? 0) + 1;
      }

      final List<Map<String, dynamic>> loadedPlayers = [];
      for (var rel in jugadoresRel) {
        final j = rel['jugadores'];
        final String primerNombre = j['nombre'] ?? '';
        final String apellidos = j['apellidos'] ?? '';
        // Si hay duplicados en esta pantalla, mostramos apellido
        final String displayName = (nameCounts[primerNombre] ?? 0) > 1 
            ? '$primerNombre $apellidos'.trim() 
            : primerNombre;

        loadedPlayers.add({
          'id': j['id'],
          'name': displayName,
          'pos': j['posicion'],
          'precio': j['precio'],
          'clausula': rel['clausula'] ?? (j['precio'] * 1.25),
          'clausula_abierta_hasta': rel['clausula_abierta_hasta'],
          'fecha_fichaje': rel['fecha_fichaje'],
          'es_titular': rel['es_titular'],
          'foto_url': j['foto_url'],
          'equipo_nombre': j['equipos_reales']?['nombre'],
          'puntos_totales': j['puntos'] ?? 0,
          'has_offer': offersMap.containsKey(j['id'].toString()),
          'my_offer_amount': offersMap[j['id'].toString()],
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
          _myPlayerCount = myPC;
          _totalPujado = totalPujado;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rival team: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showActionModal(Map<String, dynamic> p) {
    final bool isBlocked = _isClauseBlockedGlobal(p);
    final bool canClausulazo = !isBlocked;
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
                  _InfoBox(label: 'Precio', value: '${NumberFormat.decimalPattern('es_ES').format((p['precio'] as num).toInt())}€'),
                  const SizedBox(width: 12),
                  _InfoBox(label: 'Cláusula', value: '${NumberFormat.decimalPattern('es_ES').format(clausula.toInt())}€', color: Colors.yellow),
                ],
              ),
              const SizedBox(height: 24), // Reducido de 32
              AppButton(
                label: p['has_offer'] == true ? 'EDITAR OFERTA (${NumberFormat.decimalPattern('es_ES').format(p['my_offer_amount']?.toInt() ?? 0)}€)' : 'Hacer Oferta',
                backgroundColor: p['has_offer'] == true ? Colors.blueAccent : AppColors.primary,
                labelColor: p['has_offer'] == true ? Colors.white : Colors.black,
                icon: Icon(p['has_offer'] == true ? Icons.edit_note_rounded : Icons.history_edu_rounded, color: p['has_offer'] == true ? Colors.white : Colors.black),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showOfferDialog(p);
                },
              ),
              const SizedBox(height: 12),
              AppButton(
                label: canClausulazo ? 'CLAUSULAZO' : 'CLÁUSULA BLOQUEADA',
                backgroundColor: canClausulazo ? AppColors.error : Colors.blueGrey,
                icon: Icon(canClausulazo ? Icons.flash_on_rounded : Icons.lock_rounded, color: Colors.white),
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

  Color _getPosColor(String? pos) {
    if (pos == null) return Colors.grey;
    switch (pos.toLowerCase()) {
      case 'portero': return AppColors.goalkeeper;
      case 'defensa': return AppColors.defender;
      case 'centrocampista': return AppColors.midfielder;
      case 'delantero': return AppColors.forward;
      default: return AppColors.primary;
    }
  }

  void _showOfferDialog(Map<String, dynamic> p) {
    final double marketPrice = (p['precio'] as num).toDouble();
    final String initialValue = NumberFormat.decimalPattern('es_ES').format(marketPrice.toInt());
    final controller = TextEditingController(text: initialValue);
    final posColor = _getPosColor(p['pos']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Background handle by Container
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final double amountValue = double.tryParse(controller.text.replaceAll('.', '')) ?? 0;
          final bool isSquadFull = _myPlayerCount >= 26;
          final double saldoDisponible = _presupuestoPropio - _totalPujado;
          final bool isValid = amountValue >= marketPrice && !isSquadFull && amountValue <= saldoDisponible;

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              color: AppColors.bgDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
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
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 24),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                'Puja por ${p['name']}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Player Photo
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: posColor.withOpacity(0.5), width: 3),
                            boxShadow: [
                              BoxShadow(color: posColor.withOpacity(0.3), blurRadius: 15, spreadRadius: 2),
                            ],
                          ),
                          child: ClipOval(
                            child: (p['foto_url'] != null && p['foto_url'].toString().isNotEmpty)
                              ? Transform.scale(
                                  scale: 1.4,
                                  child: Image.network(
                                    p['foto_url'], 
                                    fit: BoxFit.cover, 
                                    alignment: const Alignment(0, -0.3),
                                  ),
                                )
                              : Center(child: Text(p['name'][0], style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold))),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Stats Card (Circle style)
                        _buildRowStat(
                          Icons.monetization_on_rounded, 
                          'VALOR DE MERCADO', 
                          '${NumberFormat.decimalPattern('es_ES').format(marketPrice.toInt())}€',
                          Colors.yellow
                        ),
                        const SizedBox(height: 20),
                        _buildRowStat(
                          Icons.lock_rounded, 
                          'PRECIO SOLICITADO', 
                          '${NumberFormat.decimalPattern('es_ES').format(marketPrice.toInt())}€',
                          AppColors.success
                        ),

                        const SizedBox(height: 16),

                        // Custom Input Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(child: Text('€', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w900))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('IMPORTE', style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                    TextField(
                                      controller: controller,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                      onChanged: (val) {
                                        if (val.isEmpty) return;
                                        final clean = val.replaceAll('.', '');
                                        final numVal = int.tryParse(clean) ?? 0;
                                        final formatted = NumberFormat.decimalPattern('es_ES').format(numVal);
                                        controller.value = TextEditingValue(
                                          text: formatted,
                                          selection: TextSelection.collapsed(offset: formatted.length),
                                        );
                                        setModalState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white30, size: 20),
                                onPressed: () {
                                  controller.text = '0';
                                  setModalState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // My Balance Footer Check
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isValid ? () => _submitOffer(p, amountValue) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: Text(
                          isValid ? 'Hacer puja' : (isSquadFull ? 'PLANTILLA LLENA' : 'PUJA INVÁLIDA'),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Tu saldo: ', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                        Text('${CurrencyFormatter.format(_presupuestoPropio)}', style: const TextStyle(color: AppColors.success, fontSize: 14, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRowStat(IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
      ],
    );
  }

  Future<void> _submitOffer(Map<String, dynamic> p, double monto) async {
    final double marketPrice = (p['precio'] as num?)?.toDouble() ?? 0.0;
    
    if (monto < marketPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La oferta debe ser igual o mayor al valor de mercado')),
      );
      return;
    }

    if (monto > _presupuestoPropio) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tienes presupuesto suficiente')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('ofertas_jugadores').upsert({
        'liga_id': _ligaId,
        'jugador_id': p['id'],
        'vendedor_id': widget.userId,
        'comprador_id': myId,
        'monto': monto,
        'estado': 'pendiente',
        'create_at': DateTime.now().toIso8601String(),
      }, onConflict: 'liga_id,jugador_id,comprador_id,vendedor_id');
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
        content: Text('¿Estás seguro de pagar ${NumberFormat.decimalPattern('es_ES').format(clausula.toInt())}€ por ${p['name']}? El fichaje será inmediato.'),
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
            Text('Presupuesto: ${NumberFormat.decimalPattern('es_ES').format(_presupuestoPropio.toInt())}€', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
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
                if (player['has_offer'] == true)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blueAccent.withOpacity(0.5))),
                      child: const Text('OFERTA ENVIADA', style: TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ),
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
        trailing: _buildClauseStatus(player),
      ),
    );
  }

  Widget _buildClauseStatus(Map<String, dynamic> player) {
    final clausulaAmt = player['clausula'];
    if (clausulaAmt == null) return const SizedBox.shrink();
    final double amount = (clausulaAmt as num).toDouble();
    
    final bool isBlocked = _isClauseBlockedGlobal(player);
    Duration? remaining;
    if (isBlocked) {
      final abiertaHastaStr = player['clausula_abierta_hasta'];
      final fechaFichStr = player['fecha_fichaje'];
      DateTime? limit;
      if (abiertaHastaStr != null) limit = DateTime.tryParse(abiertaHastaStr);
      if (limit == null && fechaFichStr != null) {
        final f = DateTime.tryParse(fechaFichStr);
        if (f != null) limit = f.add(const Duration(days: 14));
      }
      if (limit != null) {
        remaining = limit.difference(DateTime.now());
      }
    }

    final icon = isBlocked ? Icons.lock_rounded : Icons.lock_open_rounded;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'V. Merc.: ${CurrencyFormatter.format((player['precio'] as num))}',
          style: const TextStyle(color: Colors.white38, fontSize: 7.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.redAccent, size: 11),
            const SizedBox(width: 4),
            Text(
              CurrencyFormatter.format(amount),
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ],
        ),
        if (isBlocked && remaining != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time_rounded, color: Colors.redAccent, size: 9),
              const SizedBox(width: 3),
              Text(
                remaining.inDays > 0 
                  ? '${remaining.inDays}d ${remaining.inHours % 24}h' 
                  : '${remaining.inHours}h ${remaining.inMinutes % 60}m',
                style: const TextStyle(color: Colors.redAccent, fontSize: 8.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
      ],
    );
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
