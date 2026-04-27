import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:kawai_notes/core/extensions/theme_extension.dart';
import 'package:kawai_notes/shared/widgets/app_button.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';
import 'package:kawai_notes/shared/widgets/app_text_field.dart';
import 'package:kawai_notes/shared/widgets/screen_wrapper.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isLogin = true;
  bool _isLoading = false;

  void _submit() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final data = _formKey.currentState!.value;
      setState(() => _isLoading = true);

      // TODO: Implement Supabase Auth
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Autentikasi belum dihubungkan dengan Supabase!'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: AppText('Cloud Sync / Cloud Backup')),
      body: ScreenWrapper(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.cloud_sync,
                size: 80,
                color: context.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              AppText(
                _isLogin ? 'Login ke Cloud' : 'Daftar Cloud',
                style: AppTextStyle.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const AppText(
                'Amankan catatan Anda di Cloud Storage.\nMasuk untuk melanjutkan.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FormBuilder(
                key: _formKey,
                child: Column(
                  children: [
                    AppTextField(
                      name: 'email',
                      label: 'Email',
                      placeHolder: 'Masukkan alamat email',
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(),
                        FormBuilderValidators.email(),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      name: 'password',
                      label: 'Password',
                      placeHolder: 'Masukkan kata sandi',
                      type: AppTextFieldType.password,
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(),
                        FormBuilderValidators.minLength(6),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      text: _isLogin ? 'Masuk' : 'Daftar',
                      onPressed: _submit,
                      isLoading: _isLoading,
                      isFullWidth: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: AppText(
                  _isLogin
                      ? 'Belum punya akun? Daftar'
                      : 'Sudah punya akun? Masuk',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
