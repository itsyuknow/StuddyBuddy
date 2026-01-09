import 'package:flutter/material.dart';
import 'weakness_selection_screen.dart';

class StrengthSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> examData;

  const StrengthSelectionScreen({super.key, required this.examData});

  @override
  State<StrengthSelectionScreen> createState() =>
      _StrengthSelectionScreenState();
}

class _StrengthSelectionScreenState extends State<StrengthSelectionScreen> {
  List<String> selectedStrengths = [];

  @override
  Widget build(BuildContext context) {
    List<dynamic> strengths = widget.examData['strengths'] ?? [];

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
                          'Your Strengths',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Select subjects you\'re confident in for ${widget.examData['short_name']}.',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ...strengths.map<Widget>((strengthData) {
                          String subject = strengthData['subject'] ?? '';
                          List<dynamic> subtopics =
                              strengthData['subtopics'] ?? [];

                          return _buildSubjectSection(
                              subject, subtopics.cast<String>());
                        }).toList(),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: selectedStrengths.isEmpty
                                ? null
                                : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WeaknessSelectionScreen(
                                    examData: widget.examData,
                                    selectedStrengths: selectedStrengths,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: selectedStrengths.isEmpty
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.white,
                              foregroundColor: selectedStrengths.isEmpty
                                  ? Colors.white.withOpacity(0.5)
                                  : const Color(0xFF8A1FFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Continue',
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
                              width: index == 0 ? 32 : 8,
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
            bool isSelected = selectedStrengths.contains(subtopic);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    selectedStrengths.remove(subtopic);
                  } else {
                    selectedStrengths.add(subtopic);
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
}