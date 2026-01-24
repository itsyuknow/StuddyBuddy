import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/post_service.dart';
import '../services/challenge_service.dart';
import '../services/user_session.dart';
import '../screens/post_details_screen.dart';
import '../screens/challenge_details_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/share_service.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _challenges = [];
  Map<String, bool> _likedPosts = {};
  Map<String, bool> _likedChallenges = {};
  Map<String, bool> _joinedChallenges = {};
  bool _isLoadingPosts = true;
  bool _isLoadingChallenges = true;
  bool _isLoadingUserData = true;
  bool _isAuthenticated = false;
  String? _userExamId;
  final _supabase = Supabase.instance.client;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAuthAndLoadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndLoadData() async {
    final isLoggedIn = await UserSession.checkLogin();
    final currentUser = _supabase.auth.currentUser;

    setState(() {
      _isAuthenticated = isLoggedIn && currentUser != null;
    });

    if (_isAuthenticated) {
      // Load user exam first, THEN load posts and challenges in parallel
      await _loadUserExam();

      // Load posts and challenges simultaneously
      await Future.wait([
        _loadPosts(),
        _loadChallenges(),
      ]);
    } else {
      setState(() {
        _isLoadingPosts = false;
        _isLoadingChallenges = false;
      });
    }
  }

  Future<void> _loadUserExam() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('user_profiles')
          .select('exam_id')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        print('User exam ID: ${response['exam_id']}'); // Add debug print
        setState(() {
          _userExamId = response['exam_id'];
        });
      } else {
        print('No user profile found'); // Debug print
        setState(() {
          _userExamId = null;
        });
      }
    } catch (e) {
      print('Error loading user exam: $e');
      setState(() {
        _userExamId = null;
      });
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoadingPosts = true);

    try {
      print('🔍 Starting _loadPosts...');
      print('🔍 User Exam ID: $_userExamId');

      if (_userExamId == null) {
        print('⚠️ No exam ID found for user');
        if (mounted) {
          setState(() {
            _posts = [];
            _isLoadingPosts = false;
          });
        }
        return;
      }

      // Get all user profiles with the same exam in ONE query
      print('🔍 Fetching user profiles with exam_id: $_userExamId');
      final userProfilesResponse = await _supabase
          .from('users')
          .select('id')
          .eq('exam_id', _userExamId!);

      print('🔍 Found ${userProfilesResponse.length} user profiles');

      final userIds = userProfilesResponse.map((p) => p['id'] as String).toList();
      print('🔍 User IDs: $userIds');

      if (userIds.isEmpty) {
        print('⚠️ No users found with this exam');
        if (mounted) {
          setState(() {
            _posts = [];
            _isLoadingPosts = false;
          });
        }
        return;
      }

      // Get posts from those users in ONE query - REMOVED avatar_url
      print('🔍 Fetching posts from ${userIds.length} users...');
      final postsResponse = await _supabase
          .from('posts')
          .select('''
  id, title, description, image_urls, link_url, created_at, likes_count, comments_count,
  user_id, user_name
''')  // REMOVED avatar_url from here
          .inFilter('user_id', userIds)
          .isFilter('challenge_type', null)
          .order('created_at', ascending: false)
          .limit(50);

      print('🔍 Found ${postsResponse.length} posts');

      // Get avatars from users table
      // Get avatars from users table
      final posts = List<Map<String, dynamic>>.from(postsResponse);

// Fetch all user avatars in one query
      final uniqueUserIds = posts.map((p) => p['user_id']).toSet().toList();
      if (uniqueUserIds.isNotEmpty) {
        final usersResponse = await _supabase
            .from('users')
            .select('id, avatar_url')
            .inFilter('id', uniqueUserIds);

        // Create a map with proper null handling
        final userAvatars = <String, String?>{};
        for (var user in usersResponse) {
          userAvatars[user['id']] = user['avatar_url'];
        }

        // Add avatar_url to each post
        for (var post in posts) {
          final avatarUrl = userAvatars[post['user_id']];
          post['avatar_url'] = (avatarUrl == null || avatarUrl.isEmpty) ? 'null' : avatarUrl;
        }
      }

      // Load liked status in parallel
      final likedPosts = <String, bool>{};
      await Future.wait(
        posts.map((post) async {
          likedPosts[post['id']] = await PostService.hasUserLiked(post['id']);
        }),
      );

      print('✅ Successfully loaded ${posts.length} posts');

      if (mounted) {
        setState(() {
          _posts = posts;
          _likedPosts = likedPosts;
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      print('❌ Error loading posts: $e');
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoadingChallenges = true);

    try {
      // Direct query with exam filter - REMOVED avatar_url
      final challengesResponse = await _supabase
          .from('challenges')
          .select('''
      id, title, description, image_urls, link_url, created_at, likes_count, 
      comments_count, participants_count, user_id, user_name,
      difficulty, duration_days, subject, exam_id
    ''')  // REMOVED avatar_url from here
          .eq('exam_id', _userExamId ?? '')
          .order('created_at', ascending: false)
          .limit(50);

      final challenges = List<Map<String, dynamic>>.from(challengesResponse);

// Get avatars from users table
      final uniqueUserIds = challenges.map((c) => c['user_id']).toSet().toList();

      if (uniqueUserIds.isNotEmpty) {
        final usersResponse = await _supabase
            .from('users')
            .select('id, avatar_url')
            .inFilter('id', uniqueUserIds);

        // Create a map with proper null handling
        final userAvatars = <String, String?>{};
        for (var user in usersResponse) {
          userAvatars[user['id']] = user['avatar_url'];
        }

        // Add avatar_url to each challenge
        for (var challenge in challenges) {
          final avatarUrl = userAvatars[challenge['user_id']];
          challenge['avatar_url'] = (avatarUrl == null || avatarUrl.isEmpty) ? 'null' : avatarUrl;
        }
      }

      // Load liked and joined status in parallel
      final likedChallenges = <String, bool>{};
      final joinedChallenges = <String, bool>{};

      await Future.wait(
        challenges.map((challenge) async {
          final results = await Future.wait([
            ChallengeService.hasUserLiked(challenge['id']),
            ChallengeService.hasUserJoinedChallenge(challenge['id']),
          ]);
          likedChallenges[challenge['id']] = results[0];
          joinedChallenges[challenge['id']] = results[1];
        }),
      );

      if (mounted) {
        setState(() {
          _challenges = challenges;
          _likedChallenges = likedChallenges;
          _joinedChallenges = joinedChallenges;
          _isLoadingChallenges = false;
        });
      }
    } catch (e) {
      print('Error loading challenges: $e');
      if (mounted) setState(() => _isLoadingChallenges = false);
    }
  }

  Future<void> _refreshPosts() async {
    await _loadPosts();
  }

  Future<void> _refreshChallenges() async {
    await _loadChallenges();
  }

  Future<void> _togglePostLike(String postId) async {
    if (!_isAuthenticated) return;

    final post = _posts.firstWhere((p) => p['id'] == postId);
    final wasLiked = _likedPosts[postId] ?? false;
    final currentLikes = post['likes_count'] as int;

    setState(() {
      _likedPosts[postId] = !wasLiked;
      post['likes_count'] = currentLikes + (wasLiked ? -1 : 1);
    });

    final success = await PostService.toggleLike(postId);

    if (!success) {
      setState(() {
        _likedPosts[postId] = wasLiked;
        post['likes_count'] = currentLikes;
      });
    }
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open link'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid link'),
            backgroundColor: Colors.red,
          ),
        );

  }
  }
  }

  Future<void> _sharePost(String postId, String title) async {
    try {
      final link = await ShareService.generatePostLink(postId);
      final copied = await ShareService.copyLinkToClipboard(link);

      if (copied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Link copied to clipboard!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error sharing post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to copy link'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareChallenge(String challengeId, String title) async {
    try {
      final link = await ShareService.generateChallengeLink(challengeId);
      final copied = await ShareService.copyLinkToClipboard(link);

      if (copied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Link copied to clipboard!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error sharing challenge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to copy link'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleChallengeLike(String challengeId) async {
    if (!_isAuthenticated) return;

    final challenge = _challenges.firstWhere((c) => c['id'] == challengeId);
    final wasLiked = _likedChallenges[challengeId] ?? false;
    final currentLikes = challenge['likes_count'] as int;

    setState(() {
      _likedChallenges[challengeId] = !wasLiked;
      challenge['likes_count'] = currentLikes + (wasLiked ? -1 : 1);
    });

    // Use ChallengeService for challenges table
    final success = await ChallengeService.toggleLike(challengeId);

    if (!success) {
      setState(() {
        _likedChallenges[challengeId] = wasLiked;
        challenge['likes_count'] = currentLikes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent, // 👈 THIS removes the black line

        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        centerTitle: false,
        titleSpacing: 16,
        title: const Text(
          'Edormy',
          style: TextStyle(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        bottom: _isAuthenticated ? PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent, // 👈 removes the black line

              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: const Color(0xFF8A1FFF),
              unselectedLabelColor: Colors.white.withOpacity(0.8),
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Posts'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Challenges'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ) : null,
      ),
      body: _isAuthenticated
          ? TabBarView(
        controller: _tabController,
        children: [
          _buildPostsFeed(),
          _buildChallengesFeed(),
        ],
      )
          : _buildLoginPrompt(),
    );
  }

  Widget _buildPostsFeed() {
    if (_isLoadingPosts) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: 3, // Show 3 skeleton cards
        itemBuilder: (context, index) => Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: _buildPostSkeleton(),
        ),
      );
    }

    if (_posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshPosts,
        color: const Color(0xFF8A1FFF),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 300,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.post_add_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No posts yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pull down to refresh',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshPosts,
      color: const Color(0xFF8A1FFF),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return _buildPostCard(post);
        },
      ),
    );
  }

  Widget _buildChallengesFeed() {
    if (_isLoadingChallenges) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF8A1FFF), const Color(0xFFC43AFF)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading challenges...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_challenges.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshChallenges,
        color: const Color(0xFF8A1FFF),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 300,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No challenges yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pull down to refresh',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshChallenges,
      color: const Color(0xFF8A1FFF),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: _challenges.length,
        itemBuilder: (context, index) {
          final challenge = _challenges[index];
          return _buildChallengeCard(challenge);
        },
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final avatarUrl = post['avatar_url'];
    final createdAt = DateTime.parse(post['created_at']);
    final timeAgo = _getTimeAgo(createdAt);

    final postId = post['id'];
    final isLiked = _likedPosts[postId] ?? false;
    final imageUrls = post['image_urls'] as List?;
    final linkUrl = post['link_url'] as String?;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailsScreen(postId: postId),
          ),
        ).then((_) => _refreshPosts());
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildAvatar(avatarUrl, post['user_name']),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['user_name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post['title'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post['description'],
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Link section
            if (linkUrl != null && linkUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => _launchUrl(linkUrl),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8A1FFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF8A1FFF).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.link, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            linkUrl,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8A1FFF),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.open_in_new,
                          color: Color(0xFF8A1FFF),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (linkUrl != null && linkUrl.isNotEmpty) const SizedBox(height: 12),

            // 🎯 REPLACE THIS ENTIRE SECTION 🎯
            // Multiple images with PageView and page indicator
            if (imageUrls != null && imageUrls.isNotEmpty)
              StatefulBuilder(
                builder: (context, setStateLocal) {
                  int currentPage = 0;

                  return SizedBox(
                    height: 250,
                    child: Stack(
                      children: [
                        PageView.builder(
                          itemCount: imageUrls.length,
                          onPageChanged: (index) {
                            setStateLocal(() {
                              currentPage = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onDoubleTap: () => _togglePostLike(postId),
                              child: Image.network(
                                imageUrls[index],
                                width: double.infinity,
                                height: 250,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 250,
                                  color: Colors.grey.shade200,
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Dot indicators at bottom center
                        if (imageUrls.length > 1)
                          Positioned(
                            bottom: 12,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                imageUrls.length,
                                    (index) => Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: currentPage == index ? 24 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: currentPage == index
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Image counter badge at top right
                        if (imageUrls.length > 1)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.collections,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${currentPage + 1}/${imageUrls.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _togglePostLike(postId),
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 22,
                          color: isLiked ? Colors.red : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post['likes_count']}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isLiked ? Colors.red : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildActionChip(
                    icon: Icons.chat_bubble_outline,
                    label: '${post['comments_count']}',
                  ),
                  const Spacer(),
// 👇 ADD SHARE BUTTON
                  IconButton(
                    onPressed: () => _sharePost(postId, post['title']),
                    icon: const Icon(Icons.share_outlined, size: 20),
                    color: Colors.grey.shade700,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Share',
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostSkeleton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 250,
            color: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    final createdAt = DateTime.parse(challenge['created_at']);
    final timeAgo = _getTimeAgo(createdAt);
    final avatarUrl = challenge['avatar_url'];
    final challengeId = challenge['id'];
    final isLiked = _likedChallenges[challengeId] ?? false;
    final isJoined = _joinedChallenges[challengeId] ?? false;
    final imageUrls = challenge['image_urls'] as List?;
    final linkUrl = challenge['link_url'] as String?;

    Color difficultyColor;
    switch (challenge['difficulty']) {
      case 'easy':
        difficultyColor = Colors.green;
        break;
      case 'hard':
        difficultyColor = Colors.red;
        break;
      default:
        difficultyColor = Colors.orange;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChallengeDetailsScreen(challengeId: challengeId),
          ),
        ).then((_) => _refreshChallenges());
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF8A1FFF).withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildAvatar(avatarUrl, challenge['user_name']),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge['user_name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFBBF24).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.emoji_events, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Challenge',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    challenge['title'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    challenge['description'],
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        icon: Icons.subject,
                        label: _truncateText(challenge['subject'], 15),
                        color: const Color(0xFF8A1FFF),
                      ),
                      _buildInfoChip(
                        icon: Icons.speed,
                        label: challenge['difficulty'].toString().toUpperCase(),
                        color: difficultyColor,
                      ),
                      _buildInfoChip(
                        icon: Icons.timer,
                        label: '${challenge['duration_days']} days',
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Link section
            if (linkUrl != null && linkUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => _launchUrl(linkUrl),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8A1FFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF8A1FFF).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.link, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            linkUrl,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8A1FFF),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.open_in_new,
                          color: Color(0xFF8A1FFF),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (linkUrl != null && linkUrl.isNotEmpty) const SizedBox(height: 12),

            // 🎯 UPDATED: Multiple images with swipeable PageView
            if (imageUrls != null && imageUrls.isNotEmpty)
              SizedBox(
                height: 250,
                child: _ChallengeImageCarousel(
                  imageUrls: List<String>.from(imageUrls),
                  onDoubleTap: () => _toggleChallengeLike(challengeId),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _toggleChallengeLike(challengeId),
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 22,
                          color: isLiked ? Colors.red : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${challenge['likes_count']}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isLiked ? Colors.red : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildActionChip(
                    icon: Icons.people_outline,
                    label: '${challenge['participants_count']}',
                  ),
                  const SizedBox(width: 16),
                  _buildActionChip(
                    icon: Icons.chat_bubble_outline,
                    label: '${challenge['comments_count']}',
                  ),
                  const Spacer(),
// 👇 ADD SHARE BUTTON
                  IconButton(
                    onPressed: () => _shareChallenge(challengeId, challenge['title']),
                    icon: const Icon(Icons.share_outlined, size: 20),
                    color: Colors.grey.shade700,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Share',
                  ),
                  const SizedBox(width: 8),
                  if (isJoined)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check_circle, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Joined',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String userName) {
    // Debug: Print what we're receiving
    print('Building avatar for $userName: "$avatarUrl"');

    if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl != 'null') {
      // Try to parse and validate the URL
      try {
        final uri = Uri.parse(avatarUrl);
        if (uri.isAbsolute) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              avatarUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('Error loading avatar: $error');
                return _buildAvatarFallback(userName);
              },
            ),
          );
        } else {
          print('Invalid URL format: $avatarUrl');
          return _buildAvatarFallback(userName);
        }
      } catch (e) {
        print('Error parsing avatar URL: $e');
        return _buildAvatarFallback(userName);
      }
    }
    return _buildAvatarFallback(userName);
  }

  Widget _buildAvatarFallback(String userName) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF8A1FFF), const Color(0xFFC43AFF)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A1FFF).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({required IconData icon, required String label}) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF8A1FFF), const Color(0xFFC43AFF)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.lock_outline, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 32),
              const Text(
                'Sign In Required',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please log in to view the feed',
                style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  icon: const Icon(Icons.login, color: Colors.white),
                  label: const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }
}

class _ChallengeImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final VoidCallback onDoubleTap;

  const _ChallengeImageCarousel({
    required this.imageUrls,
    required this.onDoubleTap,
  });

  @override
  State<_ChallengeImageCarousel> createState() => _ChallengeImageCarouselState();
}

class _ChallengeImageCarouselState extends State<_ChallengeImageCarousel> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          itemCount: widget.imageUrls.length,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemBuilder: (context, index) {
            return GestureDetector(
              onDoubleTap: widget.onDoubleTap,
              child: Image.network(
                widget.imageUrls[index],
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 250,
                  color: Colors.grey.shade200,
                  child: Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            );
          },
        ),

        // Dot indicators at bottom center
        if (widget.imageUrls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.imageUrls.length,
                    (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Image counter badge at top right
        if (widget.imageUrls.length > 1)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.collections,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_currentPage + 1}/${widget.imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}