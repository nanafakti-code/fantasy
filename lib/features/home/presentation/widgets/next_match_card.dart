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
      // Si la liga es nueva (jornada 1), la forzamos a 27 para que coincida con el calendario real
      if (_jornadaNum == 1) _jornadaNum = 27; 
      
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

        if (mounted) {
          setState(() {
            _nextMatch = preferredMatch;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(child: Text(m['equipo_local']['nombre'], style: const TextStyle(fontSize: 11), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 8),
                              _SmallShield(url: m['equipo_local']['escudo_url']),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('vs', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              _SmallShield(url: m['equipo_visit']['escudo_url']),
                              const SizedBox(width: 8),
                              Flexible(child: Text(m['equipo_visit']['nombre'], style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppCard(child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppColors.primary))));
    }

    if (_nextMatch == null) return const SizedBox.shrink();

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
                  _MatchMid(),
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
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: team['escudo_url'] != null
                  ? Image.network(
                      team['escudo_url'],
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Center(child: Text('🏟️', style: TextStyle(fontSize: 32))),
                    )
                  : const Center(child: Text('🏟️', style: TextStyle(fontSize: 32))),
            ),
          ),
          const SizedBox(height: 12),
          Text(team['nombre'], 
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _MatchMid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgCardLight, 
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: const Text('VS', 
            style: TextStyle(
              color: AppColors.primary, 
              fontWeight: FontWeight.w900, 
              fontSize: 18,
              letterSpacing: 1,
            )
          ),
        ),
      ],
    );
  }
}

class _SmallShield extends StatelessWidget {
  final String? url;
  const _SmallShield({this.url});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20, height: 20,
      child: (url != null && url!.isNotEmpty)
          ? Image.network(
              url!,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => const Center(child: Text('🏟️', style: TextStyle(fontSize: 10))),
            )
          : const Center(child: Text('🏟️', style: TextStyle(fontSize: 10))),
    );
  }
}
