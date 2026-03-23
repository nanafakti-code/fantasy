import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class NextMatchCard extends StatefulWidget {
  final String? ligaId;
  const NextMatchCard({super.key, this.ligaId});

  @override
  State<NextMatchCard> createState() => _NextMatchCardState();
}

class _NextMatchCardState extends State<NextMatchCard> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _isLoading = true;
  Map<String, dynamic>? _nextMatch;
  List<dynamic> _allJornadaMatches = [];
  int _jornadaNum = 27;

  @override
  void initState() {
    super.initState();
    _fetchNextMatch();
  }

  Future<void> _fetchNextMatch() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Obtener liga id y jornada actual
      String? lId = widget.ligaId;
      if (lId == null) {
        final membership = await Supabase.instance.client
            .from('usuarios_ligas')
            .select('liga_id')
            .eq('user_id', user.id)
            .maybeSingle();
        if (membership != null) lId = membership['liga_id'];
      }

      if (lId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final leagueData = await Supabase.instance.client
          .from('ligas')
          .select('jornada_actual, division')
          .eq('id', lId)
          .single();
      
      _jornadaNum = leagueData['jornada_actual'];
      final division = leagueData['division'];

      // 2. Obtener la ID de la jornada
      final jornadaObj = await Supabase.instance.client
          .from('jornadas')
          .select('id')
          .eq('numero', _jornadaNum)
          .eq('division', division)
          .single();

      // 3. Cargar TODOS los partidos de esta jornada
      final matches = await Supabase.instance.client
          .from('partidos')
          .select('*, equipo_local:equipo_local_id(nombre, escudo_url), equipo_visit:equipo_visit_id(nombre, escudo_url)')
          .eq('jornada_id', jornadaObj['id'])
          .order('fecha_hora', ascending: true);

      if (matches.isNotEmpty) {
        _allJornadaMatches = matches;
        
        // Elegimos como "principal" el del Chipiona o el primero de la lista
        var preferredMatch = matches.firstWhere(
          (m) => m['equipo_local']['nombre'].toString().contains('CHIPIONA') || 
                 m['equipo_visit']['nombre'].toString().contains('CHIPIONA'),
          orElse: () => matches.first
        );

        final DateTime matchTime = DateTime.parse(preferredMatch['fecha_hora']);
        final now = DateTime.now();
        
        if (mounted) {
          setState(() {
            _nextMatch = preferredMatch;
            _remaining = matchTime.isAfter(now) ? matchTime.difference(now) : Duration.zero;
            _isLoading = false;
          });
          _startTimer();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining.inSeconds > 0) {
        if (mounted) setState(() => _remaining -= const Duration(seconds: 1));
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showAllMatches(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Partidos Jornada $_jornadaNum', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _allJornadaMatches.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                itemBuilder: (ctx, i) {
                  final m = _allJornadaMatches[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(m['equipo_local']['nombre'], style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('vs', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(child: Text(m['equipo_visit']['nombre'], style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppCard(child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppColors.primary))));
    }

    if (_nextMatch == null) return const SizedBox.shrink();

    final h = _pad(_remaining.inHours);
    final m = _pad(_remaining.inMinutes.remainder(60));
    final s = _pad(_remaining.inSeconds.remainder(60));

    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Próximo partido - Jornada $_jornadaNum',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _TeamSide(team: _nextMatch!['equipo_local']),
                  _CountdownMid(h: h, m: m, s: s),
                  _TeamSide(team: _nextMatch!['equipo_visit']),
                ],
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => _showAllMatches(context),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Ver todos los partidos de la jornada', 
                style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamSide extends StatelessWidget {
  final Map<String, dynamic> team;
  const _TeamSide({required this.team});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.bgCardLight, shape: BoxShape.circle),
            child: const Center(child: Text('🏟️', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(height: 8),
          Text(team['nombre'], 
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _CountdownMid extends StatelessWidget {
  final String h, m, s;
  const _CountdownMid({required this.h, required this.m, required this.s});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: AppColors.bgCardLight, borderRadius: BorderRadius.circular(12)),
          child: const Text('VS', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Unit(v: h, l: 'h'),
            const Text(' : ', style: TextStyle(color: Colors.white24)),
            _Unit(v: m, l: 'm'),
            const Text(' : ', style: TextStyle(color: Colors.white24)),
            _Unit(v: s, l: 's'),
          ],
        ),
      ],
    );
  }
}

class _Unit extends StatelessWidget {
  final String v, l;
  const _Unit({required this.v, required this.l});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(v, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 15)),
      Text(l, style: const TextStyle(color: AppColors.textMuted, fontSize: 8)),
    ]);
  }
}
