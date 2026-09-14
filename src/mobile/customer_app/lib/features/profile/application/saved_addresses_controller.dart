import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/place.dart';
import '../data/profile_repository.dart';

/// Owns the saved-address list and its CRUD operations. Mutations update state
/// optimistically from the repository's returned list.
class SavedAddressesController extends AsyncNotifier<List<SavedPlace>> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  Future<List<SavedPlace>> build() => _repo.addresses();

  Future<void> add(SavedPlace address) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.add(address));
  }

  Future<void> remove(String id) async {
    final previous = state.valueOrNull ?? const [];
    // Optimistic remove so the row disappears instantly.
    state = AsyncValue.data(previous.where((a) => a.id != id).toList());
    state = await AsyncValue.guard(() => _repo.remove(id));
  }
}

final savedAddressesProvider =
    AsyncNotifierProvider<SavedAddressesController, List<SavedPlace>>(
  SavedAddressesController.new,
);
