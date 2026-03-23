import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('usuarios')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (mounted) setState(() => _userData = data);
      }
    } catch (e) {
      // Si falla, el usuario de todos modos podrá ver su email
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  final _picker = ImagePicker();
  
  static const _cloudinaryApiKey = '228343367458522';
  static const _cloudinaryApiSecret = 'oiZgDUwPfzUUGhFahjMDM7HX_P8';
  static const _cloudName = 'dvdqltemk';

  Future<void> _uploadAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _isLoading = true);

      // Firma segura para API Authenticated (Firmada)
      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round().toString();
      final str = 'timestamp=$timestamp$_cloudinaryApiSecret';
      final signature = sha1.convert(utf8.encode(str)).toString();

      final targetUrl = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

      final request = http.MultipartRequest('POST', targetUrl)
        ..fields['api_key'] = _cloudinaryApiKey
        ..fields['timestamp'] = timestamp
        ..fields['signature'] = signature
        ..files.add(await http.MultipartFile.fromPath('file', image.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final json = jsonDecode(resStr);
        final imageUrl = json['secure_url'];

        // Guardar en la BD
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final updatedData = await Supabase.instance.client
              .from('usuarios')
              .update({'avatar_url': imageUrl})
              .eq('id', user.id)
              .select();
              
          // Si el update ha devuelto 0 filas, significa que el usuario está en Auth
          // pero no en public.usuarios (algun fallo al registrar). Lo guardamos a la fuerza:
          if (updatedData.isEmpty) {
             await Supabase.instance.client.from('usuarios').insert({
                'id': user.id,
                'email': user.email ?? 'sin@email.com',
                'username': user.email?.split('@').first ?? 'Manager',
                'avatar_url': imageUrl,
             });
          }
          
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Row(
                   children: [
                     Container(
                       padding: const EdgeInsets.all(6),
                       decoration: const BoxDecoration(
                         color: AppColors.primary,
                         shape: BoxShape.circle,
                       ),
                       child: const Icon(Icons.check_rounded, color: Colors.black, size: 16),
                     ),
                     const SizedBox(width: 12),
                     const Expanded(
                       child: Text(
                         'Avatar actualizado con éxito',
                         style: TextStyle(
                           color: AppColors.textPrimary,
                           fontWeight: FontWeight.w600,
                           fontSize: 14,
                         ),
                       ),
                     ),
                   ],
                 ),
                 backgroundColor: AppColors.bgCardLight,
                 behavior: SnackBarBehavior.floating,
                 elevation: 0,
                 margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(16),
                   side: const BorderSide(color: AppColors.primary, width: 1.5),
                 ),
                 duration: const Duration(seconds: 3),
               ),
             );
          }
          
          await _fetchProfile();
        }
      } else {
        final errorStr = await response.stream.bytesToString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error Cloudinary: $errorStr')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final username = _userData?['username'] ?? 'Míster';
    final email = _userData?['email'] ?? Supabase.instance.client.auth.currentUser?.email ?? '';
    final initials = username.isNotEmpty && username != 'Míster' 
        ? username.substring(0, 2).toUpperCase() 
        : 'US';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Mi Perfil', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _uploadAvatar,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Hero(
                    tag: 'profile_avatar',
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                        image: _userData?['avatar_url'] != null
                            ? DecorationImage(
                                image: NetworkImage(_userData!['avatar_url']),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _userData?['avatar_url'] == null
                          ? Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.bgCardLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              username,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 48),
            AppCard(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
                    title: const Text('Ajustes de la cuenta', style: TextStyle(color: AppColors.textPrimary)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    onTap: () {},
                  ),
                  const Divider(color: AppColors.bgCardLight, height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded, color: AppColors.textPrimary),
                    title: const Text('Soporte y Ayuda', style: TextStyle(color: AppColors.textPrimary)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: _signOut,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                side: const BorderSide(color: AppColors.error),
                foregroundColor: AppColors.error,
              ),
              child: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
