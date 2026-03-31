import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/di/repository_providers.dart';
import 'package:flutter_setup_riverpod/feature/folders/models/folder.dart';
import 'package:flutter_setup_riverpod/feature/folders/repositories/folder_repository.dart';

class FolderListState extends Equatable {
  final List<Folder> items;
  final bool isMutating;
  final Object? mutationError;

  const FolderListState({
    this.items = const [],
    this.isMutating = false,
    this.mutationError,
  });

  bool get isEmpty => items.isEmpty;

  FolderListState copyWith({
    List<Folder>? items,
    bool? isMutating,
    Object? Function()? mutationError,
  }) {
    return FolderListState(
      items: items ?? this.items,
      isMutating: isMutating ?? this.isMutating,
      mutationError: mutationError != null ? mutationError() : this.mutationError,
    );
  }

  @override
  List<Object?> get props => [items, isMutating, mutationError];
}

final folderListNotifierProvider = AsyncNotifierProvider<FolderListNotifier, FolderListState>(
  FolderListNotifier.new,
);

class FolderListNotifier extends AsyncNotifier<FolderListState> {
  late FolderRepository _folderRepository;

  @override
  FutureOr<FolderListState> build() async {
    _folderRepository = ref.read(folderRepositoryProvider);
    return _fetch();
  }

  Future<FolderListState> _fetch() async {
    final allFolders = _folderRepository.getAllFolders();
    // Sort logic here if needed
    return FolderListState(items: allFolders);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<FolderListState>();
    state = AsyncData(await _fetch());
  }

  Future<bool> createFolder(String name, {int? parentId}) async {
    final current = state.value;
    if (current == null) return false;

    state = AsyncData(current.copyWith(isMutating: true));
    try {
      _folderRepository.saveFolder(
        name: name,
        parentId: parentId,
      );
      state = AsyncData(await _fetch());
      return true;
    } catch (e, st) {
      state = AsyncData(
        current.copyWith(
          isMutating: false,
          mutationError: () => e,
        ),
      );
      return false;
    }
  }

  Future<void> deleteFolder(int id) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.copyWith(isMutating: true));
    try {
      _folderRepository.deleteFolder(id);
      state = AsyncData(await _fetch());
    } catch (e, st) {
      state = AsyncData(
        current.copyWith(
          isMutating: false,
          mutationError: () => e,
        ),
      );
    }
  }
}
