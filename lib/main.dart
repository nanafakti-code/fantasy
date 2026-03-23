import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

// ─── CONFIGURACIÓN SUPABASE ───────────────────────────────────────────────────
// IMPORTANTE: Reemplaza estos valores con los de tu proyecto en supabase.com
// Dashboard → Settings → API
const _supabaseUrl = 'https://almpxaopciabxsbjzryh.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFsbXB4YW9wY2lhYnhzYmp6cnloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQyMjEwNjMsImV4cCI6MjA4OTc5NzA2M30.B_Oh-3V4TWNB4PTiIDUpVVrp4oP9q0O997ap7OAKSqM';
// ─────────────────────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientación vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Barra de estado transparente
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF111827),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Inicializar Supabase (con guard para demo sin credenciales)
  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: FantasyAndaluciaApp(),
    ),
  );
}

class FantasyAndaluciaApp extends ConsumerWidget {
  const FantasyAndaluciaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Fantasy Andalucía',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
