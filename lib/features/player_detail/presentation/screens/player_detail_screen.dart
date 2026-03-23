import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../models/models.dart';

// Mock
Jugador _mockJugador(String id) => Jugador(
      id: id,
      nombre: 'Iñaki',
      apellidos: 'Gómez Barrera',
      posicion: Posicion.delantero,
      precio: 4500000,
      activo: true,
      equipoNombre: 'Montequinto FC',
      puntosPromedio: 9.8,
    );

final _mockStats = [
  {'jornada': 'J8', 'goles': 2, 'amarillas': 0, 'rojas': 0, 'titular': true, 'pts': 12},
  {'jornada': 'J7', 'goles': 1, 'amarillas': 1, 'rojas': 0, 'titular': true, 'pts': 9},
  {'jornada': 'J6', 'goles': 0, 'amarillas': 0, 'rojas': 0, 'titular': true, 'pts': 2},
  {'jornada': 'J5', 'goles': 0, 'amarillas': 1, 'rojas': 0, 'titular': false, 'pts': 0},
  {'jornada': 'J4', 'goles': 3, 'amarillas': 0, 'rojas': 0, 'titular': true, 'pts': 18},
];

class PlayerDetailScreen extends ConsumerWidget {
  final String jugadorId;
  const PlayerDetailScreen({super.key, required this.jugadorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jugador = _mockJugador(jugadorId);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPlayerCard(context, jugador),
                      const SizedBox(height: 24),
                      _buildStatsTable(context),
                      const SizedBox(height: 24),
                      _buildPointsChart(context),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Detalle del jugador',
              style: Theme.of(context).textTheme.headlineLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(BuildContext context, Jugador jugador) {
    return AppCard(
      child: Row(
        children: [
          Hero(
            tag: 'player-${jugador.id}',
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.forward.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.forward, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.forward.withOpacity(0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    jugador.initials,
                    style: const TextStyle(
                      color: AppColors.forward,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    ),
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
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      jugador.equipoNombre ?? 'Sin equipo',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        PositionChip(
                          label: jugador.posicion.fullLabel,
                          color: AppColors.forward,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            jugador.precioFormateado,
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: jugador.puntosPromedio ?? 0),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOut,
                    builder: (ctx, val, _) => Text(
                      val.toStringAsFixed(1),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Text(
                    'avg pts',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
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
        Text('Estadísticas recientes',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Color(0xFF1E293B))),
                ),
                child: Row(
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
              // Filas
              ..._mockStats.map(
                (s) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: Color(0xFF0D1016))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          s['jornada'] as String,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${s['goles']}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: (s['goles'] as int) > 0
                                ? AppColors.success
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${s['amarillas']}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: (s['amarillas'] as int) > 0
                                ? AppColors.warning
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${s['rojas']}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: (s['rojas'] as int) > 0
                                ? AppColors.error
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Icon(
                          (s['titular'] as bool)
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: (s['titular'] as bool)
                              ? AppColors.success
                              : AppColors.textMuted,
                          size: 16,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${s['pts']}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: (s['pts'] as int) > 0
                                ? AppColors.primary
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPointsChart(BuildContext context) {
    final pts = _mockStats.map((s) => (s['pts'] as int).toDouble()).toList();
    final maxPts = pts.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Evolución de puntos',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(pts.length, (i) {
              final barH = maxPts > 0 ? (pts[i] / maxPts) * 80 : 4.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${pts[i].toInt()}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: barH),
                        duration: Duration(milliseconds: 400 + i * 100),
                        curve: Curves.easeOut,
                        builder: (ctx, val, _) => Container(
                          height: val,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _mockStats[i]['jornada'] as String,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
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

  const _TableHeader(this.text,
      {required this.flex, this.alignRight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
      ),
    );
  }
}
