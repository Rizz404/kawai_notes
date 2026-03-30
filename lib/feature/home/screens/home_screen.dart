import 'package:flutter/material.dart';
import 'package:flutter_setup_riverpod/core/extensions/navigator_extension.dart';
import 'package:flutter_setup_riverpod/shared/widgets/app_button.dart';
import 'package:flutter_setup_riverpod/shared/widgets/screen_wrapper.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const ScreenWrapper(child: Placeholder()),
      floatingActionButton: AppButton(
        text: 'Navigate to Second Page',
        onPressed: () => context.push('/second-page'),
      ),
    );
  }
}
