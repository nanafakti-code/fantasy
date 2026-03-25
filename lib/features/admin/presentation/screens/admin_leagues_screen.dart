import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
// Removed app_widgets import

class AdminLeaguesScreen extends StatefulWidget {
  const AdminLeaguesScreen({super.key});

  @override
  State<AdminLeaguesScreen> createState() => _AdminLeaguesScreenState();
}

class _AdminLeaguesScreenState extends State<AdminLeaguesScreen> {
  bool _isLoading = true;
  List<dynamic> _leagues = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllLeagues();
  }

  Future<void> _loadAllLeagues() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('ligas')
          .select('*, creador:usuarios(username)')
          .order('created_at', ascending: false);
      setState(() {
        _leagues = res as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading admin leagues: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLeague(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Eliminar Liga'),
        content: const Text('¿Estás seguro de que deseas eliminar esta liga? Esta acción es IRREVERSIBLE.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client.from('ligas').delete().eq('id', id);
      _loadAllLeagues();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Liga eliminada correctamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var filtered = _leagues;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((l) => (l['nombre'] as String).toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('GESTIÓN DE LIGAS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar liga...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white30),
                filled: true,
                fillColor: AppColors.bgCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty 
                ? const Center(child: Text('No hay ligas registradas', style: TextStyle(color: Colors.white24)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final l = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l['nombre'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Admin: ${l['creador']?['username'] ?? 'Sistema'} • Cod: ${l['codigo_invitacion']}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                  Text(
                                    'División: ${l['division'].toString().replaceAll('_', ' ').toUpperCase()}',
                                    style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                            _buildActionButton(Icons.delete_outline_rounded, Colors.redAccent, () => _deleteLeague(l['id'])),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
