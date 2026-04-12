// lib/pages/plant_page.dart
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/api_service.dart';
import '../utils/tools.dart';
import 'plant_edit_page.dart';

class PlantPage extends StatefulWidget {
  final Map<String, dynamic> plant;

  const PlantPage({super.key, required this.plant});

  @override
  State<PlantPage> createState() => _PlantPageState();
}

class _PlantPageState extends State<PlantPage> {
  bool _initDialogShown = false;
  bool _busy = false;
  bool _dirty = false;

  late Map<String, dynamic> _plant;

  final TextEditingController _todayStateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _plant = Map<String, dynamic>.from(widget.plant);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _runBusy<void>(() async => _refreshPlantFromServer());
      if (!mounted) return;
      final ok = await _maybeForceInitialize();
      if (!ok || !mounted) return;
      await _maybeGenerateTasksIfMissing();
    });
  }

  @override
  void dispose() {
    _todayStateCtrl.dispose();
    super.dispose();
  }

  String get _uuid => (_plant['uuid'] ?? '').toString();

  bool _needsInitializationToday() {
    final initStr = (_plant['initialization'] ?? '').toString();
    final d = parseYmd(initStr);
    if (d == null) return true;
    final today = todayDateOnly();
    return DateTime(d.year, d.month, d.day) != today;
  }

  int _careDaysFromSetup() {
    final setupStr = (_plant['setup_time'] ?? '').toString();
    final setup = parseYmd(setupStr);
    if (setup == null) return 0;

    final today = todayDateOnly();
    final diff =
        today.difference(DateTime(setup.year, setup.month, setup.day)).inDays;
    return (diff < 0 ? 0 : diff) + 1;
  }

  String _formatYmdHmsCompact(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y$m$d$hh$mm$ss';
  }

  Map<String, dynamic>? _taskMap() {
    final t = _plant['task'];
    if (t == null) return null;

    if (t is Map<String, dynamic>) return t;
    if (t is Map) return t.map((k, v) => MapEntry(k.toString(), v));

    if (t is String) {
      final s = t.trim();
      if (s.startsWith('{') && s.endsWith('}')) {
        try {
          final decoded = ApiService.tryDecodeJson(s);
          if (decoded is Map) {
            return decoded.map((k, v) => MapEntry(k.toString(), v));
          }
        } catch (_) {}
      }
    }
    return null;
  }

  bool _taskDone(dynamic v) {
    if (v is Map) {
      final s = v['state'];
      return s == true || s?.toString().toLowerCase() == 'true';
    }
    return false;
  }

  String _taskContent(dynamic v, String fallbackKey) {
    if (v is Map) {
      final c = v['content']?.toString() ?? '';
      return c.isEmpty ? fallbackKey : c;
    }
    return fallbackKey;
  }

  Future<void> _refreshPlantFromServer() async {
    final found = await ApiService.getPlantDetail(uuid: _uuid);
    if (!mounted) return;
    setState(() => _plant = Map<String, dynamic>.from(found));
  }

  Future<T?> _runBusy<T>(Future<T?> Function() job) async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      return await job();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _maybeForceInitialize() async {
    if (_initDialogShown) return true;

    if (_needsInitializationToday()) {
      _initDialogShown = true;

      final ok = await _showInitializeDialog();
      if (!mounted) return false;

      if (ok != true) {
        Navigator.of(context).pop(false);
        return false;
      }
    }
    return true;
  }

  Future<bool?> _showInitializeDialog() async {
    _todayStateCtrl.text = '';
    DateTime? lastDt;
    bool saving = false;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Initialization required'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'This plant has not been initialized today.\n'
                      'Please describe the current condition and select the last watering time.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _todayStateCtrl,
                      maxLines: 4,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'Current condition',
                        hintText: 'e.g., soil dry, leaves healthy, pests found...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LastWateringPicker(
                      value: lastDt,
                      onPick: (dt) => setLocal(() => lastDt = dt),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(false),
                  child: const Text('Back'),
                ),
                ElevatedButton(
                  onPressed:
                      saving
                          ? null
                          : () async {
                            final todayState = _todayStateCtrl.text.trim();

                            if (todayState.isEmpty || lastDt == null) {
                              await showAlert(
                                ctx,
                                'Please fill in the condition and last watering time.',
                                title: 'Missing info',
                              );
                              return;
                            }

                            setLocal(() => saving = true);
                            try {
                              final detail = await ApiService.initializePlant(
                                uuid: _uuid,
                                todayState: todayState,
                                lastWateringTime: _formatYmdHmsCompact(lastDt!),
                              );
                              if (!mounted) return;
                              if (!ctx.mounted) return;
                              setState(() {
                                _plant = Map<String, dynamic>.from(detail);
                                _dirty = true;
                              });
                              Navigator.of(ctx).pop(true);
                            } catch (e) {
                              if (!mounted) return;
                              await showAlert(
                                ctx,
                                e.toString(),
                                title: 'Failed',
                              );
                              setLocal(() => saving = false);
                            }
                          },
                  child:
                      saving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _completeTask(String taskKey) async {
    final tasks = _taskMap();
    if (tasks == null || tasks.isEmpty) {
      await showAlert(context, 'No tasks available.', title: 'Tasks');
      return;
    }

    final raw = tasks[taskKey];
    if (raw is! Map) return;

    final alreadyDone = _taskDone(raw);
    if (alreadyDone) {
      await showAlert(
        context,
        'This task is already completed.',
        title: 'Tasks',
      );
      return;
    }

    final updated = <String, dynamic>{};
    for (final entry in tasks.entries) {
      final k = entry.key;
      final v = entry.value;

      if (v is Map) {
        final vv = Map<String, dynamic>.from(
          v.map((kk, vv) => MapEntry(kk.toString(), vv)),
        );
        if (k == taskKey) vv['state'] = true;
        updated[k] = vv;
      } else {
        updated[k] = v;
      }
    }

    setState(() {
      _plant['task'] = updated;
    });

    await _runBusy<void>(() async {
      final ok = await ApiService.updatePlantTask(
        uuid: _uuid,
        task: updated,
      );

      if (!ok) {
        await _refreshPlantFromServer();
        if (!mounted) return;
        await showAlert(context, 'Failed to update task.', title: 'Tasks');
        return;
      }

      await _refreshPlantFromServer();
      await ApiService.me();
      _dirty = true;
    });
  }

  Future<void> _maybeGenerateTasksIfMissing() async {
    if (_needsInitializationToday()) return;
    final existing = _taskMap();
    if (existing != null && existing.isNotEmpty) return;

    await _runBusy<void>(() async {
      final detail = await ApiService.generateTasksForPlant(uuid: _uuid);
      if (!mounted) return;
      setState(() {
        _plant = Map<String, dynamic>.from(detail);
        _dirty = true;
      });
    });
  }

  Future<void> _openEdit() async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(builder: (_) => PlantEditPage(plant: _plant)),
    );
    if (!mounted) return;
    if (result == null) return;

    if (result is Map && result['deleted'] == true) {
      _dirty = true;
      Navigator.of(context).pop(true);
      return;
    }

    if (result is Map<String, dynamic>) {
      setState(() {
        _plant = Map<String, dynamic>.from(result);
        _dirty = true;
      });
      return;
    }

    if (result == true) {
      await _runBusy<void>(() async {
        await _refreshPlantFromServer();
        _dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plantName = (_plant['plant_variety'] ?? '').toString();
    final nickname = (_plant['plant_name'] ?? '').toString();
    final setupTime = (_plant['setup_time'] ?? '').toString();
    final initTime = (_plant['initialization'] ?? '').toString();
    final status = (_plant['plant_state'] ?? '').toString();
    final careDays = _careDaysFromSetup();
    final tasks = _taskMap();

    final caredToday = !_needsInitializationToday();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_dirty);
      },
      child: Stack(
        children: [
          Scaffold(
          body: Stack(
            children: [
              // 背景裝飾
              Positioned(
                top: -60,
                right: -40,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryYellow.withAlpha(77),
                        AppColors.primaryYellow.withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // Header
                    _buildHeader(nickname),

                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        children: [
                          // 狀態卡片
                          _buildStatusCard(caredToday, careDays),

                          const SizedBox(height: 16),

                          // 資訊卡片
                          _buildInfoCard(
                            plantName: plantName,
                            nickname: nickname,
                            setupTime: setupTime,
                            initTime: initTime,
                            status: status,
                            careDays: careDays,
                          ),

                          const SizedBox(height: 16),

                          // 任務卡片
                          _buildTasksCard(tasks),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Busy overlay
        if (_busy)
          Positioned.fill(
            child: Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String nickname) {
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
              onPressed: () => Navigator.of(context).pop(_dirty),
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                nickname.isEmpty ? 'Plant' : nickname,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_rounded, size: 22),
              onPressed: _busy ? null : _openEdit,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool caredToday, int careDays) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.yellowGradient,
        borderRadius: AppRadius.cardRadius,
        boxShadow: AppShadows.button,
      ),
      child: Row(
        children: [
          // 狀態指示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(77),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              caredToday
                  ? Icons.check_circle_rounded
                  : Icons.access_time_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caredToday ? 'Cared Today' : 'Needs Care',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caredToday
                      ? 'Your plant is happy!'
                      : 'Please initialize today',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(230),
                  ),
                ),
              ],
            ),
          ),

          // 天數
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(64),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$careDays days',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String plantName,
    required String nickname,
    required String setupTime,
    required String initTime,
    required String status,
    required int careDays,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.lightYellow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.deepYellow,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Plant Information',
                  style: AppText.sectionTitle.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // 內容
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.local_florist_outlined,
                  label: 'Variety',
                  value: plantName,
                ),
                _InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Nickname',
                  value: nickname,
                ),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Start Date',
                  value: setupTime,
                ),
                _InfoRow(
                  icon: Icons.spa_outlined,
                  label: 'Status',
                  value: status,
                ),
                _InfoRow(
                  icon: Icons.update_rounded,
                  label: 'Last Init',
                  value: initTime,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksCard(Map<String, dynamic>? tasks) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.lightYellow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    color: AppColors.deepYellow,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Today\'s Tasks',
                  style: AppText.sectionTitle.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (tasks != null && tasks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightYellow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tasks.values.where((v) => _taskDone(v)).length}/${tasks.length}',
                      style: const TextStyle(
                        color: AppColors.deepYellow,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 內容
          if (tasks == null || tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'No tasks yet.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children:
                    tasks.entries.map((e) {
                      final key = e.key;
                      final v = e.value;
                      final done = _taskDone(v);
                      final content = _taskContent(v, key);

                      return _TaskItem(
                        content: content,
                        done: done,
                        onTap: done ? null : () => _completeTask(key),
                      );
                    }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      decoration: BoxDecoration(
        border:
            isLast
                ? null
                : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final String content;
  final bool done;
  final VoidCallback? onTap;

  const _TaskItem({required this.content, required this.done, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: done ? AppColors.successLight : AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? AppColors.success : Colors.transparent,
                    border:
                        done
                            ? null
                            : Border.all(color: AppColors.border, width: 2),
                  ),
                  child:
                      done
                          ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          done
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      decoration:
                          done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                    ),
                  ),
                ),
                if (!done)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textHint,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LastWateringPicker extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  const _LastWateringPicker({required this.value, required this.onPick});

  Future<DateTime?> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.deepYellow,
              onPrimary: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null) return null;
    if (!context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime:
          value != null
              ? TimeOfDay(hour: value!.hour, minute: value!.minute)
              : TimeOfDay.fromDateTime(now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.deepYellow,
              onPrimary: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute, 0);
  }

  String _display(DateTime dt) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final dt = await _pickDateTime(context);
        if (dt != null) onPick(dt);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Last watering time',
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(value == null ? 'Tap to select' : _display(value!)),
            ),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }
}
