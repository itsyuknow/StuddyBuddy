import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/post_service.dart';
import '../services/chat_service.dart';
import '../screens/post_details_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/followers_list_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _userPosts = [];
  bool _isLoading = true;
  bool _isLoadingPosts = true;
  bool _isFollowing = false;
  bool _isCheckingFollow = true;
  bool _isStudyProfileExpanded = false;
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkFollowStatus();
    _loadUserPosts();
    _loadFollowCounts();
  }

  Future<void> _loadFollowCounts() async {
    try {
      final followersResponse = await _supabase
          .from('follows')
          .select()
          .eq('following_id', widget.userId);

      final followingResponse = await _supabase
          .from('follows')
          .select()
          .eq('follower_id', widget.userId);

      setState(() {
        _followersCount = followersResponse.length;
        _followingCount = followingResponse.length;
      });
    } catch (e) {
      print('Error loading follow counts: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', widget.userId)
          .single();

      setState(() {
        _userData = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserPosts() async {
    setState(() => _isLoadingPosts = true);
    try {
      final allPosts = await PostService.getPosts();
      final userPosts = allPosts.where((post) => post['user_id'] == widget.userId).toList();

      setState(() {
        _userPosts = userPosts;
        _isLoadingPosts = false;
      });
    } catch (e) {
      setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _checkFollowStatus() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      final response = await _supabase
          .from('follows')
          .select()
          .eq('follower_id', currentUserId!)
          .eq('following_id', widget.userId);

      setState(() {
        _isFollowing = response.isNotEmpty;
        _isCheckingFollow = false;
      });
    } catch (e) {
      setState(() => _isCheckingFollow = false);
    }
  }

  Future<void> _toggleFollow() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      if (_isFollowing) {
        await _supabase
            .from('follows')
            .delete()
            .eq('follower_id', currentUserId!)
            .eq('following_id', widget.userId);
      } else {
        await _supabase.from('follows').insert({
          'follower_id': currentUserId,
          'following_id': widget.userId,
        });
      }

      setState(() => _isFollowing = !_isFollowing);
      _loadFollowCounts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _openChat() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Opening chat...'),
            ],
          ),
          duration: Duration(seconds: 1),
        ),
      );

      final conversationId = await ChatService.getOrCreateConversation(widget.userId);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: conversationId, otherUser: _userData!),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening chat: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_userData == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text('User not found')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
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
                      _buildActionButtons(),
                      _buildBio(),
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
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          const Icon(Icons.lock_outline, size: 18, color: Colors.black),
          const SizedBox(width: 6),
          Text(
            _userData?['username'] ?? _userData?['full_name'] ?? 'Profile',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.black),
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
                      builder: (_) => FollowersListScreen(userId: widget.userId, initialTab: 0),
                    ),
                  ).then((_) => _loadFollowCounts());
                }),
                _buildStatColumn(_followingCount.toString(), 'Following', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FollowersListScreen(userId: widget.userId, initialTab: 1),
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

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: _isFollowing ? Colors.grey.shade200 : Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ElevatedButton(
                onPressed: _isCheckingFollow ? null : _toggleFollow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing ? Colors.grey.shade200 : Colors.black,
                  foregroundColor: _isFollowing ? Colors.black : Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  _isCheckingFollow ? 'Loading...' : (_isFollowing ? 'Following' : 'Follow'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Container(
              height: 32,
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
              child: ElevatedButton(
                onPressed: _openChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Message', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {},
              icon: const Icon(Icons.person_add_outlined, size: 18),
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBio() {
    if (_userData?['bio'] == null || _userData!['bio'].isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_userData?['full_name'] ?? 'User', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
          const SizedBox(height: 4),
          Text(_userData!['bio'], style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black)),
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black, width: 1))),
                    child: const Icon(Icons.grid_on, size: 24, color: Colors.black),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Icon(Icons.person_pin_outlined, size: 24, color: Colors.grey.shade400),
                  ),
                ),
              ],
            ),
          ),
          _isLoadingPosts
              ? Container(height: 200, alignment: Alignment.center, child: const CircularProgressIndicator(color: Colors.black))
              : _userPosts.isEmpty
              ? Container(
            height: 300,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2)),
                  child: const Icon(Icons.camera_alt_outlined, size: 40),
                ),
                const SizedBox(height: 16),
                const Text('No Posts Yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300, color: Colors.black)),
                const SizedBox(height: 8),
                const Text('When they share photos, they will appear here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.black54)),
              ],
            ),
          )
              : GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
            itemCount: _userPosts.length,
            itemBuilder: (context, index) => _buildPostGridItem(_userPosts[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildPostGridItem(Map<String, dynamic> post) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailsScreen(postId: post['id']))).then((_) => _loadUserPosts());
      },
      child: Container(
        color: Colors.grey.shade200,
        child: post['image_url'] != null
            ? Image.network(
          post['image_url'],
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade300,
            child: const Icon(Icons.broken_image, size: 40, color: Colors.white),
          ),
        )
            : Container(
          color: Colors.grey.shade300,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.article_outlined, size: 32, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                post['title'] ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
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
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share Profile'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: const Text('Block User'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.report_outlined, color: Colors.red),
                title: const Text('Report User', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}