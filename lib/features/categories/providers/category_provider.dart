import 'package:flutter_riverpod/legacy.dart';
import '../../../domain/entities/vault_category.dart';
import '../../../data/repositories/category_repository.dart';

final categoryListProvider =
    StateNotifierProvider<CategoryNotifier, List<VaultCategory>>((ref) {
      return CategoryNotifier();
    });

class CategoryNotifier extends StateNotifier<List<VaultCategory>> {
  final CategoryRepository _repo = CategoryRepository.instance;

  CategoryNotifier() : super([]) {
    loadAll();
  }

  Future<void> loadAll() async {
    final items = await _repo.getAll();
    state = items;
  }

  Future<void> addCategory(VaultCategory c) async {
    final inserted = await _repo.insert(c);
    state = [...state, inserted];
  }

  Future<void> updateCategory(VaultCategory c) async {
    await _repo.update(c);
    state = [
      for (final e in state)
        if (e.id == c.id) c else e,
    ];
  }

  Future<void> deleteCategory(int id) async {
    await _repo.delete(id);
    state = state.where((e) => e.id != id).toList();
  }
}
