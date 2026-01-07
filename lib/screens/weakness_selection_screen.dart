import 'package:flutter/material.dart';
import 'skills_selection_screen.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
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
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select subjects where you need support.\nWe\'ll match you with partners strong in these areas.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: weaknesses.map<Widget>((weakness) {
                    bool isSelected = selectedWeaknesses.contains(weakness);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedWeaknesses.remove(weakness);
                          } else {
                            selectedWeaknesses.add(weakness);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : Colors.white,
                          border: Border.all(
                            color: Colors.black,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: isSelected ? Colors.white : Colors.black,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              weakness,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedWeaknesses.isEmpty
                        ? null
                        : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SkillsSelectionScreen(
                            examData: widget.examData,
                            selectedStrengths: widget.selectedStrengths,
                            selectedWeaknesses: selectedWeaknesses,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: selectedWeaknesses.isEmpty
                          ? Colors.grey.shade300
                          : Colors.black,
                      foregroundColor: Colors.white,
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
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                        (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == 2 ? 32 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index <= 2 ? Colors.black : Colors.grey.shade300,
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
    );
  }
}