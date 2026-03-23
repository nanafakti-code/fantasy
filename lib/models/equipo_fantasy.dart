import 'jugador.dart';

class EquipoFantasyJugador {
  final String id;
  final String equipoFantasyId;
  final String jugadorId;
  final bool esTitular;
  final int? ordenSuplente;
  final Jugador? jugador;

  const EquipoFantasyJugador({
    required this.id,
    required this.equipoFantasyId,
    required this.jugadorId,
    required this.esTitular,
    this.ordenSuplente,
    this.jugador,
  });

  factory EquipoFantasyJugador.fromJson(Map<String, dynamic> json) =>
      EquipoFantasyJugador(
        id: json['id'] as String,
        equipoFantasyId: json['equipo_fantasy_id'] as String,
        jugadorId: json['jugador_id'] as String,
        esTitular: json['es_titular'] as bool? ?? false,
        ordenSuplente: (json['orden_suplente'] as num?)?.toInt(),
        jugador: json['jugadores'] != null
            ? Jugador.fromJson(json['jugadores'] as Map<String, dynamic>)
            : null,
      );
}

class EquipoFantasy {
  final String id;
  final String userId;
  final String ligaId;
  final String? nombre;
  final String formacion;
  final DateTime createdAt;
  final List<EquipoFantasyJugador> jugadores;

  const EquipoFantasy({
    required this.id,
    required this.userId,
    required this.ligaId,
    this.nombre,
    required this.formacion,
    required this.createdAt,
    this.jugadores = const [],
  });

  List<EquipoFantasyJugador> get titulares =>
      jugadores.where((j) => j.esTitular).toList();

  List<EquipoFantasyJugador> get suplentes =>
      jugadores.where((j) => !j.esTitular).toList();

  factory EquipoFantasy.fromJson(Map<String, dynamic> json) => EquipoFantasy(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        ligaId: json['liga_id'] as String,
        nombre: json['nombre'] as String?,
        formacion: json['formacion'] as String? ?? '4-3-3',
        createdAt: DateTime.parse(json['created_at'] as String),
        jugadores: (json['equipo_fantasy_jugadores'] as List<dynamic>? ?? [])
            .map((j) =>
                EquipoFantasyJugador.fromJson(j as Map<String, dynamic>))
            .toList(),
      );
}
