import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/api_service.dart';
import '../utils/session.dart';
import '../utils/tools.dart';
import '../widgets/app_logo.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class ForceChangePasswordPage extends StatefulWidget {
  const ForceChangePasswordPage({super.key});

  @override
  State<ForceChangePasswordPage> createState() => _ForceChangePasswordPageState();
}

class _ForceChangePasswordPageState extends State<ForceChangePasswordPage> {
  final _form = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _old.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiService.changePassword(
        oldPassword: _old.text,
        newPassword: _next.text,
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } catch (e) {
      final msg = e is ApiException ? e.message : e.toString();
      if (!mounted) return;
      await showAlert(context, msg, title: 'Update Failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Change Password'),
          actions: [
            IconButton(
              onPressed: _loading ? null : _logout,
              icon: const Icon(Icons.logout),
              tooltip: 'Log out',
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.deepYellow.withAlpha(70),
                                blurRadius: 28,
                                spreadRadius: 2,
                                offset: Offset.zero,
                              ),
                            ],
                          ),
                          child: const AppLogo(size: 72),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Your password has been reset. Please change your password to continue.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        controller: _old,
                        label: 'Temporary password (old password)',
                        obscureText: true,
                        validator: (v) => requiredValidator(
                          v?.trim() ?? '',
                          label: 'Temporary password',
                        ),
                        prefixIcon: Icons.lock_outline,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _next,
                        label: 'New password',
                        obscureText: true,
                        validator: (v) => passwordValidator(v ?? ''),
                        prefixIcon: Icons.lock_reset_outlined,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _confirm,
                        label: 'Confirm new password',
                        obscureText: true,
                        validator: (v) =>
                            confirmPasswordValidator(v ?? '', _next.text),
                        prefixIcon: Icons.lock_reset_outlined,
                      ),
                      const SizedBox(height: 22),
                      CustomButton(
                        text: 'Update password',
                        loading: _loading,
                        onPressed: _submit,
                        icon: Icons.check_circle_outline,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
