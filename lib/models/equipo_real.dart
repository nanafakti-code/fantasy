enum Division { segundaAndaluza, primeraAndaluza, divisionHonor }

extension DivisionX on Division {
  String get label {
    switch (this) {
      case Division.segundaAndaluza:
        return '2ª Andaluza';
      case Division.primeraAndaluza:
        return '1ª Andaluza';
      case Division.divisionHonor:
        return 'División de Honor';
    }
  }
}

class EquipoReal {
  final String id;
  final String nombre;
  final String? escudoUrl;
  final Division division;
  final String? ciudad;

  const EquipoReal({
    required this.id,
    required this.nombre,
    this.escudoUrl,
    required this.division,
    this.ciudad,
  });

  factory EquipoReal.fromJson(Map<String, dynamic> json) => EquipoReal(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        escudoUrl: json['escudo_url'] as String?,
        division: Division.values.firstWhere(
          (e) =>
              e.name ==
              (json['division'] as String? ?? 'segunda_andaluza')
                  .replaceAll('_', ''),
          orElse: () => Division.segundaAndaluza,
        ),
        ciudad: json['ciudad'] as String?,
      );
}
