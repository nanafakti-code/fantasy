import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _errorMessage = null);
    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        // En Desktop nativo, abrimos un mini servidor temporal para capturar
        // el código de redirección de Google desde localhost:3000
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);

        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'http://localhost:3000',
        );

        // Esperamos a que Google redirija de vuelta a este mini servidor
        await for (var request in server) {
          final uri = request.uri;
          if (uri.queryParameters.containsKey('code')) {
            final code = uri.queryParameters['code']!;
            
            // Intercambiamos el código de la URL por una Sesión válida en Supabase
            await Supabase.instance.client.auth.exchangeCodeForSession(code);
            
            // Mostramos mensaje de éxito en el navegador para que el usuario pueda cerrarlo
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.html
              ..write('<html><head><title>Autenticado</title></head><body style="background-color:#0f172a;color:#fff;"><h2 style="font-family:sans-serif;text-align:center;margin-top:20vh;">¡Inicio de sesi&oacute;n completado con &eacute;xito!</h2><p style="text-align:center;font-family:sans-serif;">Ya puedes cerrar esta ventana y volver a Fantasy Andaluc&iacute;a.</p><script>window.close();</script></body></html>')
              ..close();

            await server.close(force: true);
            
            // Login terminado, nos vamos al inicio
            if (mounted) context.go('/home');
            break;
            
          } else if (uri.queryParameters.containsKey('error_description')) {
            final error = uri.queryParameters['error_description'];
            request.response
              ..statusCode = 400
              ..headers.contentType = ContentType.html
              ..write('<html><body>Error: $error</body></html>')
              ..close();
            await server.close(force: true);
            if (mounted) setState(() => _errorMessage = error);
            break;
          }
        }
      } else {
        // App móvil (Android/iOS) o Web utilizarán los flujos nativos estándar de forma transparente
        await Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.google);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Ocurrió un error abriendo Google');
      }
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          if (e.message.toLowerCase().contains('invalid login credentials')) {
            _errorMessage = 'Email o contraseña incorrectos';
          } else {
            _errorMessage = e.message;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ha ocurrido un error inesperado';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Email',
            hint: 'tu@email.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefix: const Icon(Icons.email_outlined,
                color: AppColors.textMuted, size: 20),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Introduce tu email';
              if (!value.contains('@')) return 'Email no válido';
              return null;
            },
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Contraseña',
            controller: _passwordController,
            obscureText: _obscurePassword,
            prefix: const Icon(Icons.lock_outline,
                color: AppColors.textMuted, size: 20),
            suffix: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Introduce tu contraseña';
              if (value.length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          AppButton(
            label: 'Entrar',
            onPressed: _signIn,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),
          _OrDivider(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _signInWithGoogle,
            icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
            label: const Text('Continuar con Google'),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'o',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
