import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../../core/utils/boot_manager.dart';

const Color _bgDark = Color(0xFF090E17);
const Color _accentCyan = Color(0xFF00E5FF);

double _logoOpacity = 0.0;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _logoOpacity = 1.0;
        });
      }
    });
    _bootApp();
  }

  Future<void> _bootApp() async {
    // 1. Give the UI a half-second to render the cool splash logo smoothly
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // 2. Fire off the location request (triggers permissions and starts background tracking).
    // We intentionally IGNORE whether it succeeds or fails here, because the
    // individual tool screens will handle missing GPS data natively!
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 800)),
      BootManager.initializeLocation(context),
    ]);

    // 3. Unconditionally push the user into the main app
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
      //       Navigator.of(context).pushAndRemoveUntil(
      //   MaterialPageRoute(builder: (_) => const HomeScreen()),
      //   (route) => false,
      // );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              // decoration: BoxDecoration(
              //   color: Colors.white.withValues(alpha: 0.05),
              //   shape: BoxShape.circle,
              //   border: Border.all(color: _accentCyan, width: 1.5),
              // ),
              child: AnimatedOpacity(
                opacity: _logoOpacity,
                duration: const Duration(milliseconds: 800),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 120,
                  height: 120,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "DISHSAT",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _accentCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _accentCyan.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text(
                    "PRO",
                    style: TextStyle(
                      color: _accentCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            // const SizedBox(height: 8),
            // const Text(
            //   "INITIALIZING SYSTEM...",
            //   style: TextStyle(
            //     color: Colors.white54,
            //     fontSize: 10,
            //     fontWeight: FontWeight.bold,
            //     letterSpacing: 2,
            //   ),
            // ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: _accentCyan),
          ],
        ),
      ),
    );
  }
}
