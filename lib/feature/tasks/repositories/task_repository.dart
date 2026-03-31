import 'package:flutter_setup_riverpod/core/services/objectbox_service.dart';
import 'package:flutter_setup_riverpod/feature/tasks/models/task.dart';
import 'package:ulid/ulid.dart';

class TaskRepository {
  final ObjectBoxService _objectBoxService;

  TaskRepository(this._objectBoxService);

  Task saveTask({
    int id = 0,
    String? ulid,
    required String title,
    bool isCompleted = false,
    DateTime? dueDate,
  }) {
    final taskUlid = ulid ?? Ulid().toString();

    final task = Task(
      id: id,
      ulid: taskUlid,
      title: title,
      isCompleted: isCompleted,
      dueDate: dueDate,
      updatedAt: DateTime.now(),
    );

    _objectBoxService.store.box<Task>().put(task);
    return task;
  }

  List<Task> getAllTasks() {
    return _objectBoxService.store.box<Task>().getAll();
  }

  Task? getTask(int id) {
    return _objectBoxService.store.box<Task>().get(id);
  }

  void deleteTask(int id) {
    _objectBoxService.store.box<Task>().remove(id);
  }
}
