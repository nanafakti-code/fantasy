import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import 'admin_match_points_screen.dart';

class AdminCalendarScreen extends StatefulWidget {
  const AdminCalendarScreen({super.key});

  @override
  State<AdminCalendarScreen> createState() => _AdminCalendarScreenState();
}

class _AdminCalendarScreenState extends State<AdminCalendarScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _jornadas = [];
  List<Map<String, dynamic>> _partidos = [];
  String? _selectedJornadaId;

  @override
  void initState() {
    super.initState();
    _loadJornadas();
  }

  Future<void> _loadJornadas() async {
    try {
      final res = await supabase
          .from('jornadas')
          .select('id, numero')
          .eq('division', 'segunda_andaluza')
          .order('numero', ascending: true);
      
      if (mounted) {
        setState(() {
          _jornadas = List<Map<String, dynamic>>.from(res);
          if (_jornadas.isNotEmpty) {
            _selectedJornadaId = _jornadas.first['id'];
            _loadPartidos(_selectedJornadaId!);
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading jornadas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPartidos(String jornadaId) async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('partidos')
          .select('*, equipo_local:equipos_reales!equipo_local_id(nombre, escudo_url), equipo_visit:equipos_reales!equipo_visit_id(nombre, escudo_url)')
          .eq('jornada_id', jornadaId)
          .order('fecha_hora', ascending: true);
      
      if (mounted) {
        setState(() {
          _partidos = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading partidos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateMatchTime(String matchId, DateTime newTime) async {
    try {
      await supabase
          .from('partidos')
          .update({'fecha_hora': newTime.toIso8601String()})
          .eq('id', matchId);
      
      _loadPartidos(_selectedJornadaId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fecha/Hora actualizada correctamente')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _updateMatchResult(String matchId, int local, int visit, String estado) async {
    try {
      await supabase
          .from('partidos')
          .update({
            'goles_local': local,
            'goles_visitante': visit,
            'estado': estado,
          })
          .eq('id', matchId);
      
      _loadPartidos(_selectedJornadaId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resultado actualizado correctamente')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showEditTime(Map<String, dynamic> match) async {
    final initialDate = match['fecha_hora'] != null ? DateTime.parse(match['fecha_hora']) : DateTime.now();
    
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2027),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (time != null) {
        final newDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        _updateMatchTime(match['id'], newDateTime);
      }
    }
  }

  void _showEditResult(Map<String, dynamic> match) {
    int local = match['goles_local'] ?? 0;
    int visit = match['goles_visitante'] ?? 0;
    String estado = match['estado'] ?? 'programado';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 20, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('RESULTADO DEL PARTIDO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(match['equipo_local']['nombre'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        const SizedBox(height: 12),
                        _CounterWidget(value: local, onUpdate: (v) => setMState(() => local = v)),
                      ],
                    ),
                  ),
                  const Text('VS', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Column(
                      children: [
                        Text(match['equipo_visit']['nombre'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        const SizedBox(height: 12),
                        _CounterWidget(value: visit, onUpdate: (v) => setMState(() => visit = v)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: estado,
                dropdownColor: AppColors.bgCard,
                decoration: const InputDecoration(labelText: 'Estado', labelStyle: TextStyle(color: Colors.white70)),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'programado', child: Text('Programado')),
                  DropdownMenuItem(value: 'en_curso', child: Text('En Curso')),
                  DropdownMenuItem(value: 'finalizado', child: Text('Finalizado')),
                ],
                onChanged: (v) => setMState(() => estado = v!),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'GUARDAR',
                onPressed: () {
                  _updateMatchResult(match['id'], local, visit, estado);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Calendario y Partidos'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Jornada Selector
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _jornadas.length,
              itemBuilder: (context, index) {
                final j = _jornadas[index];
                final isSelected = j['id'] == _selectedJornadaId;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedJornadaId = j['id']);
                    _loadPartidos(j['id']);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'J${j['numero']}',
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _partidos.isEmpty
                    ? const Center(child: Text('No hay partidos programados', style: TextStyle(color: Colors.white30)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _partidos.length,
                        itemBuilder: (context, index) {
                          final m = _partidos[index];
                          return _MatchAdminCard(
                            match: m,
                            onTimeTap: () => _showEditTime(m),
                            onResultTap: () => _showEditResult(m),
                            onManagePoints: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AdminMatchPointsScreen(match: m),
                                ),
                              ).then((_) => _loadPartidos(_selectedJornadaId!));
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _MatchAdminCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final VoidCallback onTimeTap;
  final VoidCallback onResultTap;
  final VoidCallback onManagePoints;

  const _MatchAdminCard({
    required this.match,
    required this.onTimeTap,
    required this.onResultTap,
    required this.onManagePoints,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = match['fecha_hora'] != null 
        ? DateFormat('dd/MM HH:mm').format(DateTime.parse(match['fecha_hora']).toLocal())
        : 'S/F';
    
    final isFinished = match['estado'] == 'finalizado';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isFinished ? AppColors.primary.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildEscudo(match['equipo_local']['escudo_url']),
                    const SizedBox(height: 8),
                    Text(match['equipo_local']['nombre'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Column(
                children: [
                  GestureDetector(
                    onTap: onTimeTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_filled_rounded, color: Colors.white38, size: 12),
                          const SizedBox(width: 6),
                          Text(dateStr, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onResultTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${match['goles_local']} - ${match['goles_visitante']}',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  children: [
                    _buildEscudo(match['equipo_visit']['escudo_url']),
                    const SizedBox(height: 8),
                    Text(match['equipo_visit']['nombre'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onResultTap,
                  child: Text(
                    match['estado'].toString().toUpperCase(), 
                    style: TextStyle(
                      color: isFinished ? AppColors.primary : Colors.orangeAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              if (!isFinished)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton(
                    onPressed: onResultTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('FINALIZAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: isFinished ? onManagePoints : null,
                icon: const Icon(Icons.settings_suggest_rounded, size: 16),
                label: const Text('GESTIONAR PUNTOS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white.withOpacity(0.05),
                  disabledForegroundColor: Colors.white24,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEscudo(String? url) {
    return Container(
      width: 50,
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: url != null && url.isNotEmpty
          ? Image.network(
              url, 
              fit: BoxFit.contain, 
              errorBuilder: (c,e,s) => const Icon(Icons.shield, color: Colors.white10),
            )
          : const Icon(Icons.shield, color: Colors.white10),
    );
  }
}

class _CounterWidget extends StatelessWidget {
  final int value;
  final Function(int) onUpdate;
  const _CounterWidget({required this.value, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: value > 0 ? () => onUpdate(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline, color: Colors.white38),
        ),
        Text('$value', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        IconButton(
          onPressed: () => onUpdate(value + 1),
          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
        ),
      ],
    );
  }
}
