import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class AdminPointsScreen extends StatefulWidget {
  const AdminPointsScreen({super.key});

  @override
  State<AdminPointsScreen> createState() => _AdminPointsScreenState();
}

class _AdminPointsScreenState extends State<AdminPointsScreen> {
  String? _selectedJornadaId;
  String? _selectedMatchId;
  List<dynamic> _jornadas = [];
  List<dynamic> _matches = [];
  List<dynamic> _players = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadJornadas();
  }

  Future<void> _loadJornadas() async {
    final res = await Supabase.instance.client.from('jornadas').select().order('numero');
    setState(() => _jornadas = res);
  }

  Future<void> _loadMatches(String jornadaId) async {
    setState(() => _isLoading = true);
    final res = await Supabase.instance.client
        .from('partidos')
        .select('*, equipo_local:equipos_reales!equipo_local_id(nombre, escudo_url), equipo_visitant:equipos_reales!equipo_visit_id(nombre, escudo_url)')
        .eq('jornada_id', jornadaId);
    setState(() {
      _matches = res;
      _selectedMatchId = null;
      _players = [];
      _isLoading = false;
    });
  }

  Future<void> _loadPlayers(String matchId) async {
    setState(() => _isLoading = true);
    final match = _matches.firstWhere((m) => m['id'] == matchId);
    final res = await Supabase.instance.client
        .from('jugadores')
        .select('*, stats:estadisticas_jugadores(*)')
        .or('equipo_id.eq.${match['equipo_local_id']},equipo_id.eq.${match['equipo_visit_id']}')
        .eq('stats.partido_id', matchId); 
    
    final players = List<dynamic>.from(res);
    // Sort: Local first, then Visitor. Within each team: GK, DF, MF, FW.
    players.sort((a, b) {
      // 1. Team Sort
      if (a['equipo_id'] == match['equipo_local_id'] && b['equipo_id'] != match['equipo_local_id']) return -1;
      if (a['equipo_id'] != match['equipo_local_id'] && b['equipo_id'] == match['equipo_local_id']) return 1;
      
      // 2. Position Sort
      final posOrder = {'portero': 0, 'defensa': 1, 'centrocampista': 2, 'delantero': 3, 'entrenador': 4};
      final posA = posOrder[a['posicion'].toString().toLowerCase()] ?? 99;
      final posB = posOrder[b['posicion'].toString().toLowerCase()] ?? 99;
      
      if (posA != posB) return posA.compareTo(posB);

      // 3. Name Sort
      return a['nombre'].toString().compareTo(b['nombre'].toString());
    });

    setState(() {
      _players = players;
      _isLoading = false;
    });
  }

  Future<void> _saveStat(String jugadorId, Map<String, dynamic> stats) async {
    try {
      await Supabase.instance.client.from('estadisticas_jugadores').upsert(
        {
          'jugador_id': jugadorId,
          'partido_id': _selectedMatchId,
          ...stats,
        },
        onConflict: 'jugador_id,partido_id',
      );
      _loadPlayers(_selectedMatchId!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showStatsModal(dynamic p) {
    final stat = (p['stats'] as List).isNotEmpty ? p['stats'][0] : null;
    int goles = stat?['goles'] ?? 0;
    int golesPropia = stat?['goles_propia'] ?? 0;
    bool porteriaCero = stat?['porteria_cero'] ?? false;
    bool convocado = stat?['convocado'] ?? true; // Default to true if already editing
    bool titular = stat?['titular'] ?? false;
    bool noJugo = stat?['minutos_jugados'] == 0 && stat != null;
    bool amarilla = (stat?['tarjetas_amarillas'] ?? 0) > 0;
    bool dobleAmarilla = (stat?['tarjetas_amarillas'] ?? 0) >= 2;
    bool tarjetaRoja = (stat?['tarjetas_rojas'] ?? 0) > 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ESTADÍSTICAS: ${p['nombre']} ${p['apellidos'] ?? ''}', 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 20),
                
                // CHECKBOX: Convocado
                CheckboxListTile(
                  title: const Text('¿Convocado?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Marca si el jugador entró en la convocatoria', 
                    style: TextStyle(color: Colors.white30, fontSize: 12)),
                  value: convocado,
                  onChanged: (val) => setMState(() {
                    convocado = val!;
                    if (!val) {
                      noJugo = true;
                      titular = false;
                      porteriaCero = false;
                    }
                  }),
                ),
                const SizedBox(height: 12),

                // CHECKBOX: No jugó
                CheckboxListTile(
                  title: const Text('¿No jugó?', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Marca si el jugador no participó en el partido', 
                    style: TextStyle(color: Colors.white30, fontSize: 12)),
                  value: noJugo,
                  onChanged: convocado ? (val) => setMState(() => noJugo = val!) : null,
                ),
                const SizedBox(height: 12),
                
                // Si NO marcó "No jugó", mostrar las opciones
                if (!noJugo) ...[
                  CheckboxListTile(
                    title: const Text('¿Fue Titular?', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Titular suma más puntos que suplente', 
                      style: TextStyle(color: Colors.white30, fontSize: 12)),
                    value: titular,
                    onChanged: (val) => setMState(() => titular = val!),
                  ),
                  const SizedBox(height: 16),
                  
                  // Goles (contador)
                  _buildCounter('Goles', goles, (v) => setMState(() => goles = v)),
                  const SizedBox(height: 12),
                  
                  // Goles Propia (contador)
                  _buildCounter('Goles en propia', golesPropia, (v) => setMState(() => golesPropia = v)),
                  const SizedBox(height: 16),

                  // Portería 0
                  CheckboxListTile(
                    title: const Text('Portería 0', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Puntos extra por imbatibilidad', 
                      style: TextStyle(color: Colors.white30, fontSize: 12)),
                    value: porteriaCero,
                    onChanged: (val) => setMState(() => porteriaCero = val!),
                  ),
                  const SizedBox(height: 16),
                  
                  // Tarjetas
                  const Divider(color: Colors.white10),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: const Text('Tarjetas', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  
                  CheckboxListTile(
                    title: const Text('Tarjeta Amarilla', style: TextStyle(color: Colors.white)),
                    value: amarilla,
                    onChanged: (val) => setMState(() {
                      amarilla = val!;
                      if (val) {
                        dobleAmarilla = false;
                        tarjetaRoja = false;
                      }
                    }),
                  ),
                  
                  CheckboxListTile(
                    title: const Text('Doble Amarilla (Expulsión)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    value: dobleAmarilla,
                    onChanged: (val) => setMState(() {
                      dobleAmarilla = val!;
                      if (val) {
                        amarilla = false;
                        tarjetaRoja = false;
                      }
                    }),
                  ),
                  
                  CheckboxListTile(
                    title: const Text('Tarjeta Roja Directa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    value: tarjetaRoja,
                    onChanged: (val) => setMState(() {
                      tarjetaRoja = val!;
                      if (val) {
                        amarilla = false;
                        dobleAmarilla = false;
                      }
                    }),
                  ),
                ],
                
                const SizedBox(height: 24),
                AppButton(
                  label: 'GUARDAR',
                  onPressed: () {
                    _saveStat(p['id'], {
                      'convocado': convocado,
                      'titular': convocado && !noJugo && titular,
                      'goles': (convocado && !noJugo) ? goles : 0,
                      'goles_propia': (convocado && !noJugo) ? golesPropia : 0,
                      'porteria_cero': (convocado && !noJugo) && porteriaCero,
                      'asistencias': 0, // Eliminado
                      'tarjetas_amarillas': (convocado && !noJugo) ? (dobleAmarilla ? 2 : (amarilla ? 1 : 0)) : 0,
                      'tarjetas_rojas': (convocado && !noJugo) ? (tarjetaRoja ? 1 : 0) : 0,
                      'minutos_jugados': (convocado && !noJugo) ? (titular ? 90 : 45) : 0,
                    });
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounter(String label, int value, Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white30), onPressed: () => onChanged(value > 0 ? value - 1 : 0)),
          Text('$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.primary), onPressed: () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _buildEscudo(String? url) {
    if (url == null || url.isEmpty) return const SizedBox(width: 20, height: 20);
    return Image.network(url, width: 22, height: 22, errorBuilder: (ctx, _, __) => const Icon(Icons.shield, size: 20, color: Colors.white24));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: const Text('INTRODUCCIÓN DE PUNTOS'), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Seleccionar Jornada', labelStyle: TextStyle(color: Colors.white30)),
              dropdownColor: AppColors.bgCard,
              style: const TextStyle(color: Colors.white),
              value: _selectedJornadaId,
              isExpanded: true,
              items: _jornadas.map((j) => DropdownMenuItem(value: j['id'].toString(), child: Text('Jornada ${j['numero']}'))).toList(),
              onChanged: (val) {
                setState(() => _selectedJornadaId = val);
                if (val != null) _loadMatches(val);
              },
            ),
            const SizedBox(height: 16),
            if (_selectedJornadaId != null)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Seleccionar Partido', labelStyle: TextStyle(color: Colors.white30)),
                dropdownColor: AppColors.bgCard,
                style: const TextStyle(color: Colors.white),
                isExpanded: true,
                value: _selectedMatchId,
                items: _matches.map((m) => DropdownMenuItem(
                  value: m['id'].toString(), 
                  child: Row(
                    children: [
                      _buildEscudo(m['equipo_local']['escudo_url']),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${m['equipo_local']['nombre']} vs ${m['equipo_visitant']['nombre']}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildEscudo(m['equipo_visitant']['escudo_url']),
                    ],
                  ),
                )).toList(),
                onChanged: (val) {
                  setState(() => _selectedMatchId = val);
                  if (val != null) _loadPlayers(val);
                },
              ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _players.isEmpty
                  ? const Center(child: Text('Selecciona un partido', style: TextStyle(color: Colors.white24)))
                  : _buildPlayersList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersList() {
    final match = _matches.firstWhere((m) => m['id'] == _selectedMatchId);
    final localId = match['equipo_local_id'];
    final localName = match['equipo_local']['nombre'];
    final visitName = match['equipo_visitant']['nombre'];

    final localPlayers = _players.where((p) => p['equipo_id'] == localId).toList();
    final visitPlayers = _players.where((p) => p['equipo_id'] != localId).toList();

    return ListView(
      children: [
        _buildSectionHeader(localName, true),
        ...localPlayers.map((p) => _buildPlayerTile(p)),
        const SizedBox(height: 16),
        _buildSectionHeader(visitName, false),
        ...visitPlayers.map((p) => _buildPlayerTile(p)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionHeader(String name, bool isLocal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: isLocal ? AppColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isLocal ? AppColors.primary.withOpacity(0.3) : Colors.white12),
      ),
      child: Text(
        name.toUpperCase(),
        style: TextStyle(
          color: isLocal ? AppColors.primary : Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildPlayerTile(dynamic p) {
    final hasStats = (p['stats'] as List).isNotEmpty;
    // Color según posición
    Color posColor = Colors.white30;
    switch (p['posicion']?.toString().toLowerCase()) {
      case 'portero': posColor = Colors.orange; break;
      case 'defensa': posColor = Colors.blue; break;
      case 'centrocampista': posColor = Colors.green; break;
      case 'delantero': posColor = Colors.red; break;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        '${p['nombre']} ${p['apellidos'] ?? ''}', 
        style: TextStyle(color: hasStats ? Colors.white : Colors.white60, fontWeight: hasStats ? FontWeight.bold : FontWeight.normal)
      ),
      subtitle: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: posColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            p['posicion'].toString().toUpperCase(), 
            style: const TextStyle(fontSize: 10, color: Colors.white30, letterSpacing: 1),
          ),
        ],
      ),
      trailing: hasStats 
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1), 
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ), 
            child: Text(
              '${p['stats'][0]['puntos_calculados']}', 
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)
            )
          )
        : const Icon(Icons.edit_note_rounded, color: Colors.white24),
      onTap: () => _showStatsModal(p),
    );
  }
}
