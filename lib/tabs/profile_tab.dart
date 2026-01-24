import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/challenge_details_screen.dart';
import '../screens/edit_study_profile_dialog.dart';
import '../services/challenge_service.dart';
import '../services/user_session.dart';
import '../services/post_service.dart';
import '../screens/exam_selection_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/post_details_screen.dart';
import '../screens/followers_list_screen.dart';
import 'package:shimmer/shimmer.dart';
import '../services/share_service.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _userPosts = [];
  List<Map<String, dynamic>> _userChallenges = [];
  bool _isLoadingUser = true;
  bool _isLoadingPosts = true;
  bool _isLoadingCounts = true;
  bool _isStudyProfileExpanded = false;
  bool _showingPosts = true;
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    // Start all loads in parallel
    await Future.wait([
      _loadUserData(),
      _loadFollowCounts(),
    ]);
    // Load posts after basic profile is ready
    _loadUserPosts();
  }

  Future<void> _loadFollowCounts() async {
    setState(() => _isLoadingCounts = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final followersResponse = await _supabase
          .from('follows')
          .select()
          .eq('following_id', userId);

      final followingResponse = await _supabase
          .from('follows')
          .select()
          .eq('follower_id', userId);

      if (mounted) {
        setState(() {
          _followersCount = followersResponse.length;
          _followingCount = followingResponse.length;
          _isLoadingCounts = false;
        });
      }
    } catch (e) {
      print('Error loading follow counts: $e');
      if (mounted) setState(() => _isLoadingCounts = false);
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoadingUser = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      if (response != null) {
        if (mounted) {
          setState(() {
            _userData = response;
            _isLoadingUser = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingUser = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _loadUserPosts() async {
    setState(() => _isLoadingPosts = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Direct database queries instead of loading everything
      final postsResponse = await _supabase
          .from('posts')
          .select()
          .eq('user_id', userId)
          .isFilter('challenge_type', null)  // Changed from .is_() to .isFilter()
          .order('created_at', ascending: false);

      final challengesResponse = await _supabase
          .from('challenges')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _userPosts = List<Map<String, dynamic>>.from(postsResponse);
          _userChallenges = List<Map<String, dynamic>>.from(challengesResponse);
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      print('Error loading user posts and challenges: $e');
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _updateAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 90,
    );

    if (pickedFile == null) return;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF8A1FFF)),
        ),
      );

      // Read file as bytes
      final bytes = await pickedFile.readAsBytes();
      final fileName = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload to Supabase storage
      await _supabase.storage.from('profiles').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      final avatarUrl = _supabase.storage.from('profiles').getPublicUrl(fileName);

      await _supabase.from('users').update({
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      // Dismiss loading
      if (!mounted) return;
      Navigator.pop(context);

      await _loadUserData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Profile picture updated!'),
            ],
          ),
          backgroundColor: const Color(0xFF8A1FFF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      // Dismiss loading if it's showing
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print('Error updating avatar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: ${e.toString()}'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _refreshProfile() async {
    await Future.wait([
      _loadUserData(),
      _loadUserPosts(),
      _loadFollowCounts(),
    ]);
  }

  Future<void> _shareProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final userName = _userData?['full_name'] ?? 'User Profile';

      if (userId == null) return;

      final link = await ShareService.generateUserProfileLink(userId);
      final copied = await ShareService.copyLinkToClipboard(link);

      if (!mounted) return;

      if (copied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Profile link copied to clipboard!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error sharing profile: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy link: ${e.toString()}'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);



    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refreshProfile,
          color: Colors.white,
          backgroundColor: const Color(0xFF8A1FFF),
          child: CustomScrollView(
            slivers: [
              _buildModernAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildGlassProfileHeader(),
                    const SizedBox(height: 20),
                    _buildContentSections(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      expandedHeight: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF8A1FFF).withOpacity(0.95),
              const Color(0xFFC43AFF).withOpacity(0.95),
            ],
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  _userData?['username'] ?? _userData?['full_name'] ?? 'Profile',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Icon(Icons.menu_rounded, color: Colors.white, size: 20),
          ),
          onPressed: _showOptionsMenu,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildGlassProfileHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar and stats in a column for small screens
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 400;

              if (isSmallScreen) {
                return Column(
                  children: [
                    GestureDetector(
                      onTap: _updateAvatar,
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.4),
                                  Colors.white.withOpacity(0.2),
                                ],
                              ),
                              border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(3),
                            child: _buildAvatar(_userData?['avatar_url'], _userData?['full_name'] ?? 'U', 94),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFFFFF), Color(0xFFF0F0F0)],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF8A1FFF)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Stats row
                    Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                    // Posts stat with shimmer loading
                    _isLoadingPosts
                    ? Shimmer.fromColors(
                    baseColor: Colors.white.withOpacity(0.3),
                    highlightColor: Colors.white.withOpacity(0.5),
                    child: _buildSkeletonStat(),
                    )
                        : _buildGlassStatColumn(_userPosts.length.toString(), 'Posts', null),

                    // Followers stat with shimmer loading
                    _isLoadingCounts
                    ? Shimmer.fromColors(
                    baseColor: Colors.white.withOpacity(0.3),
                    highlightColor: Colors.white.withOpacity(0.5),
              child: _buildSkeletonStat(),
              )
                  : _buildGlassStatColumn(_followersCount.toString(), 'Followers', () {
              Navigator.push(
              context,
              MaterialPageRoute(
              builder: (_) => FollowersListScreen(userId: _supabase.auth.currentUser!.id, initialTab: 0),
              ),
              ).then((_) => _loadFollowCounts());
              }),

              // Following stat with shimmer loading
              _isLoadingCounts
              ? Shimmer.fromColors(
              baseColor: Colors.white.withOpacity(0.3),
              highlightColor: Colors.white.withOpacity(0.5),
              child: _buildSkeletonStat(),
              )
                  : _buildGlassStatColumn(_followingCount.toString(), 'Following', () {
              Navigator.push(
              context,
              MaterialPageRoute(
              builder: (_) => FollowersListScreen(userId: _supabase.auth.currentUser!.id, initialTab: 1),
              ),
              ).then((_) => _loadFollowCounts());
              },
    ),
    ],
    )])
              ;
    } else {
                // Original row layout for larger screens
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _updateAvatar,
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.4),
                                  Colors.white.withOpacity(0.2),
                                ],
                              ),
                              border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(3),
                            child: _buildAvatar(_userData?['avatar_url'], _userData?['full_name'] ?? 'U', 94),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFFFFF), Color(0xFFF0F0F0)],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF8A1FFF)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: _buildGlassStatColumn(_userPosts.length.toString(), 'Posts', null),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: _buildGlassStatColumn(_followersCount.toString(), 'Followers', () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FollowersListScreen(userId: _supabase.auth.currentUser!.id, initialTab: 0),
                                ),
                              ).then((_) => _loadFollowCounts());
                            }),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: _buildGlassStatColumn(_followingCount.toString(), 'Following', () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FollowersListScreen(userId: _supabase.auth.currentUser!.id, initialTab: 1),
                                ),
                              ).then((_) => _loadFollowCounts());
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),

          // User info
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userData?['full_name'] ?? 'User',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                if (_userData?['bio'] != null && _userData!['bio'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _userData!['bio'],
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Buttons
          // Buttons
          _buildGlassButton(
            'Edit Profile',
            Icons.edit_rounded,
                () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
              _loadUserData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String userName, double size) {
    if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl != 'null') {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildAvatarFallback(userName, size),
        ),
      );
    }
    return _buildAvatarFallback(userName, size);
  }

  Widget _buildAvatarFallback(String userName, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.7),
          ],
        ),
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF8A1FFF),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassStatColumn(String value, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Reduced padding
        constraints: const BoxConstraints(
          minWidth: 60, // Minimum width
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18, // Slightly smaller
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11, // Slightly smaller
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassButton(String text, IconData icon, VoidCallback onPressed) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentSections() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          _buildEducationCard(),
          _buildStudyProfileCard(),
          _buildInterestsCard(),
          _buildPostsSection(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildEducationCard() {
    if (_userData?['institution_name'] == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8A1FFF).withOpacity(0.1),
            const Color(0xFFC43AFF).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF8A1FFF).withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text(
                'Education',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8A1FFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _userData!['institution_name'],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (_userData?['major_subject'] != null) ...[
            const SizedBox(height: 6),
            Text(
              _userData!['major_subject'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudyProfileCard() {
    final hasData = (_userData?['exam_id'] != null) ||
        (_userData?['strengths']?.isNotEmpty ?? false) ||
        (_userData?['weaknesses']?.isNotEmpty ?? false) ||
        (_userData?['skills']?.isNotEmpty ?? false) ||
        (_userData?['study_issues']?.isNotEmpty ?? false);

    if (!hasData) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8A1FFF).withOpacity(0.1),
            const Color(0xFFC43AFF).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF8A1FFF).withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isStudyProfileExpanded = !_isStudyProfileExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_graph_rounded, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Study Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8A1FFF),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isStudyProfileExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF8A1FFF),
                  ),
                ],
              ),
            ),
          ),
          if (_isStudyProfileExpanded) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFF8A1FFF).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_userData?['exam_id'] != null)
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _getExamDetails(_userData!['exam_id']),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          final exam = snapshot.data!;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8A1FFF).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Preparing for',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  exam['short_name'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  exam['full_name'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  if (_userData?['strengths']?.isNotEmpty ?? false)
                    _buildModernTagSection('Strengths', _userData!['strengths'], const Color(0xFF10B981), Icons.trending_up_rounded),
                  if (_userData?['weaknesses']?.isNotEmpty ?? false)
                    _buildModernTagSection('Weaknesses', _userData!['weaknesses'], const Color(0xFFEF4444), Icons.trending_down_rounded),
                  if (_userData?['skills']?.isNotEmpty ?? false)
                    _buildModernTagSection('Skills', _userData!['skills'], const Color(0xFF3B82F6), Icons.lightbulb_rounded),
                  if (_userData?['study_issues']?.isNotEmpty ?? false)
                    _buildModernTagSection('Study Issues', _userData!['study_issues'], const Color(0xFFF59E0B), Icons.error_outline_rounded),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showEditStudyProfileDialog,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit Study Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8A1FFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _getExamDetails(String examId) async {
    try {
      return await _supabase.from('exams').select().eq('id', examId).maybeSingle();
    } catch (e) {
      return null;
    }
  }

  Widget _buildModernTagSection(String title, List<dynamic> items, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                ),
                child: Text(
                  item.toString(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsCard() {
    if (_userData?['interests'] == null || _userData!['interests'].isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8A1FFF).withOpacity(0.1),
            const Color(0xFFC43AFF).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF8A1FFF).withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text(
                'Interests',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8A1FFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: (_userData!['interests'] as List).map((interest) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF8A1FFF).withOpacity(0.15),
                      const Color(0xFFC43AFF).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF8A1FFF).withOpacity(0.3), width: 1.5),
                ),
                child: Text(
                  interest.toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8A1FFF),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonStat() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(minWidth: 60),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 50,
            height: 11,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsSection() {
    final currentList = _showingPosts ? _userPosts : _userChallenges;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showingPosts = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: _showingPosts
                            ? const LinearGradient(
                          colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                        )
                            : null,
                        color: _showingPosts ? null : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _showingPosts
                              ? Colors.transparent
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.grid_on_rounded,
                            size: 20,
                            color: _showingPosts ? Colors.white : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Posts',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _showingPosts ? Colors.white : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showingPosts = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: !_showingPosts
                            ? const LinearGradient(
                          colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                        )
                            : null,
                        color: !_showingPosts ? null : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: !_showingPosts
                              ? Colors.transparent
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.emoji_events_rounded,
                            size: 20,
                            color: !_showingPosts ? Colors.white : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Challenges',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: !_showingPosts ? Colors.white : Colors.grey.shade600,
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
          _isLoadingPosts
              ? Container(
            height: 200,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: Color(0xFF8A1FFF)),
          )
              : currentList.isEmpty
              ? Container(
            height: 300,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF8A1FFF).withOpacity(0.2),
                        const Color(0xFFC43AFF).withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF8A1FFF).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _showingPosts ? Icons.photo_camera_rounded : Icons.emoji_events_rounded,
                    size: 45,
                    color: const Color(0xFF8A1FFF),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _showingPosts ? 'No Posts Yet' : 'No Challenges Yet',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8A1FFF),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _showingPosts
                        ? 'Share your study journey and connect with others'
                        : 'Create challenges to motivate yourself and others',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          )
              : GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: currentList.length,
            itemBuilder: (context, index) => _buildModernPostGridItem(currentList[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildModernPostGridItem(Map<String, dynamic> post) {
    final isChallenge = _showingPosts ? false : true; // If showing challenges tab, it's a challenge

    return GestureDetector(
      onTap: () {
        if (isChallenge) {
          // Navigate to ChallengeDetailsScreen for challenges
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChallengeDetailsScreen(challengeId: post['id']),
            ),
          ).then((_) => _loadUserPosts());
        } else {
          // Navigate to PostDetailsScreen for normal posts
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailsScreen(postId: post['id']),
            ),
          ).then((_) => _loadUserPosts());
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (post['image_url'] != null)
                Image.network(
                  post['image_url'],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF8A1FFF).withOpacity(0.3),
                          const Color(0xFFC43AFF).withOpacity(0.2),
                        ],
                      ),
                    ),
                    child: const Icon(Icons.broken_image_rounded, size: 35, color: Colors.white),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF8A1FFF).withOpacity(0.8),
                        const Color(0xFFC43AFF).withOpacity(0.6),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isChallenge ? Icons.emoji_events_rounded : Icons.article_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        post['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              if (isChallenge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.emoji_events_rounded, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditStudyProfileDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditStudyProfileDialog(userData: _userData!),
    );
    if (result == true) _loadUserData();
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              _buildMenuOption(
                Icons.share_rounded,
                'Share Profile',
                    () {
                  Navigator.pop(context);
                  _shareProfile();
                },
              ),
              const SizedBox(width: 16),
              _buildMenuOption(
                Icons.logout_rounded,
                'Log out',
                    () async {
                  final navigatorContext = Navigator.of(context, rootNavigator: true).context;
                  Navigator.pop(context);

                  final confirm = await showDialog<bool>(
                    context: navigatorContext,
                    builder: (dialogContext) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      title: const Text('Log out', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: const Text('Are you sure you want to log out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Log out', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm != true) return;

                  showDialog(
                    context: navigatorContext,
                    barrierDismissible: false,
                    builder: (context) => WillPopScope(
                      onWillPop: () async => false,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                          ),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        ),
                      ),
                    ),
                  );

                  try {
                    await UserSession.clearUser();
                    await Future.delayed(const Duration(milliseconds: 200));

                    Navigator.of(navigatorContext).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const ExamSelectionScreen()),
                          (route) => false,
                    );
                  } catch (e) {
                    Navigator.of(navigatorContext).pop();
                    ScaffoldMessenger.of(navigatorContext).showSnackBar(
                      SnackBar(
                        content: Text('Error logging out: $e'),
                        backgroundColor: Colors.red.shade400,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                },
                isDestructive: true,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: isDestructive
              ? LinearGradient(
            colors: [
              Colors.red.shade400.withOpacity(0.2),
              Colors.red.shade300.withOpacity(0.1),
            ],
          )
              : LinearGradient(
            colors: [
              const Color(0xFF8A1FFF).withOpacity(0.15),
              const Color(0xFFC43AFF).withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red.shade600 : const Color(0xFF8A1FFF),
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red.shade600 : Colors.black87,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 22,
        color: Colors.grey.shade400,
      ),
      onTap: onTap,
    );
  }
}