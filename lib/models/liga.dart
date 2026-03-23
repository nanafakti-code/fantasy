enum LigaEstado { pendiente, activa, finalizada }

extension LigaEstadoX on LigaEstado {
  String get label {
    switch (this) {
      case LigaEstado.pendiente:
        return 'Pendiente';
      case LigaEstado.activa:
        return 'Activa';
      case LigaEstado.finalizada:
        return 'Finalizada';
    }
  }
}

class Liga {
  final String id;
  final String nombre;
  final String? creadorId;
  final String codigoInvitacion;
  final LigaEstado estado;
  final int maxParticipantes;
  final double presupuestoInicial;
  final int jornadaActual;
  final DateTime createdAt;

  // Datos enriquecidos (join)
  final int? totalParticipantes;

  const Liga({
    required this.id,
    required this.nombre,
    this.creadorId,
    required this.codigoInvitacion,
    required this.estado,
    required this.maxParticipantes,
    required this.presupuestoInicial,
    required this.jornadaActual,
    required this.createdAt,
    this.totalParticipantes,
  });

  factory Liga.fromJson(Map<String, dynamic> json) => Liga(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        creadorId: json['creador_id'] as String?,
        codigoInvitacion: json['codigo_invitacion'] as String,
        estado: LigaEstado.values.firstWhere(
          (e) => e.name == (json['estado'] as String? ?? 'pendiente'),
          orElse: () => LigaEstado.pendiente,
        ),
        maxParticipantes: (json['max_participantes'] as num?)?.toInt() ?? 20,
        presupuestoInicial:
            (json['presupuesto_inicial'] as num?)?.toDouble() ?? 50000000,
        jornadaActual: (json['jornada_actual'] as num?)?.toInt() ?? 1,
        createdAt: DateTime.parse(json['created_at'] as String),
        totalParticipantes: (json['total_participantes'] as num?)?.toInt(),
      );
}
