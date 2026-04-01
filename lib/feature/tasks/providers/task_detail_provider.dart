import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/extensions/riverpod_extension.dart';
import 'package:flutter_setup_riverpod/di/repository_providers.dart';
import 'package:flutter_setup_riverpod/di/service_providers.dart';
import 'package:flutter_setup_riverpod/feature/tasks/models/task.dart';
import 'package:flutter_setup_riverpod/feature/tasks/repositories/task_repository.dart';

class TaskDetailState extends Equatable {
  final Task? data;
  final bool isMutating;
  final Object? mutationError;

  const TaskDetailState({
    this.data,
    this.isMutating = false,
    this.mutationError,
  });

  TaskDetailState copyWith({
    Task? data,
    bool? isMutating,
    Object? Function()? mutationError,
  }) {
    return TaskDetailState(
      data: data ?? this.data,
      isMutating: isMutating ?? this.isMutating,
      mutationError: mutationError != null
          ? mutationError()
          : this.mutationError,
    );
  }

  @override
  List<Object?> get props => [data, isMutating, mutationError];
}

final taskDetailNotifierProvider = AsyncNotifierProvider.autoDispose
    .family<TaskDetailNotifier, TaskDetailState, int?>(TaskDetailNotifier.new);

class TaskDetailNotifier extends AsyncNotifier<TaskDetailState> {
  final int? _id;

  TaskDetailNotifier(this._id);

  late TaskRepository _taskRepository;

  @override
  FutureOr<TaskDetailState> build() async {
    ref.cacheFor(const Duration(minutes: 5));
    _taskRepository = ref.read(taskRepositoryProvider);
    if (_id == null) {
      return const TaskDetailState();
    }
    final task = _taskRepository.getTask(_id);
    return TaskDetailState(data: task);
  }

  Future<bool> saveTask({required String title, DateTime? dueDate}) async {
    final current = state.value;
    if (current == null) return false;

    state = AsyncData(current.copyWith(isMutating: true));
    try {
      final task = _taskRepository.saveTask(
        id: current.data?.id ?? 0,
        ulid: current.data?.ulid,
        title: title,
        dueDate: dueDate,
        isCompleted: current.data?.isCompleted ?? false,
      );

      if (dueDate != null && !task.isCompleted) {
        final notifications = ref.read(notificationServiceProvider);
        await notifications.scheduleNotification(
          id: task.id,
          title: 'Task Reminder',
          body: title,
          scheduledDate: dueDate,
        );
      }

      state = AsyncData(current.copyWith(data: task, isMutating: false));
      return true;
    } catch (e) {
      state = AsyncData(
        current.copyWith(isMutating: false, mutationError: () => e),
      );
      return false;
    }
  }
}
