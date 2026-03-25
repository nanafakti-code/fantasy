import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class PitchView extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final String formacion;
  final bool showPoints;
  final Function(String pos, Map<String, dynamic>? currentPlayer)? onSlotTap;

  const PitchView({
    super.key, 
    required this.players,
    required this.formacion,
    this.showPoints = false,
    this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    // Parsear formación (ej: "4-4-2")
    final parts = formacion.split('-');
    final numDefs = int.parse(parts[0]);
    final numMids = int.parse(parts[1]);
    final numFwds = int.parse(parts[2]);

    // Agrupar jugadores por posición
    final gksIn = players.where((p) => p['pos'] == 'PT').toList();
    final defsIn = players.where((p) => p['pos'] == 'DF').toList();
    final midsIn = players.where((p) => p['pos'] == 'CC').toList();
    final fwdsIn = players.where((p) => p['pos'] == 'DL').toList();

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
              child: const SizedBox(height: 520, width: double.infinity),
            ),
            SizedBox(
              height: 520,
              child: Column(
                children: [
                  const SizedBox(height: 25),
                  // Delanteros
                  _FormationRow(count: numFwds, players: fwdsIn, defaultPos: 'DL', onSlotTap: onSlotTap, showPoints: showPoints),
                  const Spacer(),
                  // Medios
                  _FormationRow(count: numMids, players: midsIn, defaultPos: 'CC', onSlotTap: onSlotTap, showPoints: showPoints),
                  const Spacer(),
                  // Defensas
                  _FormationRow(count: numDefs, players: defsIn, defaultPos: 'DF', onSlotTap: onSlotTap, showPoints: showPoints),
                  const Spacer(),
                  // Portero
                  _FormationRow(count: 1, players: gksIn, defaultPos: 'PT', onSlotTap: onSlotTap, showPoints: showPoints),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormationRow extends StatelessWidget {
  final int count;
  final List<Map<String, dynamic>> players;
  final String defaultPos;
  final bool showPoints;
  final Function(String pos, Map<String, dynamic>? currentPlayer)? onSlotTap;

  const _FormationRow({
    required this.count, 
    required this.players,
    required this.defaultPos,
    this.showPoints = false,
    this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(count, (index) {
        if (index < players.length) {
          return _PlayerTile(player: players[index], onSlotTap: onSlotTap, showPoints: showPoints);
        } else {
          return _EmptySlot(pos: defaultPos, onSlotTap: onSlotTap);
        }
      }),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final String pos;
  final Function(String pos, Map<String, dynamic>? currentPlayer)? onSlotTap;
  const _EmptySlot({required this.pos, this.onSlotTap});

  Color get _color {
    if (pos == 'PT') return AppColors.goalkeeper;
    if (pos == 'DF') return AppColors.defender;
    if (pos == 'CC') return AppColors.midfielder;
    return AppColors.forward;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSlotTap?.call(pos, null),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: _color.withOpacity(0.4),
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Center(
              child: Icon(Icons.add, color: _color.withOpacity(0.5), size: 24),
            ),
          ),
          const SizedBox(height: 24), // Espacio para el nombre vacío
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final Map<String, dynamic> player;
  final bool showPoints;
  final Function(String pos, Map<String, dynamic>? currentPlayer)? onSlotTap;

  const _PlayerTile({required this.player, this.showPoints = false, this.onSlotTap});

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
      onTap: () {
        if (onSlotTap != null) {
          onSlotTap!(player['pos'] as String, player);
        } else {
          context.push('/player/${player['id']}');
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Hero(
            tag: 'player-${player['id']}',
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _posColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: _posColor, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: _posColor.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (player['foto_url'] != null && (player['foto_url'] as String).isNotEmpty)
                        ClipOval(
                          child: Transform.scale(
                            scale: 1.4,
                            child: Image.network(
                              player['foto_url'],
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -0.3),
                              errorBuilder: (c, e, s) => Center(
                                child: Text(
                                  player['initials'] as String,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          player['initials'] as String,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 60, // Fixed width to match player circle and prevent row overflow
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              player['name'] as String,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          if (showPoints) ...[
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
