import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../utils/session.dart';
import '../widgets/app_logo.dart';

class LaunchGate extends StatefulWidget {
  const LaunchGate({super.key});

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 設定動畫
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
    _boot();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await Session.init();

    // 確保啟動畫面至少顯示 1.5 秒
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    if (Session.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.lightYellow,
              AppColors.primaryYellow.withAlpha(128),
              AppColors.deepYellow.withAlpha(102),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo 圖標
                  const AppLogo(size: 140),

                  const SizedBox(height: 32),

                  // APP 名稱
                  const Text(
                    'Plant Care',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -1,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 標語
                  Text(
                    'Care for your green friends',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary.withAlpha(179),
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 60),

                  // 載入指示器
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(
                        AppColors.deepYellow.withAlpha(179),
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
  }
}
