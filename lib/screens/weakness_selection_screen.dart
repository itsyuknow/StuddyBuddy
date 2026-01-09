import 'package:flutter/material.dart';
import '../services/user_session.dart';
import 'login_screen.dart';
import 'main_app_screen.dart';

class WeaknessSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> examData;
  final List<String> selectedStrengths;

  const WeaknessSelectionScreen({
    super.key,
    required this.examData,
    required this.selectedStrengths,
  });

  @override
  State<WeaknessSelectionScreen> createState() =>
      _WeaknessSelectionScreenState();
}

class _WeaknessSelectionScreenState extends State<WeaknessSelectionScreen> {
  List<String> selectedWeaknesses = [];

  @override
  Widget build(BuildContext context) {
    List<dynamic> weaknesses = widget.examData['weaknesses'] ?? [];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 20),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Areas for Improvement',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Select subjects where you need support.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ...weaknesses.map<Widget>((weaknessData) {
                          String subject = weaknessData['subject'] ?? '';
                          List<dynamic> subtopics =
                              weaknessData['subtopics'] ?? [];

                          return _buildSubjectSection(
                              subject, subtopics.cast<String>());
                        }).toList(),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: selectedWeaknesses.isEmpty
                                ? null
                                : () async {
                              await _handleSearchBuddy(context);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: selectedWeaknesses.isEmpty
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.white,
                              foregroundColor: selectedWeaknesses.isEmpty
                                  ? Colors.white.withOpacity(0.5)
                                  : const Color(0xFF8A1FFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Search My Buddy',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            2,
                                (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 32,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectSection(String subject, List<String> subtopics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subject Header
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Text(
            subject,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        // Subtopics in a compact wrap layout
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: subtopics.map((subtopic) {
            bool isSelected = selectedWeaknesses.contains(subtopic);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    selectedWeaknesses.remove(subtopic);
                  } else {
                    selectedWeaknesses.add(subtopic);
                  }
                });
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 48,
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.15),
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color:
                      isSelected ? const Color(0xFF8A1FFF) : Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        subtopic,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                          isSelected ? const Color(0xFF8A1FFF) : Colors.white,
                        ),
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _handleSearchBuddy(BuildContext context) async {
    bool isLoggedIn = await UserSession.checkLogin();

    if (!isLoggedIn) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            examData: widget.examData,
            selectedStrengths: widget.selectedStrengths,
            selectedWeaknesses: selectedWeaknesses,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => const MainAppScreen(initialTabIndex: 1)),
            (route) => false,
      );
    }
  }
}