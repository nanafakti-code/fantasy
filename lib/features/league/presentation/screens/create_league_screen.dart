import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class CreateLeagueScreen extends ConsumerStatefulWidget {
  const CreateLeagueScreen({super.key});

  @override
  ConsumerState<CreateLeagueScreen> createState() => _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends ConsumerState<CreateLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _maxParticipantes = 12;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createLeague() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No autenticado');

      // Generar código aleatorio
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final random = Random();
      final code = String.fromCharCodes(Iterable.generate(
          8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));

      // 1. Crear liga
      final newLeague = await Supabase.instance.client
          .from('ligas')
          .insert({
            'nombre': _nameController.text.trim(),
            'creador_id': user.id,
            'max_participantes': _maxParticipantes,
            'codigo_invitacion': code,
            'presupuesto_inicial': 50000000,
          })
          .select()
          .single();

      // 2. Unirse como admin
      await Supabase.instance.client.from('usuarios_ligas').insert({
        'user_id': user.id,
        'liga_id': newLeague['id'],
        'presupuesto': 50000000,
        'puntos_totales': 0,
      });

      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccessDialog(context, code);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showSuccessDialog(BuildContext context, String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¡Liga creada!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                code,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Comparte este código para que tus amigos se unan a tu liga.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Cierra el diálogo
              context.pop();      // Vuelve al Inicio y activa el refresh
            },
            child: const Text('Ir al inicio'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          label: 'Nombre de la liga',
                          hint: 'Ej: Liga de la Peña',
                          controller: _nameController,
                          prefix: const Icon(Icons.emoji_events_rounded,
                              color: AppColors.textMuted, size: 20),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            if (v.length < 3) return 'Mínimo 3 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Participantes máximos: $_maxParticipantes',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Slider(
                          value: _maxParticipantes.toDouble(),
                          min: 2,
                          max: 14,
                          divisions: 12,
                          activeColor: AppColors.primary,
                          inactiveColor: AppColors.bgCardLight,
                          label: '$_maxParticipantes',
                          onChanged: (v) =>
                              setState(() => _maxParticipantes = v.toInt()),
                        ),
                        const SizedBox(height: 16),
                        _InfoCard(
                          icon: Icons.info_outline_rounded,
                          text:
                              'Presupuesto inicial: 50M €\nSe generará un código único de 8 caracteres.',
                        ),
                        const SizedBox(height: 32),
                        AppButton(
                          label: 'Crear liga',
                          onPressed: _createLeague,
                          isLoading: _isLoading,
                          icon: const Icon(Icons.add_rounded,
                              color: Colors.black),
                        ),
                      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          Text('Crear liga', style: Theme.of(context).textTheme.headlineLarge),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
