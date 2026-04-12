import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/api_service.dart';
import '../utils/session.dart';
import '../utils/tools.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class PlantEditPage extends StatefulWidget {
  final Map<String, dynamic> plant;

  const PlantEditPage({super.key, required this.plant});

  @override
  State<PlantEditPage> createState() => _PlantEditPageState();
}

class _PlantEditPageState extends State<PlantEditPage> {
  final _form = GlobalKey<FormState>();
  final _variety = TextEditingController();
  final _name = TextEditingController();
  final _setupTime = TextEditingController();

  DateTime? _setupDate;
  String _state = 'seedling';

  bool _loading = false;
  bool _saving = false;
  bool _deleting = false;

  late Map<String, dynamic> _plant;

  String get _uuid => (_plant['uuid'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _plant = Map<String, dynamic>.from(widget.plant);
    _hydrateFromPlant(_plant);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _load();
    });
  }

  @override
  void dispose() {
    _variety.dispose();
    _name.dispose();
    _setupTime.dispose();
    super.dispose();
  }

  void _hydrateFromPlant(Map<String, dynamic> p) {
    _variety.text = (p['plant_variety'] ?? '').toString();
    _name.text = (p['plant_name'] ?? '').toString();
    _state = ((p['plant_state'] ?? 'seedling').toString()).trim();

    final setup = parseYmd((p['setup_time'] ?? '').toString());
    _setupDate = setup;
    _setupTime.text = setup == null ? '' : formatDate(setup);
  }

  Future<void> _load() async {
    if (!Session.isLoggedIn) return;
    setState(() => _loading = true);
    try {
      final detail = await ApiService.getPlantDetail(uuid: _uuid);
      if (!mounted) return;
      setState(() {
        _plant = Map<String, dynamic>.from(detail);
      });
      _hydrateFromPlant(_plant);
    } catch (e) {
      if (!mounted) return;
      await showAlert(context, e.toString(), title: 'Load Failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickSetupDate() async {
    final now = DateTime.now();
    final initial = _setupDate ?? DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _setupDate = DateTime(picked.year, picked.month, picked.day);
      _setupTime.text = formatDate(_setupDate!);
    });
  }

  Future<void> _onSave() async {
    if (!_form.currentState!.validate()) return;
    if (_setupDate == null) {
      await showAlert(context, 'Please select setup date.', title: 'Missing');
      return;
    }
    if (!Session.isLoggedIn) {
      await showAlert(context, 'Please sign in again.', title: 'No session');
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await ApiService.updatePlant(
        uuid: _uuid,
        plantVariety: _variety.text.trim(),
        plantName: _name.text.trim(),
        plantState: _state,
        setupTime: ymd(_setupDate!),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      await showAlert(context, e.toString(), title: 'Save Failed');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onDelete() async {
    if (!Session.isLoggedIn) {
      await showAlert(context, 'Please sign in again.', title: 'No session');
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Delete Plant',
      message: 'Are you sure you want to delete this plant?',
      okText: 'Delete',
      cancelText: 'Cancel',
    );
    if (!ok) return;

    setState(() => _deleting = true);
    try {
      await ApiService.deletePlant(uuid: _uuid);
      if (!mounted) return;
      Navigator.of(context).pop({'deleted': true});
    } catch (e) {
      if (!mounted) return;
      await showAlert(context, e.toString(), title: 'Delete Failed');
    } finally {
      if (mounted) setState(() => _deleting = false);
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
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Edit Plant',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildStateField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: AppRadius.inputRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _state.isEmpty ? 'seedling' : _state,
        onChanged:
            (_saving || _deleting) ? null : (v) => setState(() => _state = v!),
        items: const [
          DropdownMenuItem(value: 'seedling', child: Text('🌱 Seedling')),
          DropdownMenuItem(value: 'growing', child: Text('🌿 Growing')),
          DropdownMenuItem(value: 'stable', child: Text('🌳 Stable')),
        ],
        decoration: const InputDecoration(
          labelText: 'Growth Stage',
          prefixIcon: Icon(Icons.spa_outlined),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        dropdownColor: AppColors.cardBg,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Card(
                                              child: Padding(
                                                padding: AppSpacing.cardPadding,
                                                child: Column(
                                                  children: [
                                                    CustomTextField(
                                                      controller: _variety,
                                                      label: 'Plant Variety',
                                                      prefixIcon:
                                                          Icons
                                                              .local_florist_outlined,
                                                      validator:
                                                          (v) =>
                                                              requiredValidator(
                                                                v,
                                                                label:
                                                                    'Plant Variety',
                                                              ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    CustomTextField(
                                                      controller: _name,
                                                      label: 'Plant Nickname',
                                                      prefixIcon:
                                                          Icons.badge_outlined,
                                                      validator:
                                                          (v) =>
                                                              requiredValidator(
                                                                v,
                                                                label:
                                                                    'Plant Nickname',
                                                              ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    _buildStateField(),
                                                    const SizedBox(height: 16),
                                                    CustomTextField(
                                                      controller: _setupTime,
                                                      label: 'Setup Date',
                                                      prefixIcon:
                                                          Icons.event_outlined,
                                                      readOnly: true,
                                                      onTap:
                                                          busy
                                                              ? null
                                                              : _pickSetupDate,
                                                      hintText:
                                                          'Tap to pick a date',
                                                      suffixIcon: const Icon(
                                                        Icons
                                                            .calendar_month_outlined,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            CustomButton(
                                              text: 'Save',
                                              icon: Icons.save_rounded,
                                              onPressed: busy ? null : _onSave,
                                              loading: _saving,
                                            ),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              height: 52,
                                              child: OutlinedButton.icon(
                                                onPressed:
                                                    busy ? null : _onDelete,
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      AppColors.error,
                                                  side: BorderSide(
                                                    color:
                                                        busy
                                                            ? AppColors.border
                                                            : AppColors.error,
                                                    width: 2,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        AppRadius.buttonRadius,
                                                  ),
                                                  padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          vertical: 14,
                                                        ),
                                                ),
                                                icon: _deleting
                                                    ? const SizedBox(
                                                        height: 22,
                                                        width: 22,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor:
                                                              AlwaysStoppedAnimation(
                                                            AppColors.error,
                                                          ),
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons.delete_rounded,
                                                        size: 20,
                                                      ),
                                                label: Text(
                                                  _deleting
                                                      ? 'Deleting...'
                                                      : 'Delete Plant',
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
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
        ],
      ),
    );
  }
}
