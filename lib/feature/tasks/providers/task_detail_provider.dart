import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/core/extensions/logger_extension.dart';
import 'package:kawai_notes/core/extensions/riverpod_extension.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/tasks/models/task.dart';
import 'package:kawai_notes/feature/tasks/repositories/task_repository.dart';
import 'package:kawai_notes/l10n/app_localizations.dart';

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
    _taskRepository = ref.read(taskRepositoryProvider);
    // * a cached "new task" state would make the next create edit this task
    if (_id != null) ref.cacheFor(const Duration(minutes: 5));
    if (_id == null) {
      return const TaskDetailState();
    }
    final task = _taskRepository.getTask(_id);
    return TaskDetailState(data: task);
  }

  String _reminderTitle() {
    try {
      return LocalizationExtension.current.tasksTaskReminder;
    } catch (_) {
      return lookupL10n(const Locale('en')).tasksTaskReminder;
    }
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

      // * keep the persisted id before scheduling so a retry updates, not duplicates
      state = AsyncData(current.copyWith(data: task, isMutating: false));

      final notifications = ref.read(notificationServiceProvider);
      try {
        if (dueDate != null && !task.isCompleted) {
          await notifications.scheduleNotification(
            id: task.id,
            title: _reminderTitle(),
            body: title,
            scheduledDate: dueDate,
          );
        } else {
          await notifications.cancelNotification(task.id);
        }
      } catch (e, stack) {
        // * the task is saved; a reminder failure must not fail the save
        logError('Failed to update task reminder', e, stack);
      }
      return true;
    } catch (e) {
      state = AsyncData(
        current.copyWith(isMutating: false, mutationError: () => e),
      );
      return false;
    }
  }
}
