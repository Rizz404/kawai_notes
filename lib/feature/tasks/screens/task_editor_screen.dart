import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_setup_riverpod/core/extensions/navigator_extension.dart';
import 'package:flutter_setup_riverpod/feature/tasks/providers/task_detail_provider.dart';
import 'package:flutter_setup_riverpod/feature/tasks/providers/task_list_provider.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_text_field.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_date_time_picker.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_button.dart';
import 'package:flutter_setup_riverpod/shared/widgets/screen_wrapper.dart';

class TaskEditorScreen extends ConsumerStatefulWidget {
  final int? taskId;

  const TaskEditorScreen({this.taskId, super.key});

  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    final detailStateAsync = ref.watch(taskDetailNotifierProvider(widget.taskId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskId == null ? 'New Task' : 'Edit Task'),
      ),
      body: detailStateAsync.when(
        data: (state) {
          final task = state.data;
          return ScreenWrapper(
            child: FormBuilder(
              key: _formKey,
              initialValue: {
                'title': task?.title ?? '',
                'dueDate': task?.dueDate,
              },
              child: Column(
                children: [
                  AppTextField(
                    name: 'title',
                    label: 'Task Title',
                    validator: FormBuilderValidators.required(),
                  ),
                  const SizedBox(height: 16),
                  const AppDateTimePicker(
                    name: 'dueDate',
                    label: 'Due Date',
                    inputType: InputType.both,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: 'Save Task',
                      onPressed: () async {
                        if (_formKey.currentState?.saveAndValidate() ?? false) {
                          final values = _formKey.currentState!.value;
                          final title = values['title'] as String;
                          final dueDate = values['dueDate'] as DateTime?;

                          final success = await ref
                              .read(taskDetailNotifierProvider(widget.taskId).notifier)
                              .saveTask(title: title, dueDate: dueDate);

                          if (success && context.mounted) {
                            await ref.read(taskListNotifierProvider.notifier).refresh();
                            if (context.mounted) context.pop();
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
