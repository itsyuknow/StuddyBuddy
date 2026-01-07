import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  final _institutionController = TextEditingController();
  final _majorController = TextEditingController();
  final _websiteController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _githubController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedDate;
  bool _isLoading = true;
  bool _isSaving = false;

  // Study profile data - only strengths and weaknesses
  List<String> _strengths = [];
  List<String> _weaknesses = [];
  List<String> _interests = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _institutionController.dispose();
    _majorController.dispose();
    _websiteController.dispose();
    _linkedinController.dispose();
    _githubController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId!)
          .single();

      setState(() {
        _fullNameController.text = response['full_name'] ?? '';
        _usernameController.text = response['username'] ?? '';
        _bioController.text = response['bio'] ?? '';
        _phoneController.text = response['phone'] ?? '';
        _institutionController.text = response['institution_name'] ?? '';
        _majorController.text = response['major_subject'] ?? '';
        _websiteController.text = response['website_url'] ?? '';
        _linkedinController.text = response['linkedin_url'] ?? '';
        _githubController.text = response['github_url'] ?? '';
        _cityController.text = response['city'] ?? '';
        _countryController.text = response['country'] ?? '';
        _selectedGender = response['gender'];

        if (response['date_of_birth'] != null) {
          _selectedDate = DateTime.parse(response['date_of_birth']);
        }

        _strengths = List<String>.from(response['strengths'] ?? []);
        _weaknesses = List<String>.from(response['weaknesses'] ?? []);
        _interests = List<String>.from(response['interests'] ?? []);

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final userId = _supabase.auth.currentUser?.id;

      await _supabase.from('users').update({
        'full_name': _fullNameController.text.trim(),
        'username': _usernameController.text.trim().isEmpty
            ? null
            : _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'phone': _phoneController.text.trim(),
        'institution_name': _institutionController.text.trim(),
        'major_subject': _majorController.text.trim(),
        'website_url': _websiteController.text.trim(),
        'linkedin_url': _linkedinController.text.trim(),
        'github_url': _githubController.text.trim(),
        'city': _cityController.text.trim(),
        'country': _countryController.text.trim(),
        'gender': _selectedGender,
        'date_of_birth': _selectedDate?.toIso8601String(),
        'strengths': _strengths,
        'weaknesses': _weaknesses,
        'interests': _interests,
      }).eq('id', userId!);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showTagEditor(String title, List<String> currentTags, Function(List<String>) onSave) {
    final controller = TextEditingController();
    List<String> tempTags = List.from(currentTags);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        onSave(tempTags);
                        Navigator.pop(context);
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'Add new tag',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        if (controller.text.trim().isNotEmpty) {
                          setModalState(() {
                            tempTags.add(controller.text.trim());
                            controller.clear();
                          });
                        }
                      },
                      icon: const Icon(Icons.add_circle),
                      color: Colors.blue,
                      iconSize: 32,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tempTags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        onDeleted: () {
                          setModalState(() => tempTags.remove(tag));
                        },
                        deleteIcon: const Icon(Icons.close, size: 18),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: Text(
              _isSaving ? 'Saving...' : 'Save',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _isSaving ? Colors.grey : Colors.blue,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Basic Information'),
              const SizedBox(height: 12),
              _buildTextField('Full Name', _fullNameController, required: true),
              const SizedBox(height: 12),
              _buildTextField('Username', _usernameController, prefix: '@'),
              const SizedBox(height: 12),
              _buildTextField(
                'Bio',
                _bioController,
                maxLines: 4,
                hint: 'Tell us about yourself...',
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Contact'),
              const SizedBox(height: 12),
              _buildTextField('Phone', _phoneController),
              const SizedBox(height: 24),

              _buildSectionTitle('Location'),
              const SizedBox(height: 12),
              _buildTextField('City', _cityController),
              const SizedBox(height: 12),
              _buildTextField('Country', _countryController),
              const SizedBox(height: 24),

              _buildSectionTitle('Education'),
              const SizedBox(height: 12),
              _buildTextField('Institution', _institutionController),
              const SizedBox(height: 12),
              _buildTextField('Major/Subject', _majorController),
              const SizedBox(height: 24),

              _buildSectionTitle('Study Profile'),
              const SizedBox(height: 12),
              _buildTagButton(
                'Strengths',
                _strengths,
                Icons.trending_up,
                Colors.green,
                    () => _showTagEditor('Strengths', _strengths, (tags) {
                  setState(() => _strengths = tags);
                }),
              ),
              const SizedBox(height: 12),
              _buildTagButton(
                'Weaknesses',
                _weaknesses,
                Icons.trending_down,
                Colors.red,
                    () => _showTagEditor('Weaknesses', _weaknesses, (tags) {
                  setState(() => _weaknesses = tags);
                }),
              ),
              const SizedBox(height: 12),
              _buildTagButton(
                'Interests',
                _interests,
                Icons.favorite,
                Colors.purple,
                    () => _showTagEditor('Interests', _interests, (tags) {
                  setState(() => _interests = tags);
                }),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Social Links'),
              const SizedBox(height: 12),
              _buildTextField('Website', _websiteController),
              const SizedBox(height: 12),
              _buildTextField('LinkedIn', _linkedinController),
              const SizedBox(height: 12),
              _buildTextField('GitHub', _githubController),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller, {
        bool required = false,
        int maxLines = 1,
        String? hint,
        String? prefix,
      }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: required
          ? (value) {
        if (value == null || value.trim().isEmpty) {
          return 'This field is required';
        }
        return null;
      }
          : null,
    );
  }

  Widget _buildTagButton(
      String label,
      List<String> tags,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tags.isEmpty ? 'Add $label' : '${tags.length} items',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}