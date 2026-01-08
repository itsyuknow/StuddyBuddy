import 'package:flutter/material.dart';
import 'dart:math' as math;

class MatchAnimationScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final Map<String, dynamic> matchedUser;
  final int matchPercentage;

  const MatchAnimationScreen({
    super.key,
    required this.currentUser,
    required this.matchedUser,
    required this.matchPercentage,
  });

  @override
  State<MatchAnimationScreen> createState() => _MatchAnimationScreenState();
}

class _MatchAnimationScreenState extends State<MatchAnimationScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _heartController;
  late AnimationController _percentController;
  late AnimationController _confettiController;

  late Animation<Offset> _leftSlideAnimation;
  late Animation<Offset> _rightSlideAnimation;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _heartRotateAnimation;
  late Animation<double> _percentAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Slide animation for avatars
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _leftSlideAnimation = Tween<Offset>(
      begin: const Offset(-2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _rightSlideAnimation = Tween<Offset>(
      begin: const Offset(2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    // Book animation
    _heartController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _heartScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _heartController,
      curve: Curves.elasticOut,
    ));

    _heartRotateAnimation = Tween<double>(
      begin: 0.0,
      end: math.pi * 2,
    ).animate(CurvedAnimation(
      parent: _heartController,
      curve: Curves.easeInOut,
    ));

    // Percentage animation
    _percentController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _percentAnimation = Tween<double>(
      begin: 0.0,
      end: widget.matchPercentage.toDouble(),
    ).animate(CurvedAnimation(
      parent: _percentController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _percentController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    ));

    // Confetti animation
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _slideController.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    _heartController.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    _percentController.forward();

    await Future.delayed(const Duration(milliseconds: 100));
    _confettiController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _heartController.dispose();
    _percentController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Confetti background
            AnimatedBuilder(
              animation: _confettiController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: ConfettiPainter(_confettiController.value),
                );
              },
            ),

            // Main content
            Column(
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 28, color: Color(0xFF8A1FFF)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // Avatars with book icon
                SizedBox(
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Left avatar (current user)
                      SlideTransition(
                        position: _leftSlideAnimation,
                        child: Transform.translate(
                          offset: const Offset(-40, 0),
                          child: _buildAvatar(
                            widget.currentUser['avatar_url'],
                            widget.currentUser['full_name'] ?? 'You',
                            120,
                          ),
                        ),
                      ),

                      // Right avatar (matched user)
                      SlideTransition(
                        position: _rightSlideAnimation,
                        child: Transform.translate(
                          offset: const Offset(40, 0),
                          child: _buildAvatar(
                            widget.matchedUser['avatar_url'],
                            widget.matchedUser['full_name'] ?? 'User',
                            120,
                          ),
                        ),
                      ),

                      // Book icon in center
                      AnimatedBuilder(
                        animation: _heartController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _heartScaleAnimation.value,
                            child: Transform.rotate(
                              angle: _heartRotateAnimation.value,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF8A1FFF).withOpacity(0.4),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // "It's a Match!" text
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFF8A1FFF),
                            Color(0xFFC43AFF),
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          "It's a Match!",
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You and ${widget.matchedUser['full_name'] ?? 'this user'}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'are perfect study partners!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Match percentage circle
                AnimatedBuilder(
                  animation: _percentAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8A1FFF).withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_percentAnimation.value.toInt()}%',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'MATCH',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const Spacer(flex: 1),

                // Action buttons
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                              ),
                              borderRadius: BorderRadius.all(Radius.circular(16)),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x4D8A1FFF),
                                  blurRadius: 15,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                // Navigate to chat or profile
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Say Hi 👋',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8A1FFF),
                              side: const BorderSide(color: Color(0xFF8A1FFF), width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Keep Looking',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String userName, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF8A1FFF),
            Color(0xFFC43AFF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A1FFF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(4),
        child: ClipOval(
          child: avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl != 'null'
              ? Image.network(
            avatarUrl,
            width: size - 16,
            height: size - 16,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildAvatarFallback(userName, size - 16),
          )
              : _buildAvatarFallback(userName, size - 16),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String userName, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
        ),
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final double animationValue;
  final List<ConfettiParticle> particles = [];

  ConfettiPainter(this.animationValue) {
    // Generate confetti particles
    final random = math.Random(42); // Fixed seed for consistent animation
    for (int i = 0; i < 50; i++) {
      particles.add(ConfettiParticle(
        x: random.nextDouble(),
        y: random.nextDouble() * 0.5 - 0.2,
        color: [
          const Color(0xFF8A1FFF),
          const Color(0xFFC43AFF),
          Colors.pink,
          Colors.blue,
          Colors.purple,
          Colors.orange,
        ][random.nextInt(6)],
        size: random.nextDouble() * 8 + 4,
        rotation: random.nextDouble() * math.pi * 2,
        speed: random.nextDouble() * 0.5 + 0.5,
      ));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(
          (1 - animationValue).clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.fill;

      final x = particle.x * size.width;
      final y = particle.y * size.height + (animationValue * particle.speed * size.height);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.rotation + (animationValue * math.pi * 4));

      // Draw confetti as small rectangles
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size,
            height: particle.size * 1.5,
          ),
          const Radius.circular(2),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue;
  }
}

class ConfettiParticle {
  final double x;
  final double y;
  final Color color;
  final double size;
  final double rotation;
  final double speed;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.rotation,
    required this.speed,
  });
}