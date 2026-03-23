import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class PitchView extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final String formacion;

  const PitchView({
    super.key, 
    required this.players,
    required this.formacion,
  });

  @override
  Widget build(BuildContext context) {
    // Agrupar jugadores por posición
    final gks = players.where((p) => p['pos'] == 'PT').toList();
    final defs = players.where((p) => p['pos'] == 'DF').toList();
    final mids = players.where((p) => p['pos'] == 'CC').toList();
    final fwds = players.where((p) => p['pos'] == 'DL').toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
            CustomPaint(
              painter: _PitchPainter(),
              child: const SizedBox(height: 480, width: double.infinity),
            ),
            SizedBox(
              height: 480,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Delanteros
                  _PlayerRow(players: fwds),
                  const Spacer(),
                  // Medios
                  _PlayerRow(players: mids),
                  const Spacer(),
                  // Defensas
                  _PlayerRow(players: defs),
                  const Spacer(),
                  // Portero
                  _PlayerRow(players: gks),
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

  const _PlayerRow({required this.players});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: players.map((p) => _PlayerTile(player: p)).toList(),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final Map<String, dynamic> player;

  const _PlayerTile({required this.player});

  Color get _posColor {
    switch (player['pos'] as String) {
      case 'PT': return AppColors.goalkeeper;
      case 'DF': return AppColors.defender;
      case 'CC': return AppColors.midfielder;
      case 'DL': return AppColors.forward;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pts = player['pts'] as int? ?? 0;
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
                width: 48,
                height: 48,
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
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              player['name'] as String,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: pts > 0 ? AppColors.success.withOpacity(0.8) : Colors.black45,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$pts pts',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
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

    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 50, paint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.15, size.height * 0.78, size.width * 0.7, size.height * 0.22), paint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.15, 0, size.width * 0.7, size.height * 0.22), paint);
  }

  @override
  bool shouldRepaint(_PitchPainter oldDelegate) => false;
}
