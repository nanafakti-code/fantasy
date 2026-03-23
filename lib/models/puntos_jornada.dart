class PuntosJornada {
  final String id;
  final String userId;
  final String ligaId;
  final String jornadaId;
  final double puntos;
  final DateTime? calculatedAt;

  const PuntosJornada({
    required this.id,
    required this.userId,
    required this.ligaId,
    required this.jornadaId,
    required this.puntos,
    this.calculatedAt,
  });

  factory PuntosJornada.fromJson(Map<String, dynamic> json) => PuntosJornada(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        ligaId: json['liga_id'] as String,
        jornadaId: json['jornada_id'] as String,
        puntos: (json['puntos'] as num?)?.toDouble() ?? 0,
        calculatedAt: json['calculated_at'] != null
            ? DateTime.parse(json['calculated_at'] as String)
            : null,
      );
}

class ClasificacionEntry {
  final String userId;
  final String username;
  final String? avatarUrl;
  final double puntosTotal;
  final int posicion;
  final double? puntosUltimaJornada;

  const ClasificacionEntry({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.puntosTotal,
    required this.posicion,
    this.puntosUltimaJornada,
  });

  factory ClasificacionEntry.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuarios'] as Map<String, dynamic>?;
    return ClasificacionEntry(
      userId: json['user_id'] as String,
      username: usuario?['username'] as String? ?? 'Jugador',
      avatarUrl: usuario?['avatar_url'] as String?,
      puntosTotal: (json['puntos_totales'] as num?)?.toDouble() ?? 0,
      posicion: (json['posicion'] as num?)?.toInt() ?? 0,
      puntosUltimaJornada:
          (json['puntos_ultima_jornada'] as num?)?.toDouble(),
    );
  }

  String get initials {
    final parts = username.split(' ');
    if (parts.length > 1) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return username.substring(0, 2).toUpperCase();
  }
}
