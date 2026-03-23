class Partido {
  final String id;
  final String jornadaId;
  final String equipoLocalId;
  final String equipoVisitanteId;
  final String? equipoLocalNombre;
  final String? equipoVisitanteNombre;
  final int golesLocal;
  final int golesVisitante;
  final DateTime? fechaHora;
  final String estado; // programado, en_curso, finalizado

  const Partido({
    required this.id,
    required this.jornadaId,
    required this.equipoLocalId,
    required this.equipoVisitanteId,
    this.equipoLocalNombre,
    this.equipoVisitanteNombre,
    required this.golesLocal,
    required this.golesVisitante,
    this.fechaHora,
    required this.estado,
  });

  bool get esFinalizado => estado == 'finalizado';
  bool get estaEnCurso => estado == 'en_curso';
  String get resultado => '$golesLocal - $golesVisitante';

  factory Partido.fromJson(Map<String, dynamic> json) {
    final local = json['equipo_local'] as Map<String, dynamic>?;
    final visita = json['equipo_visitante'] as Map<String, dynamic>?;
    return Partido(
      id: json['id'] as String,
      jornadaId: json['jornada_id'] as String,
      equipoLocalId: json['equipo_local_id'] as String,
      equipoVisitanteId: json['equipo_visit_id'] as String,
      equipoLocalNombre: local?['nombre'] as String?,
      equipoVisitanteNombre: visita?['nombre'] as String?,
      golesLocal: (json['goles_local'] as num?)?.toInt() ?? 0,
      golesVisitante: (json['goles_visitante'] as num?)?.toInt() ?? 0,
      fechaHora: json['fecha_hora'] != null
          ? DateTime.parse(json['fecha_hora'] as String)
          : null,
      estado: json['estado'] as String? ?? 'programado',
    );
  }
}
