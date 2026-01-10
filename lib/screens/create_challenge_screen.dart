import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/challenge_service.dart';
import '../services/user_session.dart';

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> with AutomaticKeepAliveClientMixin {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetScoreController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  File? _selectedImage;
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;

  // Challenge settings
  String? _selectedExamId;
  String? _selectedSubject;
  String _selectedDifficulty = 'medium';
  int _selectedDuration = 7;

  List<Map<String, dynamic>> _exams = [];
  List<String> _subjects = [];

  bool _isKeyboardVisible = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    try {
      final response = await _supabase
          .from('exams')
          .select('id, short_name, full_name')
          .eq('is_active', true)
          .order('sort_order');

      setState(() {
        _exams = (response as List).map((e) => {
          'id': e['id'],
          'short_name': e['short_name'],
          'full_name': e['full_name'],
        }).toList();
      });
    } catch (e) {
      print('Error loading exams: $e');
    }
  }

  Future<void> _loadSubjects(String examId) async {
    try {
      final subjects = await ChallengeService.getExamSubjects(examId);
      setState(() {
        _subjects = subjects;
        _selectedSubject = null;
      });
    } catch (e) {
      print('Error loading subjects: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetScoreController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 90,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Add Challenge Photo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildImageSourceOption(
                icon: Icons.photo_library_rounded,
                title: 'Choose from Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 12),
              _buildImageSourceOption(
                icon: Icons.camera_alt_rounded,
                title: 'Take Photo',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 12),
              _buildImageSourceOption(
                icon: Icons.close_rounded,
                title: 'Cancel',
                isCancel: true,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isCancel = false,
  }) {
    return Material(
      color: isCancel ? Colors.grey.shade100 : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isCancel ? Colors.grey.shade300 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: isCancel ? Colors.grey.shade700 : const Color(0xFF8A1FFF)),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isCancel ? Colors.grey.shade700 : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createChallenge() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedExamId == null) {
      _showMessage('Please select an exam', isError: true);
      return;
    }
    if (_selectedSubject == null) {
      _showMessage('Please select a subject', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final targetScore = _targetScoreController.text.trim().isNotEmpty
          ? int.tryParse(_targetScoreController.text.trim())
          : null;

      final result = await ChallengeService.createChallenge(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        examId: _selectedExamId!,
        subject: _selectedSubject!,
        difficulty: _selectedDifficulty,
        durationDays: _selectedDuration,
        targetScore: targetScore,
        imageFile: _selectedImage,
      );

      if (!mounted) return;

      if (result['success']) {
        _showMessage('🏆 Challenge created successfully!', isError: false);

        _titleController.clear();
        _descriptionController.clear();
        _targetScoreController.clear();
        setState(() {
          _selectedImage = null;
          _selectedExamId = null;
          _selectedSubject = null;
          _subjects.clear();
          _selectedDifficulty = 'medium';
          _selectedDuration = 7;
        });
      } else {
        _showMessage(result['error'] ?? 'Failed to create challenge', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('An error occurred: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Check if keyboard is visible
    _isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildChallengeHeader(),
                    const SizedBox(height: 16),
                    _buildImageSection(),
                    const SizedBox(height: 16),
                    _buildBasicInfo(),
                    const SizedBox(height: 16),
                    _buildChallengeSettings(),
                    const SizedBox(height: 100), // Add space for button
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildSubmitButton(),
    );
  }

  Widget _buildChallengeHeader() {
    final user = _supabase.auth.currentUser;
    final userName = UserSession.userData?['full_name'] ?? user?.email?.split('@')[0] ?? 'User';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8A1FFF), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🏆 Create a Challenge',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Challenge others to beat your score!',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return GestureDetector(
      onTap: _selectedImage == null ? _showImageSourceSheet : null,
      child: Container(
        width: double.infinity,
        height: _selectedImage != null ? 200 : 140, // REDUCED heights
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: _selectedImage == null
              ? const LinearGradient(
            colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
          )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF8A1FFF)),
        ),
        child: _selectedImage == null
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_outlined, size: 48, color: Colors.white), // REDUCED size
            const SizedBox(height: 8),
            const Text(
              'Add Challenge Image',
              style: TextStyle(
                fontSize: 14, // REDUCED size
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Show your achievement',
              style: TextStyle(
                fontSize: 12, // REDUCED size
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        )
            : Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _selectedImage!,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => setState(() => _selectedImage = null),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: _showImageSourceSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Change',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Challenge Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Challenge Title',
              hintText: 'e.g., "Beat my NEET Biology score"',
              prefixIcon: const Icon(Icons.title, color: Color(0xFF8A1FFF)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF8A1FFF), width: 2),
              ),
            ),
            maxLength: 100,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a title';
              }
              if (value.trim().length < 5) {
                return 'Title must be at least 5 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'Describe the challenge, rules, and what you expect...',
              prefixIcon: const Icon(Icons.description, color: Color(0xFF8A1FFF)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF8A1FFF), width: 2),
              ),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            maxLength: 500,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a description';
              }
              if (value.trim().length < 20) {
                return 'Description must be at least 20 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeSettings() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Challenge Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),

          // Exam Selection
          DropdownButtonFormField<String>(
            value: _selectedExamId,
            decoration: InputDecoration(
              labelText: 'Select Exam',
              prefixIcon: const Icon(Icons.school, color: Color(0xFF8A1FFF)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF8A1FFF), width: 2),
              ),
            ),
            items: _exams.map((exam) {
              return DropdownMenuItem<String>(
                value: exam['id'],
                child: Text(exam['short_name']),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedExamId = value;
                if (value != null) {
                  _loadSubjects(value);
                }
              });
            },
          ),

          const SizedBox(height: 16),

          // Subject Selection
          DropdownButtonFormField<String>(
            value: _selectedSubject,
            decoration: InputDecoration(
              labelText: 'Select Subject',
              prefixIcon: const Icon(Icons.book, color: Color(0xFF8A1FFF)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF8A1FFF), width: 2),
              ),
            ),
            items: _subjects.map((subject) {
              return DropdownMenuItem<String>(
                value: subject,
                child: Text(subject),
              );
            }).toList(),
            onChanged: _selectedExamId == null
                ? null
                : (value) {
              setState(() {
                _selectedSubject = value;
              });
            },
          ),

          const SizedBox(height: 16),

          // Difficulty
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed, color: Color(0xFF8A1FFF)),
                    const SizedBox(width: 8),
                    const Text(
                      'Difficulty Level',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDifficultyChip('easy', 'Easy', Colors.green),
                    const SizedBox(width: 8),
                    _buildDifficultyChip('medium', 'Medium', Colors.orange),
                    const SizedBox(width: 8),
                    _buildDifficultyChip('hard', 'Hard', Colors.red),
                  ],
                )
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Duration
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer, color: Color(0xFF8A1FFF)),
                    const SizedBox(width: 8),
                    const Text(
                      'Challenge Duration',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDurationChip(3, '3 Days'),
                      const SizedBox(width: 8),
                      _buildDurationChip(7, '1 Week'),
                      const SizedBox(width: 8),
                      _buildDurationChip(14, '2 Weeks'),
                      const SizedBox(width: 8),
                      _buildDurationChip(30, '1 Month'),
                    ],
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Target Score (Optional)
          TextFormField(
            controller: _targetScoreController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Target Score (Optional)',
              hintText: 'e.g., 95',
              prefixIcon: const Icon(Icons.stars, color: Color(0xFF8A1FFF)),
              suffixText: 'points',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF8A1FFF), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyChip(String value, String label, Color color) {
    final isSelected = _selectedDifficulty == value;
    return Flexible(  // Changed from Expanded to Flexible
      child: GestureDetector(
        onTap: () => setState(() => _selectedDifficulty = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),  // Added horizontal padding
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip(int days, String label) {
    final isSelected = _selectedDuration == days;
    return GestureDetector(
      onTap: () => setState(() => _selectedDuration = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
            colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
          )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF8A1FFF) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _titleController.text.trim().length >= 5 &&
        _descriptionController.text.trim().length >= 20 &&
        _selectedExamId != null &&
        _selectedSubject != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false, // ADD THIS
        child: Container(
          width: double.infinity,
          height: 52, // REDUCED from 56
          decoration: BoxDecoration(
            gradient: canSubmit && !_isLoading
                ? const LinearGradient(
              colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
            )
                : null,
            color: canSubmit && !_isLoading ? null : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(16),
            boxShadow: canSubmit && !_isLoading
                ? [
              BoxShadow(
                color: const Color(0xFF8A1FFF).withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ]
                : null,
          ),
          child: ElevatedButton.icon(
            onPressed: canSubmit && !_isLoading ? _createChallenge : null,
            icon: _isLoading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.emoji_events, color: Colors.white, size: 20),
            label: Text(
              _isLoading ? 'Creating...' : 'Create Challenge',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}