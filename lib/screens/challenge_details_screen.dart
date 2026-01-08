import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/challenge_service.dart';
import '../services/user_session.dart';


class ChallengeDetailsScreen extends StatefulWidget {
  final String challengeId;

  const ChallengeDetailsScreen({super.key, required this.challengeId});

  @override
  State<ChallengeDetailsScreen> createState() => _ChallengeDetailsScreenState();
}

class _ChallengeDetailsScreenState extends State<ChallengeDetailsScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _challenge;
  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _participants = [];
  List<Map<String, dynamic>> _updates = [];
  Map<String, bool> _commentLikes = {};
  bool _isLoading = true;
  bool _isLiked = false;
  bool _hasJoined = false;
  bool _isAuthenticated = false;
  final _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  final _supabase = Supabase.instance.client;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _selectedTab = 0; // 0: Comments, 1: Updates, 2: Participants

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _checkAuthAndLoadChallenge();
  }

  Future<void> _checkAuthAndLoadChallenge() async {
    final isLoggedIn = await UserSession.checkLogin();
    final currentUser = _supabase.auth.currentUser;

    setState(() {
      _isAuthenticated = isLoggedIn && currentUser != null;
    });

    if (_isAuthenticated) {
      await _loadChallengeDetails();
      _animationController.forward();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadChallengeDetails() async {
    setState(() => _isLoading = true);

    try {
      // Since challenges are posts, we need to get the post first
      // You'll need to update your PostService to have a getPostById method
      // If you don't have it, here's a direct Supabase query:
      final response = await _supabase
          .from('posts')
          .select('*')
          .eq('id', widget.challengeId)
          .maybeSingle();

      if (response == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get user profile for the post creator
      final userResponse = await _supabase
          .from('user_profiles')
          .select('display_name, avatar_url, exam_id')
          .eq('id', response['user_id'])
          .maybeSingle();

      // Combine post data with user info
      final challenge = Map<String, dynamic>.from(response);
      if (userResponse != null) {
        challenge['user_name'] = userResponse['display_name'];
        challenge['avatar_url'] = userResponse['avatar_url'];
      }

      // Since this is a post (not a separate challenge), add default values
      challenge['subject'] = challenge['subject'] ?? 'General';
      challenge['difficulty'] = challenge['difficulty'] ?? 'medium';
      challenge['duration_days'] = challenge['duration_days'] ?? 7;
      challenge['expires_at'] = challenge['expires_at'] ??
          DateTime.now().add(const Duration(days: 7)).toIso8601String();
      challenge['target_score'] = challenge['target_score'] ?? 100;

      // Get comments from posts_comments table
      final commentsResponse = await _supabase
          .from('posts_comments')
          .select('*, user_profiles(display_name, avatar_url)')
          .eq('post_id', widget.challengeId)
          .order('created_at', ascending: false);

      final comments = commentsResponse.map((comment) {
        final userProfile = comment['user_profiles'] as Map<String, dynamic>?;
        return {
          'id': comment['id'],
          'user_id': comment['user_id'],
          'user_name': userProfile?['display_name'] ?? 'User',
          'avatar_url': userProfile?['avatar_url'],
          'comment_text': comment['comment_text'],
          'created_at': comment['created_at'],
          'likes_count': comment['likes_count'] ?? 0,
        };
      }).toList();

      // Check if user has liked this post
      final userId = _supabase.auth.currentUser?.id;
      bool hasLiked = false;
      if (userId != null) {
        final likeResponse = await _supabase
            .from('posts_likes')
            .select('id')
            .eq('post_id', widget.challengeId)
            .eq('user_id', userId)
            .maybeSingle();
        hasLiked = likeResponse != null;
      }

      // Check if user has joined (since you don't have a join system yet, set to false)
      bool hasJoined = false;

      // Get participants (for now, we'll just get users who commented)
      final participants = <Map<String, dynamic>>[];
      for (var comment in comments) {
        if (!participants.any((p) => p['user_id'] == comment['user_id'])) {
          participants.add({
            'user_id': comment['user_id'],
            'user_name': comment['user_name'],
            'avatar_url': comment['avatar_url'],
            'progress': 0,
            'completed': false,
          });
        }
      }

      // Updates (for now, empty list - you'll need to implement this separately)
      final updates = <Map<String, dynamic>>[];

      setState(() {
        _challenge = challenge;
        _comments = comments;
        _participants = participants;
        _updates = updates;
        _isLiked = hasLiked;
        _hasJoined = hasJoined;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading challenge: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_challenge == null || !_isAuthenticated) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final wasLiked = _isLiked;
    final currentLikes = _challenge!['likes_count'] as int;

    setState(() {
      _isLiked = !wasLiked;
      _challenge!['likes_count'] = currentLikes + (wasLiked ? -1 : 1);
    });

    try {
      if (wasLiked) {
        // Unlike
        await _supabase
            .from('posts_likes')
            .delete()
            .eq('post_id', widget.challengeId)
            .eq('user_id', userId);
      } else {
        // Like
        await _supabase
            .from('posts_likes')
            .insert({
          'post_id': widget.challengeId,
          'user_id': userId,
        });
      }
    } catch (e) {
      print('Error toggling like: $e');
      setState(() {
        _isLiked = wasLiked;
        _challenge!['likes_count'] = currentLikes;
      });
    }
  }

  Future<void> _joinChallenge() async {
    if (!_isAuthenticated) {
      _showMessage('Please log in to join challenges', isError: true);
      return;
    }

    final success = await ChallengeService.joinChallenge(widget.challengeId);

    if (success) {
      setState(() {
        _hasJoined = true;
        _challenge!['participants_count'] = (_challenge!['participants_count'] as int) + 1;
      });
      _showMessage('Challenge joined! Good luck! 🎯', isError: false);
      await _loadChallengeDetails();
    } else {
      _showMessage('Failed to join challenge', isError: true);
    }
  }

  Future<void> _submitComment() async {
    if (!_isAuthenticated) {
      _showMessage('Please log in to comment', isError: true);
      return;
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    setState(() => _isSubmittingComment = true);

    try {
      await _supabase
          .from('posts_comments')
          .insert({
        'post_id': widget.challengeId,
        'user_id': userId,
        'comment_text': commentText,
      });

      // Update comments count in the post
      await _supabase
          .from('posts')
          .update({'comments_count': _challenge!['comments_count'] + 1})
          .eq('id', widget.challengeId);

      setState(() => _isSubmittingComment = false);
      _commentController.clear();
      FocusScope.of(context).unfocus();

      // Reload to get the new comment
      await _loadChallengeDetails();

      _showMessage('Comment added!', isError: false);
    } catch (e) {
      print('Error adding comment: $e');
      setState(() => _isSubmittingComment = false);
      _showMessage('Failed to add comment', isError: true);
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
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
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
        centerTitle: false,
        titleSpacing: 0,
        title: const Text(
          'Challenge Details',
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isAuthenticated) {
      return _buildLoginPrompt();
    }

    if (_isLoading) {
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
              'Loading challenge...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_challenge == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Challenge not found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildChallengeContent(),
                    const SizedBox(height: 24),
                    _buildTabBar(),
                    const SizedBox(height: 16),
                    _buildTabContent(),
                  ],
                ),
              ),
            ),
            if (_selectedTab == 0) _buildCommentInput(),
          ],
        ),
      ),
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
                'Please log in to view challenge details',
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

  Widget _buildChallengeContent() {
    final createdAt = DateTime.parse(_challenge!['created_at']);
    final expiresAt = DateTime.parse(_challenge!['expires_at']);
    final timeAgo = _getTimeAgo(createdAt);
    final daysRemaining = expiresAt.difference(DateTime.now()).inDays;
    final avatarUrl = _challenge!['avatar_url'] as String?;
    final userName = _challenge!['user_name'] ?? 'U';

    Color difficultyColor;
    switch (_challenge!['difficulty']) {
      case 'easy':
        difficultyColor = Colors.green;
        break;
      case 'hard':
        difficultyColor = Colors.red;
        break;
      default:
        difficultyColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.all(16),
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
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildAvatar(avatarUrl, userName, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _challenge!['user_name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFBBF24).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.emoji_events, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Challenge',
                        style: TextStyle(
                          fontSize: 13,
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _challenge!['title'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _challenge!['description'],
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(
                      icon: Icons.subject,
                      label: _challenge!['subject'],
                      color: const Color(0xFF8A1FFF),
                    ),
                    _buildInfoChip(
                      icon: Icons.speed,
                      label: _challenge!['difficulty'].toString().toUpperCase(),
                      color: difficultyColor,
                    ),
                    _buildInfoChip(
                      icon: Icons.timer,
                      label: '$daysRemaining days left',
                      color: daysRemaining < 3 ? Colors.red : Colors.blue,
                    ),
                    if (_challenge!['target_score'] != null)
                      _buildInfoChip(
                        icon: Icons.stars,
                        label: 'Target: ${_challenge!['target_score']}',
                        color: Colors.amber,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_challenge!['image_url'] != null)
            ClipRRect(
              child: Image.network(
                _challenge!['image_url'],
                width: double.infinity,
                height: 320,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 320,
                  color: Colors.grey.shade200,
                  child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey.shade400),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildActionButton(
                      icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                      label: '${_challenge!['likes_count']}',
                      color: _isLiked ? Colors.red : Colors.grey.shade700,
                      onTap: _toggleLike,
                    ),
                    const SizedBox(width: 20),
                    _buildActionButton(
                      icon: Icons.people_outline,
                      label: '${_challenge!['participants_count']}',
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 20),
                    _buildActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: '${_challenge!['comments_count']}',
                      color: Colors.grey.shade700,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _hasJoined
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : [const Color(0xFF8A1FFF), const Color(0xFFC43AFF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_hasJoined
                            ? const Color(0xFF10B981)
                            : const Color(0xFF8A1FFF))
                            .withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _hasJoined ? null : _joinChallenge,
                    icon: Icon(
                      _hasJoined ? Icons.check_circle : Icons.emoji_events,
                      color: Colors.white,
                    ),
                    label: Text(
                      _hasJoined ? 'Challenge Joined!' : 'Join Challenge',
                      style: const TextStyle(
                        fontSize: 16,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'Comments', Icons.chat_bubble_outline),
          _buildTabItem(1, 'Updates', Icons.trending_up),
          _buildTabItem(2, 'Participants', Icons.people_outline),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
              colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
            )
                : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildCommentsSection();
      case 1:
        return _buildUpdatesSection();
      case 2:
        return _buildParticipantsSection();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCommentsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
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
      child: _comments.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'No comments yet',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Be the first to comment!',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      )
          : ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _comments.length,
        separatorBuilder: (context, index) => Divider(height: 24, color: Colors.grey.shade200),
        itemBuilder: (context, index) => _buildCommentItem(_comments[index]),
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final createdAt = DateTime.parse(comment['created_at']);
    final timeAgo = _getTimeAgo(createdAt);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatar(comment['avatar_url'], comment['user_name'], size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comment['user_name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeAgo,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                comment['comment_text'],
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpdatesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
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
      child: _updates.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.trending_up, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'No updates yet',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      )
          : ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _updates.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) => _buildUpdateItem(_updates[index]),
      ),
    );
  }

  Widget _buildUpdateItem(Map<String, dynamic> update) {
    final createdAt = DateTime.parse(update['created_at']);
    final timeAgo = _getTimeAgo(createdAt);
    final progress = update['progress'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(update['avatar_url'], update['user_name'], size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      update['user_name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$progress%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            update['update_text'],
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),
          if (update['image_url'] != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                update['image_url'],
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: Icon(Icons.image_not_supported, size: 32, color: Colors.grey.shade400),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 100 ? const Color(0xFF10B981) : const Color(0xFF8A1FFF),
            ),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
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
      child: _participants.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'No participants yet',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Be the first to join!',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      )
          : ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _participants.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildParticipantItem(_participants[index], index + 1),
      ),
    );
  }

  Widget _buildParticipantItem(Map<String, dynamic> participant, int rank) {
    final progress = participant['progress'] ?? 0;
    final completed = participant['completed'] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: rank <= 3 ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rank <= 3 ? const Color(0xFFFBBF24).withOpacity(0.5) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: rank == 1
                  ? const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)])
                  : rank == 2
                  ? const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFF64748B)])
                  : rank == 3
                  ? const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFA16207)])
                  : LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade500]),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildAvatar(participant['avatar_url'], participant['user_name'], size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant['user_name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          completed ? const Color(0xFF10B981) : const Color(0xFF8A1FFF),
                        ),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$progress%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: completed ? const Color(0xFF10B981) : const Color(0xFF8A1FFF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (completed) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String userName, {double size = 40}) {
    if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl != 'null') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.3),
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildAvatarFallback(userName, size);
          },
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
        gradient: LinearGradient(
          colors: [const Color(0xFF8A1FFF), const Color(0xFFC43AFF)],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A1FFF).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.42,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
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
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Write a comment...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF8A1FFF), const Color(0xFFC43AFF)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8A1FFF).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _isSubmittingComment ? null : _submitComment,
                icon: _isSubmittingComment
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
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