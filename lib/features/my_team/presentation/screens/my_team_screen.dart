import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../widgets/pitch_view.dart';

class MyTeamScreen extends ConsumerStatefulWidget {
  const MyTeamScreen({super.key});

  @override
  ConsumerState<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends ConsumerState<MyTeamScreen> {
  bool _isLoading = true;
  String _formacion = '4-4-2';
  double _presupuesto = 0;
  int _puntosTotales = 0;
  int _posicion = 0;
  int _totalLigasUser = 0;
  
  List<Map<String, dynamic>> _titulares = [];
  List<Map<String, dynamic>> _suplentes = [];

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Obtener la liga activa y presupuesto del usuario
      final membership = await Supabase.instance.client
          .from('usuarios_ligas')
          .select('presupuesto, puntos_totales, posicion, liga_id, ligas(jornada_actual)')
          .eq('user_id', user.id)
          .maybeSingle();

      if (membership == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final ligaId = membership['liga_id'];
      
      // 2. Obtener el equipo fantasy
      final equipo = await Supabase.instance.client
          .from('equipos_fantasy')
          .select('id, formacion')
          .eq('user_id', user.id)
          .eq('liga_id', ligaId)
          .maybeSingle();

      if (equipo == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final equipoId = equipo['id'];
      final formacion = equipo['formacion'] ?? '4-4-2';

      // 3. Obtener los jugadores del equipo
      final jugadoresRel = await Supabase.instance.client
          .from('equipo_fantasy_jugadores')
          .select('es_titular, jugador_id, jugadores(*, equipos_reales(nombre, logo_url))')
          .eq('equipo_fantasy_id', equipoId);

      final List<Map<String, dynamic>> tits = [];
      final List<Map<String, dynamic>> sups = [];

      for (var rel in jugadoresRel) {
        final j = rel['jugadores'] as Map<String, dynamic>;
        final playerData = {
          'id': j['id'],
          'name': j['nombre'],
          'initials': _getInitials(j['nombre']),
          'pos': _mapPos(j['posicion']),
          'pts': 0, // TODO: Cargar puntos reales de la jornada
          'es_titular': rel['es_titular'],
        };
        
        if (rel['es_titular'] == true) {
          tits.add(playerData);
        } else {
          sups.add(playerData);
        }
      }

      if (mounted) {
        setState(() {
          _presupuesto = (membership['presupuesto'] as num?)?.toDouble() ?? 0;
          _puntosTotales = (membership['puntos_totales'] as num?)?.toInt() ?? 0;
          _posicion = membership['posicion'] ?? 0;
          _formacion = formacion;
          _titulares = tits;
          _suplentes = sups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getInitials(String name) {
    List<String> parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _mapPos(String? dbPos) {
    switch (dbPos) {
      case 'portero': return 'PT';
      case 'defensa': return 'DF';
      case 'centrocampista': return 'CC';
      case 'delantero': return 'DL';
      default: return '??';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadTeamData,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildTeamStats(context),
                        const SizedBox(height: 8),
                        PitchView(players: _titulares, formacion: _formacion),
                        const SizedBox(height: 16),
                        _buildBenchSection(context),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/market'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text(
          'Gestionar',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Mi Equipo',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded, color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  _formacion,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamStats(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              label: 'Puntos totales',
              value: '$_puntosTotales pts',
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatChip(
              label: 'Presupuesto',
              value: '${(_presupuesto / 1000000).toStringAsFixed(1)}M',
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatChip(
              label: 'Posición',
              value: '$_posicionº',
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenchSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Text(
                  'Suplentes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_suplentes.isEmpty)
             const Center(child: Text('No hay suplentes', style: TextStyle(color: AppColors.textMuted)))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _suplentes
                    .map((p) => Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: _BenchPlayerTile(
                            initials: p['initials'], 
                            name: p['name'], 
                            pts: p['pts'] ?? 0
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BenchPlayerTile extends StatelessWidget {
  final String initials;
  final String name;
  final int pts;

  const _BenchPlayerTile({required this.initials, required this.name, required this.pts});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            shape: BoxShape.circle,
            border: Border.all(
              color: pts > 0 ? AppColors.primary : const Color(0xFF1E293B),
              width: pts > 0 ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 60,
          child: Text(
            name,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$pts pts',
          style: TextStyle(
            color: pts > 0 ? AppColors.success : AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
