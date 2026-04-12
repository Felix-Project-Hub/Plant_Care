// lib/pages/greenhouse_page.dart
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/api_service.dart';
import '../utils/session.dart';
import '../utils/tools.dart';
import 'plant_create_sheet.dart';
import 'plant_page.dart';

class GreenhousePage extends StatefulWidget {
  const GreenhousePage({super.key});

  @override
  State<GreenhousePage> createState() => _GreenhousePageState();
}

class _GreenhousePageState extends State<GreenhousePage> {
  List<Map<String, dynamic>> _plants = [];
  bool _loaded = false;

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
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    try {
      if (!Session.isLoggedIn) return;
      final res = await ApiService.getPlantInfo();
      await ApiService.me();
      if (!mounted) return;
      setState(() {
        _plants = res;
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loaded = true);
      if (!mounted) return;
      await showAlert(context, e.toString(), title: 'Greenhouse Error');
    }
  }

  bool _caredToday(String? initDateStr) {
    final d = parseYmd(initDateStr);
    if (d == null) return false;
    final today = todayDateOnly();
    return DateTime(d.year, d.month, d.day) == today;
  }

  String _careDays(String? setupDateStr) {
    final setup = parseYmd(setupDateStr);
    if (setup == null) return '-';
    final today = todayDateOnly();
    final diff =
        today.difference(DateTime(setup.year, setup.month, setup.day)).inDays;
    final days = (diff < 0 ? 0 : diff) + 1;
    return '$days days';
  }

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PlantCreateSheet(),
    );

    if (created == true) {
      await _loadPlants();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景裝飾
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
            bottom: 100,
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

          // 主內容
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // 植物列表
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadPlants,
                    color: AppColors.deepYellow,
                    child:
                        _loaded
                            ? (_plants.isEmpty
                                ? const _EmptyState()
                                : ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    8,
                                    20,
                                    100,
                                  ),
                                  itemCount: _plants.length,
                                  itemBuilder: (context, i) {
                                    final p = _plants[i];

                                    final name =
                                        (p['plant_name'] ?? '').toString();
                                    final variety =
                                        (p['plant_variety'] ?? '').toString();
                                    final state =
                                        (p['plant_state'] ?? '').toString();
                                    final setupTime =
                                        (p['setup_time'] ?? '').toString();
                                    final init =
                                        (p['initialization'] ?? '').toString();

                                    final cared = _caredToday(init);
                                    final daysText = _careDays(setupTime);

                                    return _PlantCard(
                                      name: name,
                                      variety: variety,
                                      state: state,
                                      caredToday: cared,
                                      daysText: daysText,
                                      onTap: () async {
                                        if (!Session.isLoggedIn) {
                                          await showAlert(
                                            context,
                                            'Please login again.',
                                            title: 'Session',
                                          );
                                          return;
                                        }

                                        final shouldRefresh =
                                            await Navigator.push<bool>(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (_) => PlantPage(
                                                      plant: p,
                                                    ),
                                              ),
                                            );

                                        if (shouldRefresh == true) {
                                          await _loadPlants();
                                        }
                                      },
                                    );
                                  },
                                ))
                            : Center(
                              child: CircularProgressIndicator(
                                color: AppColors.deepYellow,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppColors.yellowGradient,
          shape: BoxShape.circle,
          boxShadow: AppShadows.button,
        ),
        child: FloatingActionButton(
          onPressed: _openCreate,
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 12),
      child: Row(
        children: [
          // 返回按鈕
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
            ),
          ),

          const Expanded(
            child: Center(
              child: Text(
                'Greenhouse',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),

          // 點數
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.lightYellow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      size: 16,
                      color: AppColors.deepYellow,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${Session.points}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepYellow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.lightYellow,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.park_outlined,
                      size: 48,
                      color: AppColors.deepYellow,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No plants yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap + to add your first plant',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlantCard extends StatelessWidget {
  final String name;
  final String variety;
  final String state;
  final bool caredToday;
  final String daysText;
  final VoidCallback? onTap;

  const _PlantCard({
    required this.name,
    required this.variety,
    required this.state,
    required this.caredToday,
    required this.daysText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.cardBg,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardRadius,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.borderLight),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 狀態指示器
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: caredToday ? AppColors.success : AppColors.error,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (caredToday
                                    ? AppColors.success
                                    : AppColors.error)
                                .withAlpha(102),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 名稱
                    Expanded(
                      child: Text(
                        name.isEmpty ? '-' : name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // 天數
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.yellowGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        daysText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 詳細資訊
                Row(
                  children: [
                    _InfoTag(
                      icon: Icons.local_florist_outlined,
                      text: variety.isEmpty ? '-' : variety,
                    ),
                    const SizedBox(width: 12),
                    _InfoTag(
                      icon: Icons.spa_outlined,
                      text: state.isEmpty ? '-' : state,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoTag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
