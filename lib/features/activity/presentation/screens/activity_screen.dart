import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/main_scaffold.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _feedItems = [];
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadActivityData();
  }

  Future<void> _loadActivityData() async {
    final ligaId = ref.read(selectedLeagueIdProvider);
    if (ligaId == null) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      // 1. Cargar TRANSFERENCIAS (MERCADO)
      final transfersResponse = await Supabase.instance.client
          .from('transferencias')
          .select('*, jugador:jugador_id(nombre, foto_url), comprador:comprador_id(username), vendedor:vendedor_id(username)')
          .eq('liga_id', ligaId)
          .order('fecha', ascending: false)
          .limit(20);

      // 2. Cargar RECOMPENSAS (PUNTOS JORNADA)
      final rewardsResponse = await Supabase.instance.client
          .from('puntos_jornada')
          .select('*, usuario:user_id(username), jornada:jornada_id(numero)')
          .eq('liga_id', ligaId)
          .order('calculated_at', ascending: false)
          .limit(20);

      final List<Map<String, dynamic>> items = [];

      // Procesar Transferencias
      final List<dynamic> transfersList = transfersResponse as List<dynamic>;
      for (var t in transfersList) {
        final Map<String, dynamic> data = t as Map<String, dynamic>;
        final compradorName = data['comprador']?['username'] ?? 'LA LIGA';
        final vendedorName = data['vendedor']?['username'] ?? 'LA LIGA';
        final jugadorName = data['jugador']?['nombre'] ?? 'Jugador';
        final precio = (data['precio'] as num?)?.toDouble() ?? 0.0;
        final fecha = DateTime.parse(data['fecha']);

        items.add({
          'tipo': 'mercado',
          'fecha': fecha,
          'user': compradorName, 
          'titulo': 'Operación de Mercado',
          'mensaje': compradorName != 'LA LIGA'
              ? '$compradorName ha comprado a $jugadorName de $vendedorName por ${_currencyFormat.format(precio)}'
              : '$vendedorName ha vendido a $jugadorName a LA LIGA por ${_currencyFormat.format(precio)}',
          'jugador_foto': data['jugador']?['foto_url'],
          'icono': Icons.shopping_cart_rounded,
          'color': AppColors.primary,
        });
      }

      // Procesar Recompensas
      final List<dynamic> rewardsList = rewardsResponse as List<dynamic>;
      for (var r in rewardsList) {
        final Map<String, dynamic> data = r as Map<String, dynamic>;
        final userName = data['usuario']?['username'] ?? 'Míster';
        final jornadaNum = data['jornada']?['numero'] ?? 0;
        final puntos = (data['puntos'] as num?)?.toDouble() ?? 0.0;
        final saldoGanado = puntos * 10000; 
        final fecha = DateTime.parse(data['calculated_at']);

        items.add({
          'tipo': 'recompensa',
          'fecha': fecha,
          'user': userName,
          'titulo': 'Recompensa',
          'mensaje': 'En la jornada $jornadaNum, $userName ha ganado ${_currencyFormat.format(saldoGanado)}',
          'icono': Icons.emoji_events_rounded,
          'color': AppColors.accent,
        });
      }

      // Ordenar todo por fecha inversa
      items.sort((a, b) => (b['fecha'] as DateTime).compareTo(a['fecha']));

      if (mounted) {
        setState(() {
          _feedItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ERROR Activity: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('ACTIVIDAD', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadActivityData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _feedItems.isEmpty
                ? Center(child: Text('Sin actividad reciente', style: TextStyle(color: Colors.white.withOpacity(0.3))))
                : RefreshIndicator(
                    onRefresh: _loadActivityData,
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _feedItems.length,
                      itemBuilder: (ctx, i) {
                        final item = _feedItems[i];
                        return _buildActivityTile(item);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (item['color'] as Color).withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (item['color'] as Color).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(item['icono'] as IconData, color: item['color'] as Color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item['titulo'].toString().toUpperCase(),
                      style: TextStyle(
                        color: item['color'] as Color,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      _formatDate(item['fecha'] as DateTime),
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item['mensaje'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${dt.day}/${dt.month}';
  }
}
