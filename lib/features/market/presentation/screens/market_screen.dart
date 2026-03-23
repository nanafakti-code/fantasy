import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../models/models.dart';

// Mock data para demo
final _mockJugadores = List.generate(
  20,
  (i) {
    final posiciones = [
      Posicion.portero,
      Posicion.defensa,
      Posicion.centrocampista,
      Posicion.delantero
    ];
    final pos = posiciones[i % 4];
    return Jugador(
      id: 'j$i',
      nombre: ['Luis', 'Juan', 'Pedro', 'Carlos', 'Antonio'][i % 5],
      apellidos: ['García', 'Martínez', 'López', 'Ruiz', 'Moreno'][i % 5],
      posicion: pos,
      precio: (1000000 + i * 500000).toDouble(),
      activo: true,
      equipoNombre:
          ['Montequinto FC', 'Los Palacios', 'Alcalá CF', 'Sevilla Sur'][i % 4],
      puntosPromedio: (4 + i * 0.8),
    );
  },
);

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  String _searchQuery = '';
  Posicion? _selectedPosition;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Jugador> get _filteredPlayers {
    return _mockJugadores.where((j) {
      final matchSearch = _searchQuery.isEmpty ||
          j.nombreCompleto
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (j.equipoNombre
                  ?.toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ??
              false);
      final matchPos =
          _selectedPosition == null || j.posicion == _selectedPosition;
      return matchSearch && matchPos;
    }).toList();
  }

  Color _posicionColor(Posicion pos) {
    switch (pos) {
      case Posicion.portero:
        return AppColors.goalkeeper;
      case Posicion.defensa:
        return AppColors.defender;
      case Posicion.centrocampista:
        return AppColors.midfielder;
      case Posicion.delantero:
        return AppColors.forward;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          // Patrón SKILL layouts: Column con Expanded wrapping ListView
          child: Column(
            children: [
              _buildHeader(context),
              _buildBudgetBar(context),
              _buildFilters(),
              // ← EXPANDED requerido por SKILL flutter-building-layouts
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.bgCard,
                  onRefresh: () async =>
                      await Future.delayed(const Duration(seconds: 1)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredPlayers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) =>
                        _PlayerMarketCard(
                      jugador: _filteredPlayers[i],
                      posColor: _posicionColor(_filteredPlayers[i].posicion),
                      onTap: () => _showPlayerSheet(context, _filteredPlayers[i]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Mercado',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetBar(BuildContext context) {
    const budget = 8200000.0;
    const maxBudget = 50000000.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Presupuesto disponible',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '8.2M €',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: budget / maxBudget,
                backgroundColor: AppColors.bgCardLight,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.success),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // Búsqueda
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar jugador o equipo...',
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textMuted, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: AppColors.textMuted, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          // Filtros de posición
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Todos',
                  isSelected: _selectedPosition == null,
                  color: AppColors.primary,
                  onTap: () => setState(() => _selectedPosition = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'PT',
                  isSelected: _selectedPosition == Posicion.portero,
                  color: AppColors.goalkeeper,
                  onTap: () => setState(() => _selectedPosition =
                      _selectedPosition == Posicion.portero
                          ? null
                          : Posicion.portero),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'DF',
                  isSelected: _selectedPosition == Posicion.defensa,
                  color: AppColors.defender,
                  onTap: () => setState(() => _selectedPosition =
                      _selectedPosition == Posicion.defensa
                          ? null
                          : Posicion.defensa),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'CC',
                  isSelected: _selectedPosition == Posicion.centrocampista,
                  color: AppColors.midfielder,
                  onTap: () => setState(() => _selectedPosition =
                      _selectedPosition == Posicion.centrocampista
                          ? null
                          : Posicion.centrocampista),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'DL',
                  isSelected: _selectedPosition == Posicion.delantero,
                  color: AppColors.forward,
                  onTap: () => setState(() => _selectedPosition =
                      _selectedPosition == Posicion.delantero
                          ? null
                          : Posicion.delantero),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPlayerSheet(BuildContext context, Jugador jugador) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PlayerBottomSheet(jugador: jugador),
    );
  }
}

class _PlayerMarketCard extends StatelessWidget {
  final Jugador jugador;
  final Color posColor;
  final VoidCallback onTap;

  const _PlayerMarketCard({
    required this.jugador,
    required this.posColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Row(
          children: [
            Hero(
              tag: 'player-${jugador.id}',
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: posColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: posColor, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    jugador.initials,
                    style: TextStyle(
                      color: posColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jugador.nombreCompleto,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    jugador.equipoNombre ?? 'Sin equipo',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  jugador.precioFormateado,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${jugador.puntosPromedio?.toStringAsFixed(1) ?? '—'} avg',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            PositionChip(
              label: jugador.posicion.label,
              color: posColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF1E293B),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _PlayerBottomSheet extends StatelessWidget {
  final Jugador jugador;
  const _PlayerBottomSheet({required this.jugador});

  Color get _posColor {
    switch (jugador.posicion) {
      case Posicion.portero:
        return AppColors.goalkeeper;
      case Posicion.defensa:
        return AppColors.defender;
      case Posicion.centrocampista:
        return AppColors.midfielder;
      case Posicion.delantero:
        return AppColors.forward;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _posColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _posColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    jugador.initials,
                    style: TextStyle(
                      color: _posColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jugador.nombreCompleto,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      jugador.equipoNombre ?? 'Sin equipo',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    PositionChip(
                      label: jugador.posicion.fullLabel,
                      color: _posColor,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    jugador.precioFormateado,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    '${jugador.puntosPromedio?.toStringAsFixed(1) ?? '—'} pts avg',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Fichar jugador',
            icon: const Icon(Icons.add_rounded, color: Colors.black),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '✅ ${jugador.nombre} fichado correctamente'),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Cancelar'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
