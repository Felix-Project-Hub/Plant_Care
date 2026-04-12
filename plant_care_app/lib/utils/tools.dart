// lib/utils/tools.dart
import 'package:flutter/material.dart';

// 一般提示
Future<void> showAlert(
  BuildContext context,
  String msg, {
  String title = 'Notice',
}) async {
  return showDialog<void>(
    context: context,
    builder:
        (dialogCtx) => AlertDialog(
          title: Text(title),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
  );
}

// 確認對話框（OK / Cancel）
Future<bool> confirmDialog(
  BuildContext context, {
  String title = 'Confirm',
  required String message,
  String okText = 'OK',
  String cancelText = 'Cancel',
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder:
        (dialogCtx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(okText),
            ),
          ],
        ),
  );
  return res == true;
}

// 公告內容對話框（內容可滾動）
Future<void> showAnnouncementDialog(
  BuildContext context, {
  required String title,
  required String date,
  required String content,
}) async {
  // 引入 constants 來使用配色
  const primaryColor = Color(0xFFFFD54F);
  const deepColor = Color(0xFFFBC02D);
  const lightColor = Color(0xFFFFF8E1);

  return showDialog<void>(
    context: context,
    builder:
        (dialogCtx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header 區域
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryColor, deepColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(64),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.campaign_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          formatFriendlyDateTime(date),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withAlpha(230),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 內容區域
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 320,
                  minWidth: 300,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    content,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
              ),

              // 關閉按鈕
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: lightColor,
                      foregroundColor: deepColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
  );
}

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

// ---------- Validators ----------
String? requiredValidator(String? v, {String label = 'This field'}) {
  if (v == null || v.trim().isEmpty) return '$label is required';
  return null;
}

String? emailValidator(String? v) {
  if (v == null || v.trim().isEmpty) return 'Email is required';
  final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
  return ok ? null : 'Invalid email format';
}

String? passwordValidator(String? v) {
  if (v == null || v.length < 8) {
    return 'Password must be at least 8 characters';
  }
  return null;
}

String? confirmPasswordValidator(String? v, String original) {
  if (v == null || v.isEmpty) return 'Please confirm your password';
  if (v != original) return 'Passwords do not match';
  return null;
}

// ---------- 日期工具 ----------
// YYYYMMDD (no separators)
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

DateTime todayDateOnly() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

// 將多種日期格式轉成 DateTime（失敗回 null）
// 支援：YYYYMMDD、YYYY-MM-DD、YYYY/MM/DD、ISO 格式等
DateTime? parseYmd(String? s) {
  if (s == null) return null;
  final t = s.trim();
  if (t.isEmpty) return null;

  if (RegExp(r'^\d{14}$').hasMatch(t)) {
    final y = int.tryParse(t.substring(0, 4));
    final m = int.tryParse(t.substring(4, 6));
    final d = int.tryParse(t.substring(6, 8));
    if (y != null && m != null && d != null) {
      try {
        return DateTime(y, m, d);
      } catch (_) {
        return null;
      }
    }
  }

  if (RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(t)) {
    final isoLike = t.replaceFirst(' ', 'T');
    final dt = DateTime.tryParse(isoLike);
    if (dt != null) {
      return DateTime(dt.year, dt.month, dt.day);
    }
  }

  // ISO format (e.g., 2024-01-01T12:00:00)
  final iso = DateTime.tryParse(t);
  if (iso != null) {
    return DateTime(iso.year, iso.month, iso.day);
  }

  // YYYYMMDD format
  if (RegExp(r'^\d{8}$').hasMatch(t)) {
    final y = int.tryParse(t.substring(0, 4));
    final m = int.tryParse(t.substring(4, 6));
    final d = int.tryParse(t.substring(6, 8));
    if (y != null && m != null && d != null) {
      try {
        return DateTime(y, m, d);
      } catch (_) {
        return null;
      }
    }
  }

  // YYYY-MM-DD or YYYY/MM/DD format
  final match = RegExp(r'^(\d{4})\D(\d{1,2})\D(\d{1,2})').firstMatch(t);
  if (match != null) {
    final y = int.tryParse(match.group(1)!);
    final m = int.tryParse(match.group(2)!);
    final d = int.tryParse(match.group(3)!);
    if (y != null && m != null && d != null) {
      try {
        return DateTime(y, m, d);
      } catch (_) {
        return null;
      }
    }
  }

  return null;
}

/// 格式化為友善的相對時間
/// 例如：今天、昨天、2 天前、2025-12-19
String formatRelativeDate(String? dateStr) {
  final date = parseYmd(dateStr);
  if (date == null) return '-';

  final now = todayDateOnly();
  final dateOnly = DateTime(date.year, date.month, date.day);
  final diff = now.difference(dateOnly).inDays;

  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (diff == 2) return '前天';
  if (diff > 0 && diff <= 7) return '$diff 天前';

  // 超過 7 天顯示完整日期
  return formatDate(date);
}

/// 格式化為 YYYY-MM-DD
String formatDate(DateTime date) {
  final y = date.year.toString();
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// 格式化為友善的日期時間（用於公告等）
String formatFriendlyDateTime(String? dateStr) {
  final date = parseYmd(dateStr);
  if (date == null) return '-';

  final now = todayDateOnly();
  final dateOnly = DateTime(date.year, date.month, date.day);
  final diff = now.difference(dateOnly).inDays;

  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (diff > 0 && diff <= 7) return '$diff 天前';

  // 超過 7 天顯示月/日
  final m = date.month.toString();
  final d = date.day.toString();
  return '$m/$d';
}
