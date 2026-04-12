import 'package:flutter/material.dart';
import 'session.dart';
import 'nav.dart';

class AuthGuard {
  static bool _handling = false;

  static Future<void> forceLogin({
    String title = 'Notice',
    String message = '登入已過期，請重新登入。',
    bool clearSession = true,
  }) async {
    if (_handling) return;
    _handling = true;

    try {
      final ctx = rootNavigatorKey.currentContext;
      final nav = rootNavigatorKey.currentState;

      if (clearSession) {
        await Session.clear();
      }

      if (ctx != null && ctx.mounted) {
        await showDialog<void>(
          context: ctx,
          barrierDismissible: false,
          builder:
              (dialogContext) => AlertDialog(
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('前往登入'),
                  ),
                ],
              ),
        );
      }

      nav?.pushNamedAndRemoveUntil(
        '/login',
        (_) => false,
      );
    } finally {
      _handling = false;
    }
  }
}
