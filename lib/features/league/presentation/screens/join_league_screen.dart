import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class JoinLeagueScreen extends ConsumerStatefulWidget {
  final String? codigo;
  const JoinLeagueScreen({super.key, this.codigo});

  @override
  ConsumerState<JoinLeagueScreen> createState() => _JoinLeagueScreenState();
}

class _JoinLeagueScreenState extends ConsumerState<JoinLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  bool _isLoading = false;
  bool _isChecking = false;
  Map<String, dynamic>? _ligaFound;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.codigo ?? '');
    if (widget.codigo != null && widget.codigo!.length == 8) _checkCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 8) return;

    setState(() {
      _isChecking = true;
      _ligaFound = null;
    });

    try {
      final league = await Supabase.instance.client
          .from('ligas')
          .select('id, nombre, max_participantes')
          .eq('codigo_invitacion', code)
          .maybeSingle();

      if (league == null) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Código no válido o liga inexistente')),
          );
        }
        setState(() => _isChecking = false);
        return;
      }

      final participantsList = await Supabase.instance.client
          .from('usuarios_ligas')
          .select('id')
          .eq('liga_id', league['id']);

      if (mounted) {
        setState(() {
          _isChecking = false;
          _ligaFound = {
            'id': league['id'],
            'nombre': league['nombre'],
            'participantes': (participantsList as List).length,
            'max_participantes': league['max_participantes'],
          };
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _joinLeague() async {
    if (_ligaFound == null) return;
    
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'No hay usuario autenticado';

      final existing = await Supabase.instance.client
          .from('usuarios_ligas')
          .select('id')
          .eq('user_id', user.id)
          .eq('liga_id', _ligaFound!['id'])
          .maybeSingle();

      if (existing != null) {
        throw 'Ya perteneces a esta liga';
      }

      await Supabase.instance.client.from('usuarios_ligas').insert({
        'user_id': user.id,
        'liga_id': _ligaFound!['id'],
        'presupuesto': 50000000, 
      });

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ ¡Bienvenido a la liga!')),
        );
        context.pop(); 
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Introduce el código',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tu amigo te habrá pasado un código de 8 caracteres.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        AppTextField(
                          label: 'Código de invitación',
                          hint: 'FANT2025',
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [UpperCaseTextFormatter()],
                          prefix: const Icon(Icons.link_rounded,
                              color: AppColors.textMuted, size: 20),
                          suffix: _isChecking
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.search_rounded,
                                      color: AppColors.primary),
                                  onPressed: _checkCode,
                                ),
                          onChanged: (v) {
                            if (_ligaFound != null) {
                              setState(() => _ligaFound = null);
                            }
                          },
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            if (v.length != 8) return 'El código tiene 8 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        if (_ligaFound != null) ...[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.success.withOpacity(0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        color: AppColors.success, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Liga encontrada',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(color: AppColors.success),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _ligaFound!['nombre'] as String,
                                  style:
                                      Theme.of(context).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '2ª Andaluza',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.people_rounded,
                                        color: AppColors.textSecondary,
                                        size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_ligaFound!['participantes']}/${_ligaFound!['max_participantes']} participantes',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          AppButton(
                            label: 'Unirme a la liga',
                            isLoading: _isLoading,
                            onPressed: _joinLeague,
                          ),
                        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 8),
          Text('Unirse a liga',
              style: Theme.of(context).textTheme.headlineLarge),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
