enum Posicion { portero, defensa, centrocampista, delantero }

extension PosicionX on Posicion {
  String get label {
    switch (this) {
      case Posicion.portero:
        return 'PT';
      case Posicion.defensa:
        return 'DF';
      case Posicion.centrocampista:
        return 'CC';
      case Posicion.delantero:
        return 'DL';
    }
  }

  String get fullLabel {
    switch (this) {
      case Posicion.portero:
        return 'Portero';
      case Posicion.defensa:
        return 'Defensa';
      case Posicion.centrocampista:
        return 'Centrocampista';
      case Posicion.delantero:
        return 'Delantero';
    }
  }
}

class Jugador {
  final String id;
  final String nombre;
  final String? apellidos;
  final String? equipoId;
  final String? equipoNombre;
  final Posicion posicion;
  final int? dorsal;
  final String? fotoUrl;
  final double precio;
  final bool activo;

  // Stats calculadas
  final double? puntosPromedio;
  final int? puntosUltimaJornada;

  const Jugador({
    required this.id,
    required this.nombre,
    this.apellidos,
    this.equipoId,
    this.equipoNombre,
    required this.posicion,
    this.dorsal,
    this.fotoUrl,
    required this.precio,
    required this.activo,
    this.puntosPromedio,
    this.puntosUltimaJornada,
  });

  String get nombreCompleto =>
      apellidos != null ? '$nombre $apellidos' : nombre;

  String get initials {
    final parts = nombreCompleto.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nombre.substring(0, 2).toUpperCase();
  }

  factory Jugador.fromJson(Map<String, dynamic> json) {
    final equipoJson = json['equipos_reales'];
    return Jugador(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      apellidos: json['apellidos'] as String?,
      equipoId: json['equipo_id'] as String?,
      equipoNombre: equipoJson != null ? equipoJson['nombre'] as String? : null,
      posicion: Posicion.values.firstWhere(
        (e) => e.name == (json['posicion'] as String? ?? 'delantero'),
        orElse: () => Posicion.delantero,
      ),
      dorsal: (json['dorsal'] as num?)?.toInt(),
      fotoUrl: json['foto_url'] as String?,
      precio: (json['precio'] as num?)?.toDouble() ?? 1000000,
      activo: json['activo'] as bool? ?? true,
      puntosPromedio: (json['puntos_promedio'] as num?)?.toDouble(),
      puntosUltimaJornada: (json['puntos_ultima_jornada'] as num?)?.toInt(),
    );
  }

  String get precioFormateado {
    if (precio >= 1000000) {
      return '${(precio / 1000000).toStringAsFixed(1)}M';
    }
    return '${(precio / 1000).toStringAsFixed(0)}K';
  }
}
