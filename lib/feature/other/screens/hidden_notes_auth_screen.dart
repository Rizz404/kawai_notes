import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kawai_notes/core/extensions/theme_extension.dart';
import 'package:kawai_notes/core/utils/toast_utils.dart';
import 'package:kawai_notes/di/service_providers.dart';
import 'package:kawai_notes/feature/notes/widgets/pattern_entry_widget.dart';
import 'package:kawai_notes/feature/notes/widgets/pin_entry_widget.dart';
import 'package:kawai_notes/shared/widgets/app_text.dart';
import 'package:kawai_notes/shared/widgets/screen_wrapper.dart';

enum _SetupPhase { none, enter, confirm }

enum _TargetMethod { none, pin, pattern, password }

class HiddenNotesAuthScreen extends ConsumerStatefulWidget {
  const HiddenNotesAuthScreen({super.key});

  @override
  ConsumerState<HiddenNotesAuthScreen> createState() =>
      _HiddenNotesAuthScreenState();
}

class _HiddenNotesAuthScreenState extends ConsumerState<HiddenNotesAuthScreen> {
  _SetupPhase _phase = _SetupPhase.none;
  _TargetMethod _target = _TargetMethod.none;

  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _pinEnabled = false;
  bool _patternEnabled = false;
  bool _passwordEnabled = false;
  bool _loading = true;

  String? _pendingPin;
  List<int>? _pendingPattern;
  String? _errorMessage;

  final int _pinEnterKey = 0;
  int _pinConfirmKey = 0;
  final int _patternEnterKey = 0;
  int _patternConfirmKey = 0;

