class Jornada {
  final String id;
  final int numero;
  final String division;
  final DateTime? fechaIni;
  final DateTime? fechaFin;
  final bool cerrada;

  const Jornada({
    required this.id,
    required this.numero,
    required this.division,
    this.fechaIni,
    this.fechaFin,
    required this.cerrada,
  });

  factory Jornada.fromJson(Map<String, dynamic> json) => Jornada(
        id: json['id'] as String,
        numero: (json['numero'] as num).toInt(),
        division: json['division'] as String,
        fechaIni: json['fecha_ini'] != null
            ? DateTime.parse(json['fecha_ini'] as String)
            : null,
        fechaFin: json['fecha_fin'] != null
            ? DateTime.parse(json['fecha_fin'] as String)
            : null,
        cerrada: json['cerrada'] as bool? ?? false,
      );
}
