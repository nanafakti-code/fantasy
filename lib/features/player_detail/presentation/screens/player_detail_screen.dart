import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../models/models.dart';

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

      // 2. Cargar estadísticas recientes (últimos 5 partidos)
      // Necesitamos unir con partidos y jornadas para el número de jornada
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
            // Navegar por el JSON de la unión
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implementar lógica de puja/fichaje
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lógica de fichaje en desarrollo...'))
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Fichar',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
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
                ),
                const SizedBox(height: 4),
                Text(
                  jugador.equipoNombre?.toUpperCase() ?? 'EQUIPO LIBRE',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    PositionChip(label: jugador.posicion.fullLabel, color: posColor),
                    const SizedBox(width: 8),
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
