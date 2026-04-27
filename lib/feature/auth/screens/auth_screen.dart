import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:kawai_notes/core/extensions/localization_extension.dart';
import 'package:kawai_notes/core/extensions/theme_extension.dart';
import 'package:kawai_notes/feature/auth/providers/auth_provider.dart';
import 'package:kawai_notes/shared/widgets/app_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
      final email = _formKey.currentState!.value['email'] as String;
      final password = _formKey.currentState!.value['password'] as String;

      setState(() => _isLoading = true);

      try {
        final client = ref.read(supabaseClientProvider);
        if (client == null) throw Exception('Supabase belum terkonfigurasi');

        if (_isLogin) {
          await client.auth.signInWithPassword(
            email: email,
            password: password,
          );
        } else {
          await client.auth.signUp(email: email, password: password);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: AppText(context.l10n.authError(e.toString()))));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    try {
      final client = ref.read(supabaseClientProvider);
      if (client == null) throw Exception('Supabase belum terkonfigurasi');

      // ! Wajib pakai externalBrowser agar Android bisa intercept deep link callback
      await client.auth.signInWithOAuth(
        provider,
        redirectTo: 'com.rizz.kawainotes://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(context.l10n.authLoginError(e.toString()))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(supabaseClientProvider);
    final user = ref.watch(currentUserProvider);

    if (user != null) {
      return Scaffold(
        appBar: AppBar(title: AppText(context.l10n.authCloudAccount)),
        body: ScreenWrapper(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                AppText(
                  context.l10n.authLoggedInAs,
                  style: AppTextStyle.titleMedium,
                ),
                AppText(user.email ?? 'User', style: AppTextStyle.bodyLarge),
                const SizedBox(height: 32),
                AppButton(
                  text: context.l10n.authLogout,
                  onPressed: () async {
                    await client?.auth.signOut();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: AppText(context.l10n.authCloudSyncTitle)),
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
                _isLogin ? context.l10n.authLoginTitle : context.l10n.authRegisterTitle,
                style: AppTextStyle.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              AppText(
                context.l10n.authSubtitle,
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
                      placeHolder: context.l10n.authEmailPlaceholder,
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(),
                        FormBuilderValidators.email(),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      name: 'password',
                      label: 'Password',
                      placeHolder: context.l10n.authPasswordPlaceholder,
                      type: AppTextFieldType.password,
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(),
                        FormBuilderValidators.minLength(6),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      text: _isLogin ? context.l10n.authSignIn : context.l10n.authRegister,
                      onPressed: _submit,
                      isLoading: _isLoading,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: AppText(context.l10n.authOr),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // TODO: Aktifkan kembali ketika configurasi Google sudah selesai
                    // AppButton(
                    //   text: 'Tautan Akun Google',
                    //   onPressed: () => _signInWithOAuth(OAuthProvider.google),
                    //   isFullWidth: true,
                    // ),
                    // const SizedBox(height: 8),
                    AppButton(
                      text: context.l10n.authLinkGitHub,
                      onPressed: () => _signInWithOAuth(OAuthProvider.github),
                      isFullWidth: true,
                      leadingIcon: const FaIcon(FontAwesomeIcons.github),
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
                      ? context.l10n.authNoAccount
                      : context.l10n.authHasAccount,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
