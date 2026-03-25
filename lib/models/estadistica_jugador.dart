class EstadisticaJugador {
  final String id;
  final String jugadorId;
  final String partidoId;
  final bool convocado;
  final bool titular;
  final int minutosJugados;
  final int goles;
  final int asistencias;
  final int tarjetasAmarillas;
  final int tarjetasRojas;
  final int golesPropia;
  final bool porteriaCero;
  final double puntosCalculados;

  const EstadisticaJugador({
    required this.id,
    required this.jugadorId,
    required this.partidoId,
    required this.convocado,
    required this.titular,
    required this.minutosJugados,
    required this.goles,
    required this.asistencias,
    required this.tarjetasAmarillas,
    required this.tarjetasRojas,
    required this.golesPropia,
    required this.porteriaCero,
    required this.puntosCalculados,
  });

  factory EstadisticaJugador.fromJson(Map<String, dynamic> json) =>
      EstadisticaJugador(
        id: json['id'] as String,
        jugadorId: json['jugador_id'] as String,
        partidoId: json['partido_id'] as String,
        convocado: json['convocado'] as bool? ?? false,
        titular: json['titular'] as bool? ?? false,
        minutosJugados: (json['minutos_jugados'] as num?)?.toInt() ?? 0,
        goles: (json['goles'] as num?)?.toInt() ?? 0,
        asistencias: (json['asistencias'] as num?)?.toInt() ?? 0,
        tarjetasAmarillas:
            (json['tarjetas_amarillas'] as num?)?.toInt() ?? 0,
        tarjetasRojas: (json['tarjetas_rojas'] as num?)?.toInt() ?? 0,
        golesPropia: (json['goles_propia'] as num?)?.toInt() ?? 0,
        porteriaCero: json['porteria_cero'] as bool? ?? false,
        puntosCalculados:
            (json['puntos_calculados'] as num?)?.toDouble() ?? 0,
      );
}
