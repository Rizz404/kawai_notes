import 'package:flutter/material.dart';
import 'package:kawai_notes/core/extensions/navigator_extension.dart';
import 'package:kawai_notes/feature/notes/widgets/hidden_notes_auth_body.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';

class HiddenNotesAuthChallengeScreen extends StatelessWidget {
  const HiddenNotesAuthChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const AppText('Verify Identity'),
      ),
      body: HiddenNotesAuthBody(
        onSuccess: () => context.replace('/hidden-notes'),
        onCancel: () => context.pop(),
      ),
    );
  }
}
