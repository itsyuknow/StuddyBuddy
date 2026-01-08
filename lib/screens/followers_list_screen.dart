import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/user_profile_screen.dart';

class FollowersListScreen extends StatefulWidget {
  final String userId;
  final int initialTab; // 0 for followers, 1 for following

  const FollowersListScreen({
    super.key,
    required this.userId,
    this.initialTab = 0,
  });

  @override
  State<FollowersListScreen> createState() => _FollowersListScreenState();
}

class _FollowersListScreenState extends State<FollowersListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  bool _isLoadingFollowers = true;
  bool _isLoadingFollowing = true;

  final Map<String, bool> _followStatus = {};
  final Map<String, bool> _processingFollow = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadFollowers();
    _loadFollowing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowers() async {
    setState(() => _isLoadingFollowers = true);
    try {
      final response = await _supabase
          .from('follows')
          .select('follower_id, users!follows_follower_id_fkey(*)')
          .eq('following_id', widget.userId);

      final followers = (response as List).map((item) {
        return item['users'] as Map<String, dynamic>;
      }).toList();

      await _checkFollowStatuses(followers);

      setState(() {
        _followers = followers;
        _isLoadingFollowers = false;
      });
    } catch (e) {
      print('Error loading followers: $e');
      setState(() => _isLoadingFollowers = false);
    }
  }

  Future<void> _loadFollowing() async {
    setState(() => _isLoadingFollowing = true);
    try {
      final response = await _supabase
          .from('follows')
          .select('following_id, users!follows_following_id_fkey(*)')
          .eq('follower_id', widget.userId);

      final following = (response as List).map((item) {
        return item['users'] as Map<String, dynamic>;
      }).toList();

      await _checkFollowStatuses(following);

      setState(() {
        _following = following;
        _isLoadingFollowing = false;
      });
    } catch (e) {
      print('Error loading following: $e');
      setState(() => _isLoadingFollowing = false);
    }
  }

  Future<void> _checkFollowStatuses(List<Map<String, dynamic>> users) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    for (final user in users) {
      final userId = user['id'];
      if (userId == currentUserId) continue;

      try {
        final response = await _supabase
            .from('follows')
            .select()
            .eq('follower_id', currentUserId)
            .eq('following_id', userId);

        _followStatus[userId] = response.isNotEmpty;
      } catch (e) {
        print('Error checking follow status for $userId: $e');
      }
    }
  }

  Future<void> _toggleFollow(String targetUserId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    setState(() => _processingFollow[targetUserId] = true);

    try {
      final isFollowing = _followStatus[targetUserId] ?? false;

      if (isFollowing) {
        await _supabase
            .from('follows')
            .delete()
            .eq('follower_id', currentUserId)
            .eq('following_id', targetUserId);
      } else {
        await _supabase.from('follows').insert({
          'follower_id': currentUserId,
          'following_id': targetUserId,
        });
      }

      setState(() {
        _followStatus[targetUserId] = !isFollowing;
        _processingFollow[targetUserId] = false;
      });
    } catch (e) {
      setState(() => _processingFollow[targetUserId] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _supabase.auth.currentUser?.id;
    final isOwnProfile = widget.userId == currentUserId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8A1FFF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Connections',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF8A1FFF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF8A1FFF),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFollowersList(isOwnProfile),
          _buildFollowingList(isOwnProfile),
        ],
      ),
    );
  }

  Widget _buildFollowersList(bool isOwnProfile) {
    if (_isLoadingFollowers) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8A1FFF)));
    }

    if (_followers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              isOwnProfile ? 'No followers yet' : 'No followers',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              isOwnProfile
                  ? 'When people follow you, they\'ll appear here'
                  : 'This user has no followers yet',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _followers.length,
      itemBuilder: (context, index) {
        final user = _followers[index];
        return _buildUserTile(user, isOwnProfile);
      },
    );
  }

  Widget _buildFollowingList(bool isOwnProfile) {
    if (_isLoadingFollowing) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8A1FFF)));
    }

    if (_following.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              isOwnProfile ? 'Not following anyone yet' : 'Not following anyone',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              isOwnProfile
                  ? 'Find people to follow'
                  : 'This user is not following anyone yet',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _following.length,
      itemBuilder: (context, index) {
        final user = _following[index];
        return _buildUserTile(user, isOwnProfile);
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, bool isOwnProfile) {
    final currentUserId = _supabase.auth.currentUser?.id;
    final userId = user['id'];
    final isCurrentUser = userId == currentUserId;

    final isFollowing = _followStatus[userId] ?? false;
    final isProcessing = _processingFollow[userId] ?? false;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(userId: userId),
            ),
          ).then((_) {
            _loadFollowers();
            _loadFollowing();
          });
        },
        child: _buildAvatar(user['avatar_url'], user['full_name'] ?? 'U'),
      ),
      title: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(userId: userId),
            ),
          ).then((_) {
            _loadFollowers();
            _loadFollowing();
          });
        },
        child: Text(
          user['username'] ?? user['full_name'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      subtitle: user['full_name'] != null
          ? GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(userId: userId),
            ),
          ).then((_) {
            _loadFollowers();
            _loadFollowing();
          });
        },
        child: Text(
          user['full_name'],
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      )
          : null,
      trailing: isCurrentUser
          ? null
          : SizedBox(
        width: 100,
        height: 32,
        child: Container(
          decoration: BoxDecoration(
            gradient: isFollowing
                ? null
                : const LinearGradient(
              colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
            ),
            color: isFollowing ? Colors.grey.shade200 : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ElevatedButton(
            onPressed: isProcessing ? null : () => _toggleFollow(userId),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: isFollowing ? Colors.black : Colors.white,
              shadowColor: Colors.transparent,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isProcessing
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isFollowing ? Colors.black : Colors.white,
              ),
            )
                : Text(
              isFollowing ? 'Following' : 'Follow',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String userName) {
    if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl != 'null') {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
        child: avatarUrl.isEmpty
            ? Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        )
            : null,
      );
    }

    return CircleAvatar(
      radius: 24,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}