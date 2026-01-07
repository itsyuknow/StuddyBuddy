import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/edit_study_profile_dialog.dart';
import '../services/user_session.dart';
import '../services/post_service.dart';
import '../screens/exam_selection_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/post_details_screen.dart';
import '../screens/followers_list_screen.dart';

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
  bool _isLoading = true;
  bool _isLoadingPosts = true;
  bool _isStudyProfileExpanded = false;
  bool _showingPosts = true; // true = posts, false = challenges
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserPosts();
    _loadFollowCounts();
  }

  Future<void> _loadFollowCounts() async {
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

      setState(() {
        _followersCount = followersResponse.length;
        _followingCount = followingResponse.length;
      });
    } catch (e) {
      print('Error loading follow counts: $e');
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      if (response != null) {
        setState(() {
          _userData = response;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserPosts() async {
    setState(() => _isLoadingPosts = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final allPosts = await PostService.getPosts();
      final userPosts = allPosts.where((post) => post['user_id'] == userId).toList();

      // Separate normal posts and challenges
      final normalPosts = userPosts.where((post) => post['challenge_type'] == null).toList();
      final challenges = userPosts.where((post) => post['challenge_type'] != null).toList();

      setState(() {
        _userPosts = normalPosts;
        _userChallenges = challenges;
        _isLoadingPosts = false;
      });
    } catch (e) {
      setState(() => _isLoadingPosts = false);
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
      final file = File(pickedFile.path);
      final fileName = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage.from('profiles').upload(
        fileName,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      final avatarUrl = _supabase.storage.from('profiles').getPublicUrl(fileName);

      await _supabase.from('users').update({
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId!);

      _loadUserData();

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
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.purple.shade400],
                  ),
                ),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text('Loading profile...', style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        color: Colors.black,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        _buildProfileHeader(),
                        _buildBio(),
                        _buildActionButtons(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildEducationInfo(),
                  const SizedBox(height: 8),
                  _buildStudyProfile(),
                  const SizedBox(height: 8),
                  _buildInterestsSection(),
                  const SizedBox(height: 8),
                  _buildPostsSection(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      pinned: true,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const Icon(Icons.lock_outline, size: 18, color: Colors.black),
          const SizedBox(width: 6),
          Text(
            _userData?['username'] ?? _userData?['full_name'] ?? 'Profile',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black),
          ),
          const Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 20),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_box_outlined, color: Colors.black, size: 28),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.menu, color: Colors.black, size: 28),
          onPressed: _showOptionsMenu,
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: _updateAvatar,
            child: Stack(
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Colors.purple.shade400, Colors.pink.shade400, Colors.orange.shade400],
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(2),
                    child: _buildAvatar(_userData?['avatar_url'], _userData?['full_name'] ?? 'U', 80),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0095F6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.add, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(_userPosts.length.toString(), 'Posts', null),
                _buildStatColumn(_followersCount.toString(), 'Followers', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FollowersListScreen(userId: _supabase.auth.currentUser!.id, initialTab: 0),
                    ),
                  ).then((_) => _loadFollowCounts());
                }),
                _buildStatColumn(_followingCount.toString(), 'Following', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FollowersListScreen(userId: _supabase.auth.currentUser!.id, initialTab: 1),
                    ),
                  ).then((_) => _loadFollowCounts());
                }),
              ],
            ),
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
        gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.purple.shade400]),
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
          style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildBio() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_userData?['full_name'] ?? 'User', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
          if (_userData?['bio'] != null && _userData!['bio'].isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_userData!['bio'], style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black)),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 32,
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
              child: ElevatedButton(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                  _loadUserData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Edit profile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 32,
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Share profile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationInfo() {
    if (_userData?['institution_name'] == null) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_outlined, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text('Education', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_userData!['institution_name'], style: const TextStyle(fontSize: 14, color: Colors.black)),
          if (_userData?['major_subject'] != null) ...[
            const SizedBox(height: 4),
            Text(_userData!['major_subject'], style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }

  Widget _buildStudyProfile() {
    final hasData = (_userData?['exam_id'] != null) ||
        (_userData?['strengths']?.isNotEmpty ?? false) ||
        (_userData?['weaknesses']?.isNotEmpty ?? false) ||
        (_userData?['skills']?.isNotEmpty ?? false) ||
        (_userData?['study_issues']?.isNotEmpty ?? false);

    if (!hasData) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isStudyProfileExpanded = !_isStudyProfileExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('Study Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black)),
                  const Spacer(),
                  Icon(_isStudyProfileExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.black),
                ],
              ),
            ),
          ),
          if (_isStudyProfileExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_userData?['exam_id'] != null)
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _getExamDetails(_userData!['exam_id']),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          final exam = snapshot.data!;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Preparing for', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(exam['short_name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                      const SizedBox(height: 4),
                                      Text(exam['full_name'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                    ],
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
                    _buildTagSection('Strengths', _userData!['strengths'], Colors.green.shade50, Colors.green.shade700),
                  if (_userData?['weaknesses']?.isNotEmpty ?? false)
                    _buildTagSection('Weaknesses', _userData!['weaknesses'], Colors.red.shade50, Colors.red.shade700),
                  if (_userData?['skills']?.isNotEmpty ?? false)
                    _buildTagSection('Skills', _userData!['skills'], Colors.blue.shade50, Colors.blue.shade700),
                  if (_userData?['study_issues']?.isNotEmpty ?? false)
                    _buildTagSection('Study Issues', _userData!['study_issues'], Colors.orange.shade50, Colors.orange.shade700),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showEditStudyProfileDialog,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Study Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Widget _buildTagSection(String title, List<dynamic> items, Color bgColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: textColor.withOpacity(0.2)),
                ),
                child: Text(item.toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsSection() {
    if (_userData?['interests'] == null || _userData!['interests'].isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Interests', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (_userData!['interests'] as List).map((interest) {
              return Chip(
                label: Text(interest.toString()),
                backgroundColor: Colors.grey.shade100,
                side: BorderSide.none,
                labelStyle: const TextStyle(fontSize: 13),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsSection() {
    final currentList = _showingPosts ? _userPosts : _userChallenges;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showingPosts = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: _showingPosts
                            ? Border(bottom: BorderSide(color: Colors.black, width: 1))
                            : null,
                      ),
                      child: Icon(
                        Icons.grid_on,
                        size: 24,
                        color: _showingPosts ? Colors.black : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showingPosts = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: !_showingPosts
                            ? Border(bottom: BorderSide(color: Colors.black, width: 1))
                            : null,
                      ),
                      child: Icon(
                        Icons.emoji_events,
                        size: 24,
                        color: !_showingPosts ? Colors.black : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _isLoadingPosts
              ? Container(height: 200, alignment: Alignment.center, child: const CircularProgressIndicator(color: Colors.black))
              : currentList.isEmpty
              ? Container(
            height: 300,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Icon(
                    _showingPosts ? Icons.camera_alt_outlined : Icons.emoji_events_outlined,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _showingPosts ? 'Share Photos' : 'No Challenges Yet',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w300, color: Colors.black),
                ),
                const SizedBox(height: 8),
                Text(
                  _showingPosts
                      ? 'When you share photos, they will appear on your profile.'
                      : 'When you create challenges, they will appear here.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          )
              : GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: currentList.length,
            itemBuilder: (context, index) => _buildPostGridItem(currentList[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildPostGridItem(Map<String, dynamic> post) {
    final isChallenge = post['challenge_type'] != null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailsScreen(postId: post['id'])),
        ).then((_) => _loadUserPosts());
      },
      child: Container(
        color: Colors.grey.shade200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (post['image_url'] != null)
              Image.network(
                post['image_url'],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image, size: 40, color: Colors.white),
                ),
              )
            else
              Container(
                color: Colors.grey.shade300,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isChallenge ? Icons.emoji_events : Icons.article_outlined,
                      size: 32,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.emoji_events, size: 16, color: Colors.white),
                ),
              ),
          ],
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
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings and privacy'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Your activity'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_border),
                title: const Text('Saved'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_2_outlined),
                title: const Text('QR code'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.pop(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Log out', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  final navigatorContext = Navigator.of(context, rootNavigator: true).context;
                  Navigator.pop(context);

                  final confirm = await showDialog<bool>(
                    context: navigatorContext,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Log out'),
                      content: const Text('Are you sure you want to log out?'),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Log out', style: TextStyle(color: Colors.red)),
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
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  );

                  try {
                    await UserSession.clearUser();
                    await Future.delayed(const Duration(milliseconds: 200));

                    Navigator.of(navigatorContext).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const ExamSelectionScreen(),
                      ),
                          (route) => false,
                    );
                  } catch (e) {
                    Navigator.of(navigatorContext).pop();
                    ScaffoldMessenger.of(navigatorContext).showSnackBar(
                      SnackBar(
                        content: Text('Error logging out: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}