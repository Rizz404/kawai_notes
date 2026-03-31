import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_setup_riverpod/core/extensions/navigator_extension.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';
import 'package:flutter_setup_riverpod/feature/tasks/models/task.dart';
import 'package:flutter_setup_riverpod/feature/tasks/providers/task_list_provider.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_shell.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskListNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/task-editor'),
        backgroundColor: context.colorScheme.primary,
        child: Icon(Icons.add, color: context.colorScheme.onPrimary),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            context.replace('/');
          } else if (index == 2) {
            context.replace('/other');
          }
        },
      ),
      body: taskState.when(
        data: (state) {
          if (state.isEmpty) {
            return const Center(child: AppText('No Tasks. Create one!'));
          }
          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  labelColor: context.colorScheme.primary,
                  unselectedLabelColor: context.colorScheme.onSurfaceVariant,
                  indicatorColor: context.colorScheme.primary,
                  tabs: const [
                    Tab(text: 'Active'),
                    Tab(text: 'Completed'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildTaskList(context, ref, state.activeTasks),
                      _buildTaskList(context, ref, state.completedTasks),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: AppText('Error: $e')),
      ),
    );
  }

  Widget _buildTaskList(BuildContext context, WidgetRef ref, List<Task> tasks) {
    if (tasks.isEmpty) {
      return const Center(child: AppText('Nothing here...'));
    }
    return ListView.builder(
      itemCount: tasks.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          elevation: 0,
          color: context.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Checkbox(
              value: task.isCompleted,
              onChanged: (val) {
                ref
                    .read(taskListNotifierProvider.notifier)
                    .toggleTaskCompletion(task.id);
              },
            ),
            title: AppText(
              task.title,
              customStyle: task.isCompleted
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            subtitle: task.dueDate != null
                ? AppText(
                    'Due: ${task.dueDate!.toLocal().toString().split(' ')[0]}',
                    customStyle: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.primary,
                    ),
                  )
                : null,
            onTap: () {
              context.push('/task-editor', extra: {'id': task.id});
            },
            trailing: IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: context.colorScheme.error,
              ),
              onPressed: () {
                ref.read(taskListNotifierProvider.notifier).deleteTask(task.id);
              },
            ),
          ),
        );
      },
    );
  }
}
