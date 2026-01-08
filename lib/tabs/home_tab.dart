import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/post_service.dart';
import '../services/challenge_service.dart';
import '../services/user_session.dart';
import '../screens/post_details_screen.dart';
import '../screens/challenge_details_screen.dart';

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
      await _loadUserExam();
      await _loadPosts();
      await _loadChallenges();
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
          .select('exam_id')  // Changed from selected_exam_id to exam_id
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _userExamId = response['exam_id'];  // Changed from selected_exam_id to exam_id
        });
      }
    } catch (e) {
      print('Error loading user exam: $e');
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoadingPosts = true);

    try {
      // Get all posts first
      final allPosts = await PostService.getPosts();

      // Filter posts by user's selected exam AND exclude challenges
      final filteredPosts = <Map<String, dynamic>>[];

      for (var post in allPosts) {
        // Skip posts that are challenges
        if (post['challenge_type'] == 'study_challenge') {
          continue;
        }

        final postUserId = post['user_id'];

        // Get the post creator's exam
        final userProfile = await _supabase
            .from('user_profiles')
            .select('exam_id')
            .eq('id', postUserId)
            .maybeSingle();

        if (userProfile != null && userProfile['exam_id'] == _userExamId) {
          filteredPosts.add(post);
        }
      }

      // Load liked status for each post
      final likedPosts = <String, bool>{};
      for (var post in filteredPosts) {
        likedPosts[post['id']] = await PostService.hasUserLiked(post['id']);
      }

      setState(() {
        _posts = filteredPosts;
        _likedPosts = likedPosts;
        _isLoadingPosts = false;
      });
    } catch (e) {
      print('Error loading posts: $e');
      setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoadingChallenges = true);

    try {
      // Get all posts first
      final allPosts = await PostService.getPosts();

      // Filter ONLY posts with challenge_type = 'study_challenge'
      final challenges = allPosts.where((post) => post['challenge_type'] == 'study_challenge').toList();

      // Load liked status for each challenge
      final likedChallenges = <String, bool>{};
      final joinedChallenges = <String, bool>{};

      for (var challenge in challenges) {
        likedChallenges[challenge['id']] = await PostService.hasUserLiked(challenge['id']);
        // Set joined status (you'll need to implement this properly later)
        joinedChallenges[challenge['id']] = false;

        // Add default values for missing challenge fields
        challenge['subject'] = challenge['subject'] ?? 'General';
        challenge['difficulty'] = challenge['difficulty'] ?? 'medium';
        challenge['duration_days'] = challenge['duration_days'] ?? 7;
        challenge['participants_count'] = challenge['participants_count'] ?? 0;
      }

      setState(() {
        _challenges = challenges;
        _likedChallenges = likedChallenges;
        _joinedChallenges = joinedChallenges;
        _isLoadingChallenges = false;
      });
    } catch (e) {
      print('Error loading challenges: $e');
      setState(() => _isLoadingChallenges = false);
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

  Future<void> _toggleChallengeLike(String challengeId) async {
    if (!_isAuthenticated) return;

    final challenge = _challenges.firstWhere((c) => c['id'] == challengeId);
    final wasLiked = _likedChallenges[challengeId] ?? false;
    final currentLikes = challenge['likes_count'] as int;

    setState(() {
      _likedChallenges[challengeId] = !wasLiked;
      challenge['likes_count'] = currentLikes + (wasLiked ? -1 : 1);
    });

    // Use PostService since challenges are actually posts
    final success = await PostService.toggleLike(challengeId);

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
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: TabBar(
              controller: _tabController,
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
              'Loading posts...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
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
    final createdAt = DateTime.parse(post['created_at']);
    final timeAgo = _getTimeAgo(createdAt);
    final avatarUrl = post['avatar_url'];
    final postId = post['id'];
    final isLiked = _likedPosts[postId] ?? false;

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
            if (post['image_url'] != null)
              GestureDetector(
                onDoubleTap: () => _togglePostLike(postId),
                child: ClipRRect(
                  child: Image.network(
                    post['image_url'],
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
                ),
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

  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    final createdAt = DateTime.parse(challenge['created_at']);
    final timeAgo = _getTimeAgo(createdAt);
    final avatarUrl = challenge['avatar_url'];
    final challengeId = challenge['id'];
    final isLiked = _likedChallenges[challengeId] ?? false;
    final isJoined = _joinedChallenges[challengeId] ?? false;

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
                        label: challenge['subject'],
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
            if (challenge['image_url'] != null)
              GestureDetector(
                onDoubleTap: () => _toggleChallengeLike(challengeId),
                child: ClipRRect(
                  child: Image.network(
                    challenge['image_url'],
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
    if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl != 'null') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          avatarUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildAvatarFallback(userName);
          },
        ),
      );
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
}