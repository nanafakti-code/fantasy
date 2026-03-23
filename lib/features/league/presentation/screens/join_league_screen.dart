import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  Map<String, dynamic>? _ligaPreview;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.codigo ?? '');
    if (widget.codigo != null) _checkCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkCode() async {
    setState(() => _isChecking = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _isChecking = false;
        _ligaPreview = {
          'nombre': 'Liga de la Peña',
          'division': '2ª Andaluza',
          'participantes': 8,
          'max_participantes': 12,
        };
      });
    }
  }

  Future<void> _joinLeague() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Te has unido a la liga')),
      );
      context.go('/league');
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
                            if (_ligaPreview != null) {
                              setState(() => _ligaPreview = null);
                            }
                          },
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            if (v.length != 8) return 'El código tiene 8 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Vista previa de la liga
                        if (_ligaPreview != null) ...[
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
                                  _ligaPreview!['nombre'] as String,
                                  style:
                                      Theme.of(context).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _ligaPreview!['division'] as String,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.people_rounded,
                                        color: AppColors.textSecondary,
                                        size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_ligaPreview!['participantes']}/${_ligaPreview!['max_participantes']} participantes',
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
                            onPressed: _joinLeague,
                            isLoading: _isLoading,
                            icon: const Icon(Icons.login_rounded,
                                color: Colors.black),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary),
            onPressed: () => context.go('/league'),
          ),
          Text('Unirse a liga',
              style: Theme.of(context).textTheme.headlineLarge),
        ],
      ),
    );
  }
}
