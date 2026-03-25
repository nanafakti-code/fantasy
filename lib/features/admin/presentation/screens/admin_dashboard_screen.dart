import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
// Removed app_widgets import

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('PANEL SUPERADMIN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAdminCard(
              context,
              title: 'GESTIÓN DE LIGAS',
              subtitle: 'Ver, editar y eliminar todas las ligas del sistema',
              icon: Icons.emoji_events_rounded,
              color: Colors.amber,
              onTap: () => context.push('/admin/leagues'),
            ),
            const SizedBox(height: 16),
            _buildAdminCard(
              context,
              title: 'INTRODUCCIÓN DE PUNTOS',
              subtitle: 'Asignar puntos a los jugadores por jornada',
              icon: Icons.scoreboard_rounded,
              color: AppColors.primary,
              onTap: () => context.push('/admin/points'),
            ),
            const SizedBox(height: 16),
            _buildAdminCard(
              context,
              title: 'CALENDARIO Y PARTIDOS',
              subtitle: 'Gestionar jornadas y resultados de partidos oficiales',
              icon: Icons.calendar_month_rounded,
              color: Colors.blueAccent,
              onTap: () => context.push('/admin/matches'),
            ),
            const SizedBox(height: 32),
            const Text(
              'ESTADÍSTICAS GLOBALES',
              style: TextStyle(color: Colors.white30, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
            ),
            const SizedBox(height: 16),
            _buildStatSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.1)),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatSummary() {
    return FutureBuilder(
      future: Future.wait([
        Supabase.instance.client.from('ligas').select('id'),
        Supabase.instance.client.from('usuarios').select('id'),
        Supabase.instance.client.from('jugadores').select('id'),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data as List;
        return Row(
          children: [
            _StatItem(label: 'Ligas', value: '${(data[0] as List).length}', color: Colors.amber),
            const SizedBox(width: 12),
            _StatItem(label: 'Usuarios', value: '${(data[1] as List).length}', color: AppColors.primary),
            const SizedBox(width: 12),
            _StatItem(label: 'Jugadores', value: '${(data[2] as List).length}', color: Colors.blueAccent),
          ],
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 24)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