  final _pwdController = TextEditingController();
  final _pwdConfirmController = TextEditingController();
  bool _pwdObscure = true;
  bool _pwdConfirmObscure = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _pwdController.dispose();
    _pwdConfirmController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final service = ref.read(hiddenNotesAuthServiceProvider);
    final results = await Future.wait<bool>([
      service.isBiometricAvailable(),
      service.isBiometricEnabled(),
      service.isPinEnabled(),
      service.isPatternEnabled(),
      service.isPasswordEnabled(),
    ]);
    if (!mounted) return;
    setState(() {
      _biometricAvailable = results[0];
      _biometricEnabled = results[1];
      _pinEnabled = results[2];
      _patternEnabled = results[3];
      _passwordEnabled = results[4];
      _loading = false;
    });
  }

  void _cancelSetup() {
    setState(() {
      _phase = _SetupPhase.none;
      _target = _TargetMethod.none;
      _pendingPin = null;
      _pendingPattern = null;
      _errorMessage = null;
      _pwdController.clear();
      _pwdConfirmController.clear();
    });
  }

  void _startSetup(_TargetMethod method) {
    setState(() {
      _target = method;
      _phase = _SetupPhase.enter;
      _errorMessage = null;
    });
  }

  // --- Biometric ---

  Future<void> _toggleBiometric(bool enabled) async {
    await ref.read(hiddenNotesAuthServiceProvider).setBiometricEnabled(enabled);
    setState(() => _biometricEnabled = enabled);
  }

  // --- PIN ---

  void _onEnterPin(String pin) {
    setState(() {
      _pendingPin = pin;
      _phase = _SetupPhase.confirm;
      _errorMessage = null;
    });
  }

  Future<void> _onConfirmPin(String pin) async {
    if (pin != _pendingPin) {
      setState(() {
        _errorMessage = "PINs don't match. Try again.";
        _pinConfirmKey++;
      });
      return;
    }
    await ref.read(hiddenNotesAuthServiceProvider).setupPin(pin);
    await _loadState();
    if (!mounted) return;
    _cancelSetup();
    AppToast.success('PIN set up successfully');
  }

  Future<void> _removePin() async {
    if (!await _confirmRemove('Remove PIN?')) return;
    await ref.read(hiddenNotesAuthServiceProvider).removePin();
    await _loadState();
    if (mounted) AppToast.success('PIN removed');
  }

  // --- Pattern ---

  void _onEnterPattern(List<int> pattern) {
    setState(() {
      _pendingPattern = List.from(pattern);
      _phase = _SetupPhase.confirm;
      _errorMessage = null;
    });
  }

  Future<void> _onConfirmPattern(List<int> pattern) async {
    if (pattern.join(',') != _pendingPattern!.join(',')) {
      setState(() {
        _errorMessage = "Patterns don't match. Try again.";
        _patternConfirmKey++;
      });
      return;
    }
    await ref.read(hiddenNotesAuthServiceProvider).setupPattern(pattern);
    await _loadState();
    if (!mounted) return;
    _cancelSetup();
    AppToast.success('Pattern set up successfully');
  }

  Future<void> _removePattern() async {
    if (!await _confirmRemove('Remove pattern?')) return;
    await ref.read(hiddenNotesAuthServiceProvider).removePattern();
    await _loadState();
    if (mounted) AppToast.success('Pattern removed');
  }

  // --- Password ---

  Future<void> _setupPassword() async {
    final pwd = _pwdController.text;
    final confirm = _pwdConfirmController.text;
    if (pwd.isEmpty) {
      setState(() => _errorMessage = 'Password cannot be empty');
      return;
    }
    if (pwd != confirm) {
      setState(() => _errorMessage = "Passwords don't match");
      return;
    }
    await ref.read(hiddenNotesAuthServiceProvider).setupPassword(pwd);
    await _loadState();
    if (!mounted) return;
    _cancelSetup();
    AppToast.success('Password set up successfully');
  }

  Future<void> _removePassword() async {
    if (!await _confirmRemove('Remove password?')) return;
    await ref.read(hiddenNotesAuthServiceProvider).removePassword();
    await _loadState();
    if (mounted) AppToast.success('Password removed');
  }

  // --- Helpers ---

  Future<bool> _confirmRemove(String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AppText(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const AppText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: AppText('Remove', color: context.colorScheme.error),
          ),
        ],
      ),
    );
    return result == true;
  }

  String get _setupTitle => switch (_target) {
        _TargetMethod.pin =>
          _phase == _SetupPhase.confirm ? 'Confirm PIN' : 'Enter new PIN',
        _TargetMethod.pattern => _phase == _SetupPhase.confirm
            ? 'Confirm Pattern'
            : 'Draw new Pattern',
        _TargetMethod.password => 'Set up Password',
        _TargetMethod.none => 'Hidden Notes Lock',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _phase != _SetupPhase.none
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _cancelSetup,
              )
            : null,
        title: AppText(
          _phase != _SetupPhase.none ? _setupTitle : 'Hidden Notes Lock',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_phase == _SetupPhase.none) return _buildList();
    return switch (_target) {
      _TargetMethod.pin => _buildPinSetup(),
      _TargetMethod.pattern => _buildPatternSetup(),
      _TargetMethod.password => _buildPasswordSetup(),
      _TargetMethod.none => _buildList(),
    };
  }

  Widget _buildList() {
    return ScreenWrapper(
      child: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const AppText('Biometric'),
            subtitle: !_biometricAvailable
                ? const AppText('Not available on this device')
                : AppText(_biometricEnabled ? 'Enabled' : 'Disabled'),
            value: _biometricEnabled && _biometricAvailable,
            onChanged: _biometricAvailable ? _toggleBiometric : null,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.dialpad_outlined),
            title: const AppText('PIN'),
            subtitle: AppText(_pinEnabled ? 'Enabled' : 'Not set up'),
            trailing: _pinEnabled
                ? _MethodActions(
                    onChange: () => _startSetup(_TargetMethod.pin),
                    onRemove: _removePin,
                  )
                : TextButton(
                    onPressed: () => _startSetup(_TargetMethod.pin),
                    child: const AppText('Set up'),
                  ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.grid_view_outlined),
            title: const AppText('Pattern'),
            subtitle: AppText(_patternEnabled ? 'Enabled' : 'Not set up'),
            trailing: _patternEnabled
                ? _MethodActions(
                    onChange: () => _startSetup(_TargetMethod.pattern),
                    onRemove: _removePattern,
                  )
                : TextButton(
                    onPressed: () => _startSetup(_TargetMethod.pattern),
                    child: const AppText('Set up'),
                  ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: const AppText('Password'),
            subtitle: AppText(_passwordEnabled ? 'Enabled' : 'Not set up'),
            trailing: _passwordEnabled
                ? _MethodActions(
                    onChange: () => _startSetup(_TargetMethod.password),
                    onRemove: _removePassword,
                  )
                : TextButton(
                    onPressed: () => _startSetup(_TargetMethod.password),
                    child: const AppText('Set up'),
                  ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppText(
              'Enable multiple methods to use them as fallback if one fails.',
              style: AppTextStyle.bodySmall,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinSetup() {
    final isConfirm = _phase == _SetupPhase.confirm;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PinEntryWidget(
          key: ValueKey(
            isConfirm ? 'confirm_$_pinConfirmKey' : 'enter_$_pinEnterKey',
          ),
          onPinComplete: isConfirm ? _onConfirmPin : _onEnterPin,
          errorMessage: _errorMessage,
        ),
      ),
    );
  }

  Widget _buildPatternSetup() {
    final isConfirm = _phase == _SetupPhase.confirm;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PatternEntryWidget(
          key: ValueKey(
            isConfirm
                ? 'confirm_$_patternConfirmKey'
                : 'enter_$_patternEnterKey',
          ),
          onPatternComplete: isConfirm ? _onConfirmPattern : _onEnterPattern,
          errorMessage: _errorMessage,
        ),
      ),
    );
  }

  Widget _buildPasswordSetup() {
    return ScreenWrapper(
      child: ListView(
        children: [
          const SizedBox(height: 24),
          TextField(
            controller: _pwdController,
            obscureText: _pwdObscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'New password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _pwdObscure = !_pwdObscure),
                icon: Icon(
                  _pwdObscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pwdConfirmController,
            obscureText: _pwdConfirmObscure,
            decoration: InputDecoration(
              labelText: 'Confirm password',
              errorText: _errorMessage,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _pwdConfirmObscure = !_pwdConfirmObscure),
                icon: Icon(
                  _pwdConfirmObscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            onSubmitted: (_) => _setupPassword(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _setupPassword,
            child: const AppText('Save Password'),
          ),
        ],
      ),
    );
  }
}

class _MethodActions extends StatelessWidget {
  final VoidCallback onChange;
  final VoidCallback onRemove;

  const _MethodActions({required this.onChange, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'change') onChange();
        if (v == 'remove') onRemove();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'change', child: AppText('Change')),
        PopupMenuItem(
          value: 'remove',
          child: AppText('Remove', color: context.colorScheme.error),
        ),
      ],
    );
  }
}
