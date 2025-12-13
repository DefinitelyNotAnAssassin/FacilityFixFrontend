import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:facilityfix/landingpage/login.dart';
import 'package:facilityfix/landingpage/signup.dart';

class LoginOrSignup extends StatefulWidget {
  final String role;
  const LoginOrSignup({super.key, required this.role});

  @override
  State<LoginOrSignup> createState() => _LoginOrSignupState();
}

class _LoginOrSignupState extends State<LoginOrSignup>
    with SingleTickerProviderStateMixin {
  static const blue = Color(0xFF426CC2);
  static const brandBlue = Color(0xFF005CE7);

  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _welcomeSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _buttonsOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
    );

    _welcomeSlide = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.55, curve: Curves.easeOutBack),
    );

    _taglineOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.75, curve: Curves.easeIn),
    );

    _buttonsOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.65, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openLoginModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LogIn(role: 'tenant'),
    );
  }

  void _openSignUpModal(BuildContext context) {
    // Present a role selection sheet first before opening SignUp
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: 220,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Register as',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF005CE7),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF005CE7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 120), () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const SignUp(role: 'tenant'),
                        );
                      });
                    },
                    child: const Text(
                      'Tenant',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFF005CE7),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 120), () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const SignUp(role: 'staff'),
                        );
                      });
                    },
                    child: const Text(
                      'Staff',
                      style: TextStyle(color: Color(0xFF005CE7)),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const refW = 393.0;
    const refH = 852.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;
            final sx = w / refW;
            final sy = h / refH;
            final scale = (sx < sy ? sx : sy);

            // Adjusted: slightly higher curve
            const ovalLeft = -291.0,
                ovalTop = -200.0,
                ovalW = 974.0,
                ovalH = 722.0;

            // Logo resized and moved up slightly
            const logoLeft = 96.0, logoTop = 45.0, logoW = 200.0, logoH = 180.0;

            return Stack(
              children: [
                // 🔵 Blue curved background
                Positioned(
                  left: ovalLeft * sx,
                  top: ovalTop * sy,
                  child: Container(
                    width: ovalW * sx,
                    height: ovalH * sy,
                    decoration: const ShapeDecoration(
                      color: blue,
                      shape: OvalBorder(),
                    ),
                  ),
                ),

                // 🏢 Logo (fade in, now 200px)
                Positioned(
                  left: logoLeft * sx,
                  top: logoTop * sy,
                  child: FadeTransition(
                    opacity: _logoOpacity,
                    child: SizedBox(
                      width: logoW * sx,
                      height: logoH * sy,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/logo.png'),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 👋 “Welcome” text — moved slightly upward
                AnimatedBuilder(
                  animation: _welcomeSlide,
                  builder: (context, _) {
                    final offsetY = 40 * (1 - _welcomeSlide.value);
                    return Positioned(
                      left: 0,
                      right: 0,
                      top: (h * 0.43) + offsetY,
                      child: Opacity(
                        opacity: _welcomeSlide.value.clamp(0.0, 1.0),
                        child: Text(
                          'Welcome',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34 * scale,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // 📝 Tagline — also moved up slightly
                Positioned(
                  left: 28 * sx,
                  right: 28 * sx,
                  top: h * 0.50, // was 0.55 → now higher
                  child: FadeTransition(
                    opacity: _taglineOpacity,
                    child: Text(
                      'Log in to your account or create one to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 15 * scale,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),

                // 🔐 Buttons
                Positioned(
                  left: 32 * sx,
                  right: 32 * sx,
                  bottom: 160 * sy,
                  child: FadeTransition(
                    opacity: _buttonsOpacity,
                    child: Column(
                      children: [
                        // Log In
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandBlue,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              _openLoginModal(context);
                            },
                            child: const Text(
                              'Log In',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Sign Up
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: brandBlue,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              _openSignUpModal(context);
                            },
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: brandBlue,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 📃 Footer
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 40 * sy,
                  child: FadeTransition(
                    opacity: _buttonsOpacity,
                    child: Opacity(
                      opacity: 0.85,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'By continuing, you agree to our ',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF98A2B3),
                            ),
                          ),
                          Text(
                            'Terms',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: brandBlue,
                            ),
                          ),
                          Text(
                            ' & ',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF98A2B3),
                            ),
                          ),
                          Text(
                            'Privacy',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: brandBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
