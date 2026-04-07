import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/core/extensions/navigator_extension.dart';
import 'package:kawai_notes/feature/tasks/providers/task_detail_provider.dart';
import 'package:kawai_notes/feature/tasks/providers/task_list_provider.dart';
import 'package:kawai_notes/shared/widgets/app_button.dart';
import 'package:kawai_notes/shared/widgets/app_date_time_picker.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';
import 'package:kawai_notes/shared/widgets/app_text_field.dart';
import 'package:kawai_notes/shared/widgets/screen_wrapper.dart';

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
    final detailStateAsync = ref.watch(
      taskDetailNotifierProvider(widget.taskId),
    );

    return Scaffold(
      appBar: AppBar(
        title: AppText(
          widget.taskId == null
              ? context.l10n.tasksNew
              : context.l10n.tasksEdit,
        ),
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
                    label: context.l10n.tasksTitleLabel,
                    validator: FormBuilderValidators.required(),
                  ),
                  const SizedBox(height: 16),
                  AppDateTimePicker(
                    name: 'dueDate',
                    label: context.l10n.tasksDueDate,
                    inputType: InputType.both,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: context.l10n.tasksSave,
                      onPressed: () async {
                        if (_formKey.currentState?.saveAndValidate() ?? false) {
                          final values = _formKey.currentState!.value;
                          final title = values['title'] as String;
                          final dueDate = values['dueDate'] as DateTime?;

                          final success = await ref
                              .read(
                                taskDetailNotifierProvider(
                                  widget.taskId,
                                ).notifier,
                              )
                              .saveTask(title: title, dueDate: dueDate);

                          if (success && context.mounted) {
                            await ref
                                .read(taskListNotifierProvider.notifier)
                                .refresh();
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
        error: (e, _) =>
            Center(child: AppText(context.l10n.tasksError(e.toString()))),
      ),
    );
  }
}
