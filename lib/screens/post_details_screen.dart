import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/post_service.dart';
import '../services/user_session.dart';

class PostDetailsScreen extends StatefulWidget {
  final String postId;

  const PostDetailsScreen({super.key, required this.postId});

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];
  Map<String, List<Map<String, dynamic>>> _replies = {};
  Map<String, bool> _commentLikes = {};
  Map<String, bool> _expandedComments = {};
  String? _replyingToCommentId;
  bool _isLoading = true;
  bool _isLiked = false;
  bool _hasAcceptedChallenge = false;
  int _acceptancesCount = 0;
  bool _isAuthenticated = false;
  bool _hasAccess = false;
  String? _userExamId;
  final _commentController = TextEditingController();
  final _replyController = TextEditingController();
  bool _isSubmittingComment = false;
  bool _isSubmittingReply = false;
  final _supabase = Supabase.instance.client;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    _checkAuthAndLoadPost();
  }

  Future<void> _checkAuthAndLoadPost() async {
    final isLoggedIn = await UserSession.checkLogin();
    final currentUser = _supabase.auth.currentUser;

    setState(() {
      _isAuthenticated = isLoggedIn && currentUser != null;
    });

    if (_isAuthenticated) {
      await _loadUserExam();
      await _loadPostDetails();
      _animationController.forward();
    } else {
      setState(() => _isLoading = false);
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
        setState(() {
          _userExamId = response['exam_id'];
        });
      }
    } catch (e) {
      print('Error loading user exam: $e');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPostDetails() async {
    setState(() => _isLoading = true);

    try {
      final post = await PostService.getPostById(widget.postId);

      if (post == null) {
        setState(() {
          _isLoading = false;
          _hasAccess = false;
        });
        return;
      }

      // Check if post creator has same exam as current user
      final postUserId = post['user_id'];
      final userProfile = await _supabase
          .from('user_profiles')
          .select('exam_id')
          .eq('id', postUserId)
          .maybeSingle();

      if (userProfile == null || userProfile['exam_id'] != _userExamId) {
        setState(() {
          _isLoading = false;
          _hasAccess = false;
        });
        return;
      }

      // User has access, load everything
      final comments = await PostService.getComments(widget.postId);
      final hasLiked = await PostService.hasUserLiked(widget.postId);
      final hasAccepted = await PostService.hasUserAcceptedChallenge(widget.postId);
      final acceptancesCount = await PostService.getChallengeAcceptancesCount(widget.postId);

      // Load comment likes
      final commentLikes = <String, bool>{};
      for (var comment in comments) {
        commentLikes[comment['id']] = await PostService.hasUserLikedComment(comment['id']);
      }

      // Load replies for each comment
      final replies = <String, List<Map<String, dynamic>>>{};
      for (var comment in comments) {
        replies[comment['id']] = await PostService.getReplies(comment['id']);
      }

      setState(() {
        _post = post;
        _comments = comments;
        _replies = replies;
        _commentLikes = commentLikes;
        _isLiked = hasLiked;
        _hasAcceptedChallenge = hasAccepted;
        _acceptancesCount = acceptancesCount;
        _hasAccess = true;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading post: $e');
      setState(() {
        _isLoading = false;
        _hasAccess = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_post == null || !_isAuthenticated) return;

    final wasLiked = _isLiked;
    final currentLikes = _post!['likes_count'] as int;

    setState(() {
      _isLiked = !wasLiked;
      _post!['likes_count'] = currentLikes + (wasLiked ? -1 : 1);
    });

    final success = await PostService.toggleLike(widget.postId);

    if (!success) {
      setState(() {
        _isLiked = wasLiked;
        _post!['likes_count'] = currentLikes;
      });
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    if (!_isAuthenticated) return;

    final wasLiked = _commentLikes[commentId] ?? false;
    final comment = _comments.firstWhere((c) => c['id'] == commentId);
    final currentLikes = comment['likes_count'] as int;

    setState(() {
      _commentLikes[commentId] = !wasLiked;
      comment['likes_count'] = currentLikes + (wasLiked ? -1 : 1);
    });

    final success = await PostService.toggleCommentLike(commentId);

    if (!success) {
      setState(() {
        _commentLikes[commentId] = wasLiked;
        comment['likes_count'] = currentLikes;
      });
    }
  }

  Future<void> _submitComment() async {
    if (!_isAuthenticated) {
      _showMessage('Please log in to comment', isError: true);
      return;
    }

    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    setState(() => _isSubmittingComment = true);

    final success = await PostService.addComment(widget.postId, commentText);

    setState(() => _isSubmittingComment = false);

    if (success) {
      _commentController.clear();
      FocusScope.of(context).unfocus();
      _loadPostDetails();
      _showMessage('Comment added!', isError: false);
    } else {
      _showMessage('Failed to add comment', isError: true);
    }
  }

  Future<void> _submitReply(String commentId) async {
    if (!_isAuthenticated) {
      _showMessage('Please log in to reply', isError: true);
      return;
    }

    final replyText = _replyController.text.trim();
    if (replyText.isEmpty) return;

    setState(() => _isSubmittingReply = true);

    final success = await PostService.addReply(commentId, replyText);

    setState(() => _isSubmittingReply = false);

    if (success) {
      _replyController.clear();
      setState(() => _replyingToCommentId = null);
      FocusScope.of(context).unfocus();
      _loadPostDetails();
      _showMessage('Reply added!', isError: false);
    } else {
      _showMessage('Failed to add reply', isError: true);
    }
  }

  Future<void> _acceptChallenge() async {
    if (!_isAuthenticated) {
      _showMessage('Please log in to accept challenges', isError: true);
      return;
    }

    final success = await PostService.acceptChallenge(widget.postId);

    if (success) {
      setState(() {
        _hasAcceptedChallenge = true;
        _acceptancesCount++;
      });
      _showMessage('Challenge accepted! Good luck! 🎯', isError: false);
    } else {
      _showMessage('Failed to accept challenge', isError: true);
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
        title: _post != null
            ? Text(
          "${_post!['user_name']}'s Post",
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        )
            : const Text(
          'Post Details',
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
              'Loading post...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (!_hasAccess || _post == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Post not available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'This post is from a different exam group',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
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
                    _buildPostContent(),
                    const SizedBox(height: 24),
                    _buildCommentsSection(),
                  ],
                ),
              ),
            ),
            _buildCommentInput(),
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
                'Please log in to view post details',
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

  Widget _buildPostContent() {
    final createdAt = DateTime.parse(_post!['created_at']);
    final timeAgo = _getTimeAgo(createdAt);
    final isChallenge = _post!['challenge_type'] != null;
    final avatarUrl = _post!['avatar_url'] as String?;
    final userName = _post!['user_name'] ?? 'U';

    return Container(
      margin: const EdgeInsets.all(16),
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
                        _post!['user_name'],
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
                if (isChallenge)
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
                  _post!['title'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _post!['description'],
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_post!['image_url'] != null)
            ClipRRect(
              child: Image.network(
                _post!['image_url'],
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
                      label: '${_post!['likes_count']}',
                      color: _isLiked ? Colors.red : Colors.grey.shade700,
                      onTap: _toggleLike,
                    ),
                    const SizedBox(width: 20),
                    _buildActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: '${_post!['comments_count']}',
                      color: Colors.grey.shade700,
                    ),
                    if (isChallenge) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.people, color: Color(0xFFF59E0B), size: 20),
                            const SizedBox(width: 6),
                            Text(
                              '$_acceptancesCount accepted',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (isChallenge) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _hasAcceptedChallenge
                            ? [const Color(0xFF10B981), const Color(0xFF059669)]
                            : [const Color(0xFFFBBF24), const Color(0xFFF59E0B)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (_hasAcceptedChallenge
                              ? const Color(0xFF10B981)
                              : const Color(0xFFFBBF24))
                              .withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _hasAcceptedChallenge ? null : _acceptChallenge,
                      icon: Icon(
                        _hasAcceptedChallenge ? Icons.check_circle : Icons.emoji_events,
                        color: Colors.white,
                      ),
                      label: Text(
                        _hasAcceptedChallenge ? 'Challenge Accepted!' : 'Accept Challenge',
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
              ],
            ),
          ),
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
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Comments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF8A1FFF).withOpacity(0.1), const Color(0xFFC43AFF).withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_comments.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_comments.isEmpty)
            Center(
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
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comments.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) => _buildCommentItem(_comments[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final createdAt = DateTime.parse(comment['created_at']);
    final timeAgo = _getTimeAgo(createdAt);
    final commentId = comment['id'];
    final isLiked = _commentLikes[commentId] ?? false;
    final replies = _replies[commentId] ?? [];
    final isExpanded = _expandedComments[commentId] ?? false;
    final isReplying = _replyingToCommentId == commentId;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(comment['avatar_url'], comment['user_name'], size: 36),
              const SizedBox(width: 10),
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
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment['comment_text'],
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleCommentLike(commentId),
                          child: Row(
                            children: [
                              Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: isLiked ? Colors.red : Colors.grey.shade600,
                              ),
                              if (comment['likes_count'] > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '${comment['likes_count']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isLiked ? Colors.red : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_replyingToCommentId == commentId) {
                                _replyingToCommentId = null;
                              } else {
                                _replyingToCommentId = commentId;
                              }
                            });
                          },
                          child: Text(
                            'Reply',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (replies.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _expandedComments[commentId] = !isExpanded;
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  '${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF8A1FFF),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: const Color(0xFF8A1FFF),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isReplying) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF8A1FFF).withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      decoration: InputDecoration(
                        hintText: 'Reply to ${comment['user_name']}...',
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSubmittingReply ? null : () => _submitReply(commentId),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF8A1FFF), const Color(0xFFC43AFF)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: _isSubmittingReply
                          ? const Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                          : const Icon(Icons.send, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isExpanded && replies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.grey.shade300, width: 2),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: replies.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _buildReplyItem(replies[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyItem(Map<String, dynamic> reply) {
    final createdAt = DateTime.parse(reply['created_at']);
    final timeAgo = _getTimeAgo(createdAt);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatar(reply['avatar_url'], reply['user_name'], size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    reply['user_name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeAgo,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                reply['reply_text'],
                style: TextStyle(
                  fontSize: 13,
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