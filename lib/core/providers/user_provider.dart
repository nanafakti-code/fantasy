import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserState {
  final Map<String, dynamic>? profile;
  final bool isAdmin;
  final bool isLoading;

  UserState({this.profile, this.isAdmin = false, this.isLoading = true});

  UserState copyWith({Map<String, dynamic>? profile, bool? isAdmin, bool? isLoading}) {
    return UserState(
      profile: profile ?? this.profile,
      isAdmin: isAdmin ?? this.isAdmin,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class UserNotifier extends StateNotifier<UserState> {
  UserNotifier() : super(UserState()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('usuarios')
          .select('*, rol')
          .eq('id', user.id)
          .maybeSingle();

      if (res != null) {
        state = UserState(
          profile: res,
          isAdmin: res['rol'] == 'admin',
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() => loadProfile();
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier();
});
