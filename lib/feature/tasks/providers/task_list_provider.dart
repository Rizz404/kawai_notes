import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/core/extensions/logger_extension.dart';
import 'package:kawai_notes/di/repository_providers.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/tasks/models/task.dart';
import 'package:kawai_notes/feature/tasks/repositories/task_repository.dart';
import 'package:kawai_notes/l10n/app_localizations.dart';

class TaskListState extends Equatable {
  final List<Task> items;
  final bool isMutating;
  final Object? mutationError;

  const TaskListState({
    this.items = const [],
    this.isMutating = false,
    this.mutationError,
  });

  bool get isEmpty => items.isEmpty;
  List<Task> get activeTasks => items.where((t) => !t.isCompleted).toList();
  List<Task> get completedTasks => items.where((t) => t.isCompleted).toList();

  TaskListState copyWith({
    List<Task>? items,
    bool? isMutating,
    Object? Function()? mutationError,
  }) {
    return TaskListState(
      items: items ?? this.items,
      isMutating: isMutating ?? this.isMutating,
      mutationError: mutationError != null
          ? mutationError()
          : this.mutationError,
    );
  }

  @override
  List<Object?> get props => [items, isMutating, mutationError];
}

final taskListNotifierProvider =
    AsyncNotifierProvider<TaskListNotifier, TaskListState>(
      TaskListNotifier.new,
    );

class TaskListNotifier extends AsyncNotifier<TaskListState> {
  late TaskRepository _taskRepository;

  @override
  FutureOr<TaskListState> build() async {
    _taskRepository = ref.read(taskRepositoryProvider);
    return _fetch();
  }

  Future<TaskListState> _fetch() async {
    final allTasks = _taskRepository.getAllTasks();
    // Sort tasks logically by dueDate and creation date
    allTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return TaskListState(items: allTasks);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<TaskListState>();
    state = AsyncData(await _fetch());
  }

  Future<void> toggleTaskCompletion(int id) async {
    final current = state.value;
    if (current == null) return;

    try {
      final task = _taskRepository.getTask(id);
      if (task != null) {
        task.isCompleted = !task.isCompleted;
        task.updatedAt = DateTime.now();
        _taskRepository.saveTask(
          id: task.id,
          ulid: task.ulid,
          title: task.title,
          isCompleted: task.isCompleted,
          dueDate: task.dueDate,
        );
        if (task.isCompleted) {
          await _cancelReminder(id);
        } else {
          await _rescheduleReminder(task);
        }
        state = AsyncData(await _fetch());
      }
    } catch (e) {
      state = AsyncData(current.copyWith(mutationError: () => e));
    }
  }

  Future<void> _cancelReminder(int id) async {
    try {
      await ref.read(notificationServiceProvider).cancelNotification(id);
    } catch (e, stack) {
      logError('Failed to cancel task reminder', e, stack);
    }
  }

  Future<void> _rescheduleReminder(Task task) async {
    final due = task.dueDate;
    if (due == null || !due.isAfter(DateTime.now())) return;
    try {
      await ref
          .read(notificationServiceProvider)
          .scheduleNotification(
            id: task.id,
            title: _reminderTitle(),
            body: task.title,
            scheduledDate: due,
          );
    } catch (e, stack) {
      logError('Failed to reschedule task reminder', e, stack);
    }
  }

  String _reminderTitle() {
    try {
      return LocalizationExtension.current.tasksTaskReminder;
    } catch (_) {
      return lookupL10n(const Locale('en')).tasksTaskReminder;
    }
  }

  Future<void> deleteTask(int id) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.copyWith(isMutating: true));
    try {
      _taskRepository.deleteTask(id);
      await _cancelReminder(id);
      state = AsyncData(await _fetch());
    } catch (e) {
      state = AsyncData(
        current.copyWith(isMutating: false, mutationError: () => e),
      );
    }
  }
}
