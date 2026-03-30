import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_setup_riverpod/core/extensions/theme_extension.dart';

class AppToast {
  AppToast._();

  static const Duration _defaultDuration = Duration(seconds: 3);

  static void success(
    String message, {
    Duration? duration,
    VoidCallback? onTap,
  }) {
    if (message.isEmpty) return;
    BotToast.showCustomText(
      duration: duration ?? _defaultDuration,
      onlyOne: true,
      toastBuilder: (context) =>
          _ToastCard(message: message, type: _ToastType.success, onTap: onTap),
    );
  }

  static void error(String message, {Duration? duration, VoidCallback? onTap}) {
    if (message.isEmpty) return;
    BotToast.showCustomText(
      duration: duration ?? _defaultDuration,
      onlyOne: true,
      toastBuilder: (context) =>
          _ToastCard(message: message, type: _ToastType.error, onTap: onTap),
    );
  }

  static void warning(
    String message, {
    Duration? duration,
    VoidCallback? onTap,
  }) {
    if (message.isEmpty) return;
    BotToast.showCustomText(
      duration: duration ?? _defaultDuration,
      onlyOne: true,
      toastBuilder: (context) =>
          _ToastCard(message: message, type: _ToastType.warning, onTap: onTap),
    );
  }

  static void info(String message, {Duration? duration, VoidCallback? onTap}) {
    if (message.isEmpty) return;
    BotToast.showCustomText(
      duration: duration ?? _defaultDuration,
      onlyOne: true,
      toastBuilder: (context) =>
          _ToastCard(message: message, type: _ToastType.info, onTap: onTap),
    );
  }

  static void serverError(
    String message, {
    Duration? duration,
    VoidCallback? onTap,
  }) {
    if (message.isEmpty) return;
    BotToast.showCustomText(
      duration: duration ?? _defaultDuration,
      onlyOne: false,
      toastBuilder: (context) => _ToastCard(
        message: message,
        type: _ToastType.serverError,
        onTap: onTap,
      ),
    );
  }
}

enum _ToastType { success, error, warning, info, serverError }

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.message, required this.type, this.onTap});

  final String message;
  final _ToastType type;
  final VoidCallback? onTap;

  Color _getBackgroundColor(BuildContext context) {
    final semantic = context.semantic;
    switch (type) {
      case _ToastType.success:
        return semantic.success;
      case _ToastType.error:
        return semantic.error;
      case _ToastType.warning:
        return semantic.warning;
      case _ToastType.info:
        return semantic.info;
      case _ToastType.serverError:
        return context.colorScheme.tertiaryContainer;
    }
  }

  IconData _getIcon() {
    switch (type) {
      case _ToastType.success:
        return Icons.check_circle;
      case _ToastType.error:
        return Icons.error;
      case _ToastType.warning:
        return Icons.warning;
      case _ToastType.info:
        return Icons.info;
      case _ToastType.serverError:
        return Icons.cloud_off;
    }
  }

  Color _getTextColor(BuildContext context) {
    if (type == _ToastType.serverError) {
      return context.colorScheme.onTertiaryContainer;
    }
    return context.colors.textOnPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _getBackgroundColor(context),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: context.colors.scrim,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getIcon(), color: _getTextColor(context), size: 24),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: _getTextColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
