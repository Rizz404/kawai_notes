import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/theme_extension.dart';
import 'package:kawai_notes/core/services/hidden_notes_auth_service.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/notes/widgets/pattern_entry_widget.dart';
import 'package:kawai_notes/feature/notes/widgets/pin_entry_widget.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';

class HiddenNotesAuthBody extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const HiddenNotesAuthBody({
    super.key,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  ConsumerState<HiddenNotesAuthBody> createState() =>
      _HiddenNotesAuthBodyState();
}

class _HiddenNotesAuthBodyState extends ConsumerState<HiddenNotesAuthBody> {
  Set<HiddenNotesAuthMethod> _enabledMethods = {};
  HiddenNotesAuthMethod? _currentMethod;
  bool _loading = true;
  String? _errorMessage;
  int _pinResetKey = 0;
  int _patternResetKey = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final service = ref.read(hiddenNotesAuthServiceProvider);
    final methods = await service.getEnabledMethods();
    if (!mounted) return;

    if (methods.isEmpty) {
      widget.onSuccess();
      return;
    }

    setState(() {
      _enabledMethods = methods;
      _loading = false;
    });

    if (methods.contains(HiddenNotesAuthMethod.biometric)) {
      setState(() => _currentMethod = HiddenNotesAuthMethod.biometric);
      _tryBiometric();
    } else {
      setState(() => _currentMethod = methods.first);
    }
  }

  Future<void> _tryBiometric() async {
    final service = ref.read(hiddenNotesAuthServiceProvider);
    final ok = await service.authenticateWithBiometric();
    if (!mounted) return;
    if (ok) {
      widget.onSuccess();
      return;
    }
    final fallback = _enabledMethods
        .where((m) => m != HiddenNotesAuthMethod.biometric)
        .firstOrNull;
    setState(() {
      _currentMethod = fallback ?? HiddenNotesAuthMethod.biometric;
      if (fallback == null) _errorMessage = 'Biometric failed. Try again.';
    });
  }

  Future<void> _onPinComplete(String pin) async {
    final ok = await ref.read(hiddenNotesAuthServiceProvider).verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      widget.onSuccess();
    } else {
      setState(() {
        _errorMessage = 'Wrong PIN. Try again.';
        _pinResetKey++;
      });
    }
  }

  Future<void> _onPatternComplete(List<int> pattern) async {
    final ok =
        await ref.read(hiddenNotesAuthServiceProvider).verifyPattern(pattern);
    if (!mounted) return;
    if (ok) {
      widget.onSuccess();
    } else {
      setState(() {
        _errorMessage = 'Wrong pattern. Try again.';
        _patternResetKey++;
      });
    }
  }

  Future<void> _onPasswordSubmit(String password) async {
    final ok = await ref
        .read(hiddenNotesAuthServiceProvider)
        .verifyPassword(password);
    if (!mounted) return;
    if (ok) {
      widget.onSuccess();
    } else {
      setState(() => _errorMessage = 'Wrong password. Try again.');
    }
  }

  List<HiddenNotesAuthMethod> get _alternatives =>
      _enabledMethods.where((m) => m != _currentMethod).toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: context.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const AppText('Hidden Notes', style: AppTextStyle.titleMedium),
            const SizedBox(height: 32),
            _buildCurrentMethod(),
            if (_alternatives.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildAlternatives(),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: widget.onCancel,
              child: const AppText('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentMethod() {
    return switch (_currentMethod) {
      HiddenNotesAuthMethod.biometric => _buildBiometric(),
      HiddenNotesAuthMethod.pin => PinEntryWidget(
          key: ValueKey('pin_$_pinResetKey'),
          onPinComplete: _onPinComplete,
          errorMessage: _errorMessage,
        ),
      HiddenNotesAuthMethod.pattern => PatternEntryWidget(
          key: ValueKey('pattern_$_patternResetKey'),
          onPatternComplete: _onPatternComplete,
          errorMessage: _errorMessage,
        ),
      HiddenNotesAuthMethod.password => _PasswordEntry(
          errorMessage: _errorMessage,
          onSubmit: _onPasswordSubmit,
        ),
      null => const SizedBox.shrink(),
    };
  }

  Widget _buildBiometric() {
    return Column(
      children: [
        const AppText(
          'Use biometric to continue',
          style: AppTextStyle.bodyMedium,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          AppText(
            _errorMessage!,
            color: context.colorScheme.error,
            style: AppTextStyle.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _tryBiometric,
          icon: const Icon(Icons.fingerprint),
          label: const AppText('Authenticate'),
        ),
      ],
    );
  }

  Widget _buildAlternatives() {
    return Column(
      children: [
        AppText(
          'Use another method',
          style: AppTextStyle.labelMedium,
          color: context.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _alternatives
              .map(
                (m) => OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentMethod = m;
                      _errorMessage = null;
                    });
                    if (m == HiddenNotesAuthMethod.biometric) _tryBiometric();
                  },
                  child: AppText(_label(m)),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  String _label(HiddenNotesAuthMethod m) => switch (m) {
        HiddenNotesAuthMethod.biometric => 'Biometric',
        HiddenNotesAuthMethod.pin => 'PIN',
        HiddenNotesAuthMethod.pattern => 'Pattern',
        HiddenNotesAuthMethod.password => 'Password',
      };
}

class _PasswordEntry extends StatefulWidget {
  final String? errorMessage;
  final void Function(String) onSubmit;

  const _PasswordEntry({this.errorMessage, required this.onSubmit});

  @override
  State<_PasswordEntry> createState() => _PasswordEntryState();
}

class _PasswordEntryState extends State<_PasswordEntry> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          obscureText: _obscure,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter password',
            errorText: widget.errorMessage,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          onSubmitted: widget.onSubmit,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => widget.onSubmit(_controller.text),
          child: const AppText('Confirm'),
        ),
      ],
    );
  }
}
