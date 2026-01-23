import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/challenge_service.dart';
import '../services/image_picker_service.dart';
import '../services/user_session.dart';
import 'main_app_screen.dart';

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> with AutomaticKeepAliveClientMixin {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetScoreController = TextEditingController();
  final _linkController = TextEditingController(); // NEW
  final _formKey = GlobalKey<FormState>();
  List<dynamic> _selectedImages = []; // Changed to List for multiple images
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;
 // Changed from File? _selectedImage;

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
    _linkController.dispose(); // NEW
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_selectedImages.length >= 5) {
      _showMessage('You can only add up to 5 images', isError: true);
      return;
    }

    final pickedImage = await ImagePickerService.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 90,
    );

    if (pickedImage != null) {
      setState(() {
        _selectedImages.add(pickedImage);
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
        imageFiles: _selectedImages.isNotEmpty ? _selectedImages : null,
        linkUrl: _linkController.text.trim().isNotEmpty ? _linkController.text.trim() : null,
      );

      if (!mounted) return;

      if (result['success']) {
        _showMessage('🏆 Challenge posted successfully!', isError: false);

        _titleController.clear();
        _descriptionController.clear();
        _targetScoreController.clear();
        _linkController.clear(); // NEW
        setState(() {
          _selectedImages.clear(); // Changed
          _selectedExamId = null;
          _selectedSubject = null;
          _subjects.clear();
          _selectedDifficulty = 'medium';
          _selectedDuration = 7;
        });

        // Navigate to home tab after short delay
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const MainAppScreen(initialTabIndex: 0),
            ),
                (route) => false,
          );
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
                    _buildLinkSection(), // NEW
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
    return Column(
      children: [
        // Display selected images
        if (_selectedImages.isNotEmpty)
          Container(
            height: 400,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: PageView.builder(
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? FutureBuilder<List<int>?>(
                          future: ImagePickerService.getImageBytes(_selectedImages[index]),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.done &&
                                snapshot.hasData &&
                                snapshot.data != null) {
                              return Image.memory(
                                Uint8List.fromList(snapshot.data!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                              );
                            }
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          },
                        )
                            : Image.file(
                          _selectedImages[index] as File,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                    // Remove button
                    Positioned(
                      top: 12,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImages.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    // Image counter
                    if (_selectedImages.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${index + 1}/${_selectedImages.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    // Change button (only on first image)
                    if (index == 0)
                      Positioned(
                        bottom: 12,
                        right: 16,
                        child: GestureDetector(
                          onTap: _showImageSourceSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Add More',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
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

        const SizedBox(height: 12),

        // Add images button (when no images)
        if (_selectedImages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: _showImageSourceSheet,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Add Photo (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Share your study setup or materials (up to 5)',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Add more button (when has images but less than 5)
        if (_selectedImages.isNotEmpty && _selectedImages.length < 5)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: _showImageSourceSheet,
              child: Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Add More Images (${_selectedImages.length}/5)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLinkSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                'Add Link (Optional)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _linkController,
            decoration: InputDecoration(
              hintText: 'https://example.com',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.link, color: Colors.grey.shade600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF8A1FFF), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            keyboardType: TextInputType.url,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                final urlPattern = r'^https?://';
                if (!RegExp(urlPattern).hasMatch(value.trim())) {
                  return 'Please enter a valid URL starting with http:// or https://';
                }
              }
              return null;
            },
          ),
        ],
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