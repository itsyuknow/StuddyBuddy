import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/challenge_service.dart';
import '../services/user_session.dart';
import 'edit_challenge_screen.dart';

class ChallengeDetailsScreen extends StatefulWidget {
  final String challengeId;

  const ChallengeDetailsScreen({super.key, required this.challengeId});

  @override
  State<ChallengeDetailsScreen> createState() => _ChallengeDetailsScreenState();
}

class _ChallengeDetailsScreenState extends State<ChallengeDetailsScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _challenge;
  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _participants = [];
  List<Map<String, dynamic>> _updates = [];
  bool _isLoading = true;
  bool _isLiked = false;
  bool _hasJoined = false;
  bool _isAuthenticated = false;
  final _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _selectedTab = 0; // 0: Comments, 1: Updates, 2: Participants

  Map<String, List<Map<String, dynamic>>> _replies = {};
  Map<String, bool> _commentLikes = {};
  Map<String, bool> _expandedComments = {};
  String? _replyingToCommentId;
  final _replyController = TextEditingController();
  bool _isSubmittingReply = false;
  final _supabase = Supabase.instance.client;


  Map<String, List<Map<String, dynamic>>> _nestedReplies = {}; // Add this

  Map<String, bool> _replyLikes = {}; // Add this

  Map<String, bool> _expandedReplies = {}; // Add this

  String? _replyingToReplyId; // Add this

  final _nestedReplyController = TextEditingController(); // Add this

  bool _isSubmittingNestedReply = false; // Add this

  bool _isOwner = false;

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

    setState(() {
      _isAuthenticated = isLoggedIn;
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
    _replyController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadChallengeDetails() async {
    setState(() => _isLoading = true);

    try {
      print('=== DEBUG: Loading challenge ${widget.challengeId} ===');

      // Get challenge details using ChallengeService
      final challenge = await ChallengeService.getChallengeById(widget.challengeId);
      print('Challenge data: $challenge');

      if (challenge == null) {
        print('ERROR: Challenge is null!');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _challenge = null;
          });
        }
        return;
      }

      // Validate and set default values for required fields
      if (challenge['created_at'] == null) {
        print('WARNING: Challenge missing created_at field');
        challenge['created_at'] = DateTime.now().toIso8601String();
      }

      if (challenge['expires_at'] == null) {
        print('WARNING: Challenge missing expires_at field');
        final durationDays = challenge['duration_days'] ?? 7;
        challenge['expires_at'] = DateTime.now()
            .add(Duration(days: durationDays as int))
            .toIso8601String();
      }

      // Ensure counts are not null
      challenge['likes_count'] = challenge['likes_count'] ?? 0;
      challenge['participants_count'] = challenge['participants_count'] ?? 0;
      challenge['comments_count'] = challenge['comments_count'] ?? 0;

      // Get comments using ChallengeService
      final comments = await ChallengeService.getComments(widget.challengeId);
      print('Comments count: ${comments.length}');

      // Get participants using ChallengeService
      final participants = await ChallengeService.getParticipants(widget.challengeId);
      print('Participants count: ${participants.length}');

      // Get updates using ChallengeService
      final updates = await ChallengeService.getUpdates(widget.challengeId);
      print('Updates count: ${updates.length}');

      // Check if user has liked this challenge
      final hasLiked = await ChallengeService.hasUserLiked(widget.challengeId);
      print('User has liked: $hasLiked');

      // Check if user has joined this challenge
      final hasJoined = await ChallengeService.hasUserJoinedChallenge(widget.challengeId);
      print('User has joined: $hasJoined');

      // Load comment likes
      final commentLikes = <String, bool>{};
      for (var comment in comments) {
        commentLikes[comment['id']] = await ChallengeService.hasUserLikedComment(comment['id']);
      }

      // Load replies for each comment
      final replies = <String, List<Map<String, dynamic>>>{};
      final replyLikes = <String, bool>{};
      final nestedReplies = <String, List<Map<String, dynamic>>>{};

      for (var comment in comments) {
        final commentReplies = await ChallengeService.getReplies(comment['id']);
        replies[comment['id']] = commentReplies;

        // Load likes and nested replies for each reply
        for (var reply in commentReplies) {
          replyLikes[reply['id']] = await ChallengeService.hasUserLikedReply(reply['id']);
          nestedReplies[reply['id']] = await ChallengeService.getNestedReplies(reply['id']);
        }
      }

      // Check if current user is the challenge owner
      final currentUserId = _supabase.auth.currentUser?.id;
      final challengeOwnerId = challenge['user_id'];

      if (mounted) {
        setState(() {
          _challenge = challenge;
          _comments = comments;
          _participants = participants;
          _updates = updates;
          _replies = replies;
          _commentLikes = commentLikes;
          _replyLikes = replyLikes;
          _nestedReplies = nestedReplies;
          _isLiked = hasLiked;
          _hasJoined = hasJoined;
          _isOwner = currentUserId == challengeOwnerId;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('ERROR loading challenge: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _challenge = null;
        });
      }
    }
  }

  Future<void> _refreshChallengeDetails() async {
    await _loadChallengeDetails();
  }

  Future<void> _toggleReplyLike(String replyId) async {
    if (!_isAuthenticated) return;

    final wasLiked = _replyLikes[replyId] ?? false;
    final reply = _replies.values
        .expand((list) => list)
        .firstWhere((r) => r['id'] == replyId);
    final currentLikes = reply['likes_count'] as int? ?? 0;

    setState(() {
      _replyLikes[replyId] = !wasLiked;
      reply['likes_count'] = currentLikes + (wasLiked ? -1 : 1);
    });

    final success = await ChallengeService.toggleReplyLike(replyId);

    if (!success) {
      setState(() {
        _replyLikes[replyId] = wasLiked;
        reply['likes_count'] = currentLikes;
      });
    }
  }

  Future<void> _submitNestedReply(String replyId) async {
    if (!_isAuthenticated) {
      _showMessage('Please log in to reply', isError: true);
      return;
    }

    final replyText = _nestedReplyController.text.trim();
    if (replyText.isEmpty) return;

    setState(() => _isSubmittingNestedReply = true);

    final success = await ChallengeService.addReplyToReply(replyId, replyText);

    setState(() => _isSubmittingNestedReply = false);

    if (success) {
      _nestedReplyController.clear();
      setState(() => _replyingToReplyId = null);
      FocusScope.of(context).unfocus();
      _loadChallengeDetails();
      _showMessage('Reply added!', isError: false);
    } else {
      _showMessage('Failed to add reply', isError: true);
    }
  }

  Future<void> _toggleLike() async {
    if (_challenge == null || !_isAuthenticated) return;

    final wasLiked = _isLiked;
    final currentLikes = _challenge!['likes_count'] as int;

    setState(() {
      _isLiked = !wasLiked;
      _challenge!['likes_count'] = currentLikes + (wasLiked ? -1 : 1);
    });

    final success = await ChallengeService.toggleLike(widget.challengeId);

    if (!success) {
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
      await _loadChallengeDetails(); // Reload to get updated participants list
    } else {
      _showMessage('Failed to join challenge', isError: true);
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

    final success = await ChallengeService.addComment(widget.challengeId, commentText);

    if (success) {
      setState(() => _isSubmittingComment = false);
      _commentController.clear();
      FocusScope.of(context).unfocus();

      // Update comments count
      if (_challenge != null) {
        setState(() {
          _challenge!['comments_count'] = (_challenge!['comments_count'] as int) + 1;
        });
      }

      // Reload comments
      final comments = await ChallengeService.getComments(widget.challengeId);
      setState(() {
        _comments = comments;
      });

      _showMessage('Comment added!', isError: false);
    } else {
      setState(() => _isSubmittingComment = false);
      _showMessage('Failed to add comment', isError: true);
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

    final success = await ChallengeService.toggleCommentLike(commentId);

    if (!success) {
      setState(() {
        _commentLikes[commentId] = wasLiked;
        comment['likes_count'] = currentLikes;
      });
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

    final success = await ChallengeService.addReply(commentId, replyText);

    setState(() => _isSubmittingReply = false);

    if (success) {
      _replyController.clear();
      setState(() => _replyingToCommentId = null);
      FocusScope.of(context).unfocus();
      _loadChallengeDetails();
      _showMessage('Reply added!', isError: false);
    } else {
      _showMessage('Failed to add reply', isError: true);
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

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF8A1FFF)),
                title: const Text('Edit Challenge', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToEdit();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Challenge', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditChallengeScreen(challenge: _challenge!),
      ),
    );

    if (result == true) {
      _loadChallengeDetails();
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Challenge?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This action cannot be undone. All participants, comments, and updates will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChallenge();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChallenge() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await ChallengeService.deleteChallenge(widget.challengeId);

    Navigator.pop(context); // Close loading

    if (success) {
      _showMessage('Challenge deleted successfully', isError: false);
      await Future.delayed(const Duration(milliseconds: 500));
      Navigator.pop(context, true); // Return true to indicate deletion
    } else {
      _showMessage('Failed to delete challenge', isError: true);
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
        actions: [
          if (_isOwner && _challenge != null)
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: _showOptionsMenu,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isAuthenticated) {
      return _buildLoginPrompt();
    }

    if (_isLoading) {
      // ✨ NEW: Show skeleton instead of just spinner
      return _buildChallengeSkeleton();
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
              child: RefreshIndicator(
                onRefresh: _refreshChallengeDetails,
                color: const Color(0xFF8A1FFF),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildChallengeContent(),
                      const SizedBox(height: 24),
                      _buildTabBar(),
                      const SizedBox(height: 16),
                      _buildTabContent(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
            if (_selectedTab == 0) _buildCommentInput(),
          ],
        ),
      ),
    );
  }

// ✨ ADD this new method for the skeleton loader:
  Widget _buildChallengeSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Challenge Card Skeleton
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Skeleton
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
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
                              const SizedBox(height: 8),
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
                        ),
                        Container(
                          width: 90,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Title & Description Skeleton
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: MediaQuery.of(context).size.width * 0.7,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Info chips skeleton
                        Row(
                          children: [
                            Container(
                              width: 100,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 80,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 90,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Image Skeleton
                  Container(
                    width: double.infinity,
                    height: 320,
                    color: Colors.grey.shade300,
                  ),
                  // Actions Skeleton
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 70,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Container(
                              width: 60,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Container(
                              width: 50,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Tab Bar Skeleton
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: List.generate(
                  3,
                      (index) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Content Section Skeleton
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: List.generate(
                  3,
                      (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 100,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 200,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
                      label: _truncateText(_challenge!['subject'], 15),
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
    final replyId = reply['id'];
    final isLiked = _replyLikes[replyId] ?? false;
    final likesCount = reply['likes_count'] as int? ?? 0;
    final nestedReplies = _nestedReplies[replyId] ?? [];
    final isExpanded = _expandedReplies[replyId] ?? false;
    final isReplying = _replyingToReplyId == replyId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _toggleReplyLike(replyId),
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 14,
                              color: isLiked ? Colors.red : Colors.grey.shade600,
                            ),
                            if (likesCount > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '$likesCount',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isLiked ? Colors.red : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_replyingToReplyId == replyId) {
                              _replyingToReplyId = null;
                            } else {
                              _replyingToReplyId = replyId;
                            }
                          });
                        },
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      if (nestedReplies.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _expandedReplies[replyId] = !isExpanded;
                            });
                          },
                          child: Row(
                            children: [
                              Text(
                                '${nestedReplies.length} ${nestedReplies.length == 1 ? 'reply' : 'replies'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8A1FFF),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                size: 14,
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
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF8A1FFF).withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nestedReplyController,
                      decoration: InputDecoration(
                        hintText: 'Reply to ${reply['user_name']}...',
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _isSubmittingNestedReply ? null : () => _submitNestedReply(replyId),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: _isSubmittingNestedReply
                          ? const Center(
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                          : const Icon(Icons.send, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (isExpanded && nestedReplies.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.grey.shade300, width: 1.5),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: nestedReplies.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _buildNestedReplyItem(nestedReplies[index]),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNestedReplyItem(Map<String, dynamic> nestedReply) {
    final createdAt = DateTime.parse(nestedReply['created_at']);
    final timeAgo = _getTimeAgo(createdAt);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatar(nestedReply['avatar_url'], nestedReply['user_name'], size: 24),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    nestedReply['user_name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    timeAgo,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                nestedReply['reply_text'],
                style: TextStyle(
                  fontSize: 12,
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

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }
}