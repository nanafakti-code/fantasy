import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

// Data mock para demo
const _mockPlayers = {
  'portero': [
    {'id': 'p1', 'initials': 'JM', 'name': 'J. Miguel', 'pts': 8, 'pos': 'PT'},
  ],
  'defensa': [
    {'id': 'd1', 'initials': 'RM', 'name': 'R. Mora', 'pts': 12, 'pos': 'DF'},
    {'id': 'd2', 'initials': 'AG', 'name': 'A. García', 'pts': 6, 'pos': 'DF'},
    {'id': 'd3', 'initials': 'PL', 'name': 'P. López', 'pts': 4, 'pos': 'DF'},
    {'id': 'd4', 'initials': 'MH', 'name': 'M. Heredia', 'pts': 2, 'pos': 'DF'},
  ],
  'centrocampista': [
    {'id': 'c1', 'initials': 'LV', 'name': 'L. Vega', 'pts': 14, 'pos': 'CC'},
    {'id': 'c2', 'initials': 'JS', 'name': 'J. Soria', 'pts': 8, 'pos': 'CC'},
    {'id': 'c3', 'initials': 'CR', 'name': 'C. Ruiz', 'pts': 6, 'pos': 'CC'},
  ],
  'delantero': [
    {'id': 'dl1', 'initials': 'IG', 'name': 'I. Gómez', 'pts': 16, 'pos': 'DL'},
    {'id': 'dl2', 'initials': 'NB', 'name': 'N. Bellido', 'pts': 12, 'pos': 'DL'},
    {'id': 'dl3', 'initials': 'FF', 'name': 'F. Fuentes', 'pts': 4, 'pos': 'DL'},
  ],
};

class PitchView extends StatelessWidget {
  const PitchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // Campo de fútbol verde
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1B5E20),
            Color(0xFF2E7D32),
            Color(0xFF1B5E20),
            Color(0xFF2E7D32),
            Color(0xFF1B5E20),
            Color(0xFF2E7D32),
          ],
          stops: [0.0, 0.16, 0.33, 0.5, 0.66, 0.83],
        ),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Líneas del campo
            CustomPaint(
              painter: _PitchPainter(),
              child: const SizedBox(height: 480, width: double.infinity),
            ),
            // Jugadores
            SizedBox(
              height: 480,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _PlayerRow(
                    players: _mockPlayers['delantero']!,
                    context: context,
                  ),
                  const Spacer(),
                  _PlayerRow(
                    players: _mockPlayers['centrocampista']!,
                    context: context,
                  ),
                  const Spacer(),
                  _PlayerRow(
                    players: _mockPlayers['defensa']!,
                    context: context,
                  ),
                  const Spacer(),
                  _PlayerRow(
                    players: _mockPlayers['portero']!,
                    context: context,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final BuildContext context;

  const _PlayerRow({required this.players, required this.context});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: players
          .map((p) => _PlayerTile(player: p))
          .toList(),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final Map<String, dynamic> player;

  const _PlayerTile({required this.player});

  Color get _posColor {
    switch (player['pos'] as String) {
      case 'PT':
        return AppColors.goalkeeper;
      case 'DF':
        return AppColors.defender;
      case 'CC':
        return AppColors.midfielder;
      case 'DL':
        return AppColors.forward;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pts = player['pts'] as int;
    return GestureDetector(
      onTap: () => context.push('/player/${player['id']}'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Hero(
            tag: 'player-${player['id']}',
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _posColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: _posColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _posColor.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    player['initials'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              player['name'] as String,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: pts > 0
                  ? AppColors.success.withOpacity(0.8)
                  : Colors.black45,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$pts pts',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Línea central
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Círculo central
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      50,
      paint,
    );

    // Área grande local (abajo)
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.15,
        size.height * 0.78,
        size.width * 0.7,
        size.height * 0.22,
      ),
      paint,
    );

    // Área grande visitante (arriba)
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.15,
        0,
        size.width * 0.7,
        size.height * 0.22,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_PitchPainter oldDelegate) => false;
}
