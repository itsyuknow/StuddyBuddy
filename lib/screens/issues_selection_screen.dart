import 'package:flutter/material.dart';
import '../services/user_session.dart';
import 'login_screen.dart';
import 'main_app_screen.dart';

class IssuesSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> examData;
  final List<String> selectedStrengths;
  final List<String> selectedWeaknesses;
  final List<String> selectedSkills;

  const IssuesSelectionScreen({
    super.key,
    required this.examData,
    required this.selectedStrengths,
    required this.selectedWeaknesses,
    required this.selectedSkills,
  });

  @override
  State<IssuesSelectionScreen> createState() => _IssuesSelectionScreenState();
}

class _IssuesSelectionScreenState extends State<IssuesSelectionScreen> {
  List<String> selectedIssues = [];

  @override
  Widget build(BuildContext context) {
    List<dynamic> issues = widget.examData['study_issues'] ?? [];

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
                  'Study Challenges',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'What challenges do you face?\nWe\'ll find partners who can help overcome these.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                Column(
                  children: issues.map<Widget>((issue) {
                    bool isSelected = selectedIssues.contains(issue);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedIssues.remove(issue);
                          } else {
                            selectedIssues.add(issue);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : Colors.white,
                          border: Border.all(
                            color: Colors.black,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: isSelected ? Colors.white : Colors.black,
                              size: 20,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                issue,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color:
                                  isSelected ? Colors.white : Colors.black,
                                ),
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
                    onPressed: selectedIssues.isEmpty
                        ? null
                        : () async {
                      await _handleSearchBuddy(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: selectedIssues.isEmpty
                          ? Colors.grey.shade300
                          : Colors.black,
                      foregroundColor: Colors.white,
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
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                        (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 32,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.black,
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
            selectedWeaknesses: widget.selectedWeaknesses,
            selectedSkills: widget.selectedSkills,
            selectedIssues: selectedIssues,
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