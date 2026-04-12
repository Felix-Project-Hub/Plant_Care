import 'dart:async';
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/api_service.dart';
import '../utils/session.dart';
import '../utils/tools.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _birthday = TextEditingController();
  DateTime? _birthdayValue;

  bool _loading = false;
  bool _saving = false;
  bool _deletingAccount = false;
  bool _changingPassword = false;

  @override
  void initState() {
    super.initState();
    if (!Session.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      });
      return;
    }
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _birthday.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final me = await ApiService.me();
      if (!mounted) return;
      _name.text = (me['name'] ?? '').toString();
      _email.text = (me['email'] ?? '').toString();
      _phone.text = (me['phone'] ?? '').toString();
      final bd = parseYmd(me['birthday']?.toString());
      _birthdayValue = bd;
      _birthday.text = bd == null ? '' : formatDate(bd);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.code == 404) {
        await showAlert(
          context,
          'Profile API not found (404). Please restart/redeploy the backend to apply the latest changes.',
          title: 'Load Failed',
        );
      } else {
        await showAlert(context, e.toString(), title: 'Load Failed');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final initial =
        _birthdayValue ?? DateTime(now.year - 20, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _birthdayValue = DateTime(picked.year, picked.month, picked.day);
      _birthday.text = formatDate(_birthdayValue!);
    });
  }

  void _clearBirthday() {
    setState(() {
      _birthdayValue = null;
      _birthday.text = '';
    });
  }

  Future<void> _onSave() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ApiService.updateProfile(
        name: _name.text,
        email: _email.text,
        phone: _phone.text,
        birthday: _birthdayValue == null ? '' : ymd(_birthdayValue!),
      );
      if (!mounted) return;
      showSnack(context, 'Saved');
    } catch (e) {
      if (!mounted) return;
      await showAlert(context, e.toString(), title: 'Save Failed');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onLogout() async {
    final ok = await confirmDialog(
      context,
      title: 'Log Out',
      message: 'Are you sure you want to log out?',
      okText: 'Log out',
      cancelText: 'Cancel',
    );
    if (!ok) return;
    await Session.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _onChangePassword() async {
    String oldDraft = '';
    String newDraft = '';
    String confirmDraft = '';
    String? oldError;
    String? newError;
    String? confirmError;

    final payload = await showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    obscureText: true,
                    onChanged: (v) => oldDraft = v,
                    decoration: InputDecoration(
                      labelText: 'Old password',
                      errorText: oldError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    obscureText: true,
                    onChanged: (v) => newDraft = v,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      errorText: newError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    obscureText: true,
                    onChanged: (v) => confirmDraft = v,
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      errorText: confirmError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final o = oldDraft;
                    final n = newDraft;
                    final c = confirmDraft;

                    final oe = requiredValidator(o, label: 'Old password');
                    final ne = passwordValidator(n);
                    final ce = confirmPasswordValidator(c, n);

                    setState(() {
                      oldError = oe;
                      newError = ne;
                      confirmError = ce;
                    });

                    if (oe != null || ne != null || ce != null) return;

                    Navigator.of(ctx).pop({'old': o, 'new': n});
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    if (payload == null) return;
    if (!mounted) return;

    setState(() => _changingPassword = true);
    try {
      await ApiService.changePassword(
        oldPassword: payload['old'] ?? '',
        newPassword: payload['new'] ?? '',
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      showSnack(context, 'Password updated');
    } catch (e) {
      if (!mounted) return;
      await showAlert(context, e.toString(), title: 'Update Failed');
    } finally {
      if (mounted) {
        setState(() => _changingPassword = false);
      }
    }
  }

  Future<void> _onDeleteAccount() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete Account',
      message: 'This action cannot be undone. Do you want to continue?',
      okText: 'Continue',
      cancelText: 'Cancel',
    );
    if (!ok) return;
    if (!mounted) return;

    String passwordDraft = '';
    String? errorText;
    final password = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Enter password to delete account'),
              content: TextField(
                obscureText: true,
                onChanged: (v) => passwordDraft = v,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final value = passwordDraft.trim();
                    if (value.isEmpty) {
                      setState(() => errorText = 'Password is required');
                      return;
                    }
                    Navigator.of(ctx).pop(value);
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    if (password == null || password.isEmpty) return;
    if (!mounted) return;

    setState(() => _deletingAccount = true);
    try {
      try {
        await ApiService.deleteAccount(
          password: password,
        ).timeout(const Duration(seconds: 12));
      } on TimeoutException {
        var deleted = false;
        for (var i = 0; i < 4; i++) {
          try {
            await ApiService.me().timeout(const Duration(seconds: 2));
          } on ApiException catch (e) {
            if (e.code == 401) {
              deleted = true;
              break;
            }
          }
          if (i < 3) {
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
        }
        if (!deleted) {
          rethrow;
        }
      }

      if (!mounted) return;
      unawaited(Session.clear().catchError((_) {}));
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    } catch (e) {
      if (!mounted) return;
      await showAlert(context, e.toString(), title: 'Delete Failed');
    } finally {
      if (mounted) {
        setState(() => _deletingAccount = false);
      }
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.soft,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              color: AppColors.textSecondary,
              tooltip: 'Back',
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.soft,
            ),
            child: IconButton(
              tooltip: 'Log out',
              onPressed: _onLogout,
              icon: const Icon(Icons.logout_rounded, size: 22),
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _deletingAccount || _changingPassword;
    final busyText =
        _deletingAccount ? 'Deleting account...' : 'Updating password...';
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryYellow.withAlpha(64),
                    AppColors.primaryYellow.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.deepYellow.withAlpha(51),
                    AppColors.deepYellow.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child:
                      _loading
                          ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.deepYellow,
                            ),
                          )
                          : LayoutBuilder(
                            builder: (context, constraints) {
                              return Padding(
                                padding: AppSpacing.pagePadding,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 520,
                                      ),
                                      child: Form(
                                        key: _form,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Card(
                                              child: Padding(
                                                padding: AppSpacing.cardPadding,
                                                child: Column(
                                                  children: [
                                                    CustomTextField(
                                                      controller: _name,
                                                      label: 'Name',
                                                      prefixIcon:
                                                          Icons.person_outline,
                                                      validator:
                                                          (v) =>
                                                              requiredValidator(
                                                                v,
                                                                label: 'Name',
                                                              ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    CustomTextField(
                                                      controller: _email,
                                                      label: 'Email',
                                                      prefixIcon:
                                                          Icons.email_outlined,
                                                      keyboardType:
                                                          TextInputType
                                                              .emailAddress,
                                                      validator: emailValidator,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    CustomTextField(
                                                      controller: _phone,
                                                      label: 'Phone',
                                                      prefixIcon:
                                                          Icons.phone_outlined,
                                                      keyboardType:
                                                          TextInputType.phone,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    CustomTextField(
                                                      controller: _birthday,
                                                      label: 'Birthday',
                                                      prefixIcon:
                                                          Icons.cake_outlined,
                                                      readOnly: true,
                                                      onTap: _pickBirthday,
                                                      hintText:
                                                          'Tap to pick a date',
                                                      suffixIcon:
                                                          _birthdayValue == null
                                                              ? const Icon(
                                                                Icons
                                                                    .calendar_month_outlined,
                                                              )
                                                              : IconButton(
                                                                onPressed:
                                                                    _clearBirthday,
                                                                icon: const Icon(
                                                                  Icons
                                                                      .clear_rounded,
                                                                ),
                                                              ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            CustomButton(
                                              text: 'Save',
                                              icon: Icons.save_outlined,
                                              onPressed: busy ? null : _onSave,
                                              loading: _saving,
                                            ),
                                            const SizedBox(height: 12),
                                            CustomButton(
                                              text: 'Change Password',
                                              icon: Icons.lock_reset_outlined,
                                              outlined: true,
                                              onPressed:
                                                  busy
                                                      ? null
                                                      : _onChangePassword,
                                            ),
                                            const SizedBox(height: 24),
                                            TextButton(
                                              onPressed:
                                                  busy
                                                      ? null
                                                      : _onDeleteAccount,
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.error,
                                              ),
                                              child: const Text(
                                                'Delete Account',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
          if (busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withAlpha(90),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.deepYellow,
                          ),
                          const SizedBox(height: 16),
                          Text(busyText),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
