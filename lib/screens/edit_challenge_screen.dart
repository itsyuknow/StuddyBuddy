import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../services/challenge_service.dart';
import '../services/image_picker_service.dart';

class EditChallengeScreen extends StatefulWidget {
  final Map<String, dynamic> challenge;

  const EditChallengeScreen({super.key, required this.challenge});

  @override
  State<EditChallengeScreen> createState() => _EditChallengeScreenState();
}

class _EditChallengeScreenState extends State<EditChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetScoreController = TextEditingController();

  String? _selectedSubject;
  String _selectedDifficulty = 'medium';
  // ✅ NEW - Add these
  List<dynamic> _selectedImages = []; // For new images
  List<String> _existingImageUrls = []; // For existing images
  final _linkController = TextEditingController(); // For link URL
  bool _isSubmitting = false;

  List<String> _subjects = [];
  bool _isLoadingSubjects = true;

  final List<String> _difficulties = ['easy', 'medium', 'hard'];

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing data
    _titleController.text = widget.challenge['title'] ?? '';
    _descriptionController.text = widget.challenge['description'] ?? '';
    _selectedSubject = widget.challenge['subject'];
    _selectedDifficulty = widget.challenge['difficulty'] ?? 'medium';
    _linkController.text = widget.challenge['link_url'] ?? ''; // NEW

    // Load existing images
    if (widget.challenge['image_urls'] != null && widget.challenge['image_urls'] is List) {
      _existingImageUrls = List<String>.from(widget.challenge['image_urls']);
    }

    if (widget.challenge['target_score'] != null) {
      _targetScoreController.text = widget.challenge['target_score'].toString();
    }

    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final examId = widget.challenge['exam_id'];
      if (examId != null) {
        final subjects = await ChallengeService.getExamSubjects(examId);
        setState(() {
          _subjects = subjects;
          _isLoadingSubjects = false;
        });
      } else {
        setState(() => _isLoadingSubjects = false);
      }
    } catch (e) {
      print('Error loading subjects: $e');
      setState(() => _isLoadingSubjects = false);
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

  Future<void> _pickImage() async {
    if (_selectedImages.length + _existingImageUrls.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum 5 images allowed')),
      );
      return;
    }

    final image = await ImagePickerService.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImages.add(image);
      });
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  Future<void> _updateChallenge() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a subject'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    int? targetScore;
    if (_targetScoreController.text.isNotEmpty) {
      targetScore = int.tryParse(_targetScoreController.text);
    }

    final result = await ChallengeService.updateChallenge(
      challengeId: widget.challenge['id'],
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      subject: _selectedSubject!,
      difficulty: _selectedDifficulty,
      targetScore: targetScore,
      imageFiles: _selectedImages.isNotEmpty ? _selectedImages : null,
      existingImageUrls: _existingImageUrls,
      linkUrl: _linkController.text.trim().isNotEmpty ? _linkController.text.trim() : null,
      removeAllImages: _existingImageUrls.isEmpty && _selectedImages.isEmpty,
    );

    setState(() => _isSubmitting = false);

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Challenge updated successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(result['error'] ?? 'Failed to update challenge')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Challenge',
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_isSubmitting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _updateChallenge,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Challenge Title',
                    labelStyle: TextStyle(color: Colors.grey.shade600),
                    hintText: 'Enter challenge title',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.emoji_events, color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    if (value.trim().length < 5) {
                      return 'Title must be at least 5 characters';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),

              const SizedBox(height: 16),

              // Description Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: Colors.grey.shade600),
                    hintText: 'Describe your challenge...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.description, color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(20),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    if (value.trim().length < 20) {
                      return 'Description must be at least 20 characters';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),

              const SizedBox(height: 16),

              // Subject Dropdown
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isLoadingSubjects
                    ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text('Loading subjects...', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                )
                    : DropdownButtonFormField<String>(
                  value: _selectedSubject,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    labelStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: Icon(Icons.subject, color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  hint: Text('Select subject', style: TextStyle(color: Colors.grey.shade400)),
                  items: _subjects.map((subject) => DropdownMenuItem(
                    value: subject,
                    child: Text(subject),
                  )).toList(),
                  onChanged: (value) {
                    setState(() => _selectedSubject = value);
                  },
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),

              const SizedBox(height: 16),

              // Difficulty Dropdown
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedDifficulty,
                  decoration: InputDecoration(
                    labelText: 'Difficulty',
                    labelStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: Icon(Icons.speed, color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  items: _difficulties.map((difficulty) => DropdownMenuItem(
                    value: difficulty,
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: difficulty == 'easy' ? Colors.green :
                          difficulty == 'hard' ? Colors.red : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(difficulty.toUpperCase()),
                      ],
                    ),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedDifficulty = value);
                    }
                  },
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),

              const SizedBox(height: 16),

              // Target Score Field (Optional)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _targetScoreController,
                  decoration: InputDecoration(
                    labelText: 'Target Score (Optional)',
                    labelStyle: TextStyle(color: Colors.grey.shade600),
                    hintText: 'Enter target score',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.stars, color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final score = int.tryParse(value);
                      if (score == null || score <= 0) {
                        return 'Please enter a valid positive number';
                      }
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Link Section - NEW
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _linkController,
                  decoration: InputDecoration(
                    labelText: 'Link URL (Optional)',
                    labelStyle: TextStyle(color: Colors.grey.shade600),
                    hintText: 'https://example.com',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.link, color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(20),
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
              ),

              const SizedBox(height: 24),

              // Images Section
              Text(
                'Images (up to 5)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),

              // Display existing and new images
              if (_existingImageUrls.isNotEmpty || _selectedImages.isNotEmpty)
                SizedBox(
                  height: 250,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _existingImageUrls.length + _selectedImages.length,
                    itemBuilder: (context, index) {
                      final isExisting = index < _existingImageUrls.length;

                      return Container(
                        width: 200,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: isExisting
                                  ? Image.network(
                                _existingImageUrls[index],
                                width: 200,
                                height: 250,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 250,
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey.shade400),
                                ),
                              )
                                  : (_selectedImages[index - _existingImageUrls.length] is File
                                  ? Image.file(
                                _selectedImages[index - _existingImageUrls.length] as File,
                                width: 200,
                                height: 250,
                                fit: BoxFit.cover,
                              )
                                  : FutureBuilder<Uint8List>(
                                future: (_selectedImages[index - _existingImageUrls.length] as XFile).readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Image.memory(
                                      snapshot.data!,
                                      width: 200,
                                      height: 250,
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  return Container(
                                    width: 200,
                                    height: 250,
                                    color: Colors.grey.shade200,
                                    child: const Center(child: CircularProgressIndicator()),
                                  );
                                },
                              )),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () => isExisting
                                      ? _removeExistingImage(index)
                                      : _removeNewImage(index - _existingImageUrls.length),
                                ),
                              ),
                            ),
                            if (!isExisting)
                              Positioned(
                                bottom: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8A1FFF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'New',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 12),

              // Add image button
              if (_existingImageUrls.length + _selectedImages.length < 5)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, color: Colors.grey.shade600, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Add Image (${_existingImageUrls.length + _selectedImages.length}/5)',
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

              const SizedBox(height: 32),

              // Update Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8A1FFF).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _updateChallenge,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Update Challenge',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}