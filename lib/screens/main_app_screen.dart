import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../tabs/home_tab.dart';
import '../tabs/search_tab.dart';
import '../tabs/create_post_tab.dart';
import '../tabs/chat_tab.dart';
import '../tabs/profile_tab.dart';
import '../services/chat_service.dart';
import '../services/deep_link_manager.dart'; // 👈 ADD THIS
import '../main.dart'; // 👈 ADD THIS (for navigatorKey)
import 'post_details_screen.dart'; // 👈 ADD THIS
import 'challenge_details_screen.dart'; // 👈 ADD THIS
import 'user_profile_screen.dart'; // 👈 ADD THIS

class MainAppScreen extends StatefulWidget {
  final int initialTabIndex;

  const MainAppScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  final _supabase = Supabase.instance.client;
  final _deepLinkManager = DeepLinkManager(); // 👈 ADD THIS
  late int _selectedIndex;

  int _unreadMessagesCount = 0;
  int _newPostsCount = 0;
  int _newMatchesCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _loadNotificationCounts();

    // Refresh counts periodically
    _startPeriodicRefresh();

    // 👇 ADD THIS: Check for pending deep links after screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingDeepLink();
    });
  }

  // 👇 ADD THIS METHOD: Handle pending deep links
  Future<void> _handlePendingDeepLink() async {
    // Wait a bit for the screen to fully render
    await Future.delayed(const Duration(milliseconds: 500));

    if (!_deepLinkManager.hasPendingNavigation()) {
      print('📱 No pending deep link');
      return;
    }

    final pendingNav = _deepLinkManager.getPendingNavigation();

    if (pendingNav == null) return;

    print('🚀 Executing pending deep link: $pendingNav');

    final contentType = pendingNav['content_type'];
    final contentId = pendingNav['content_id'];

    // Clear the deep link so it doesn't trigger again
    _deepLinkManager.clearPendingNavigation();

    // Navigate to the appropriate screen
    if (contentType == 'post') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => PostDetailsScreen(postId: contentId),
        ),
      );
      print('✅ Navigated to post: $contentId');
    } else if (contentType == 'challenge') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChallengeDetailsScreen(challengeId: contentId),
        ),
      );
      print('✅ Navigated to challenge: $contentId');
    } else if (contentType == 'user') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: contentId),
        ),
      );
      print('✅ Navigated to user profile: $contentId');
    }
  }

  void _startPeriodicRefresh() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadNotificationCounts();
        _startPeriodicRefresh();
      }
    });
  }

  Future<void> _loadNotificationCounts() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Get unread messages count
      final unreadCount = await ChatService.getUnreadCount();

      // Get new posts count - only show if NOT on home tab
      int newPosts = 0;
      if (_selectedIndex != 0) {
        final prefs = await SharedPreferences.getInstance();
        final lastViewedStr = prefs.getString('last_viewed_home_$currentUserId');

        if (lastViewedStr != null) {
          final lastViewed = DateTime.parse(lastViewedStr);

          // Get user's exam to filter posts
          final userProfile = await _supabase
              .from('user_profiles')
              .select('exam_id')
              .eq('id', currentUserId)
              .maybeSingle();

          if (userProfile != null) {
            final examId = userProfile['exam_id'];

            // Count posts created after last view for user's exam
            final postsResponse = await _supabase
                .from('posts')
                .select('id, user_id')
                .gt('created_at', lastViewed.toIso8601String())
                .neq('challenge_type', 'study_challenge'); // Exclude challenges

            // Filter by exam
            int count = 0;
            for (var post in (postsResponse as List)) {
              final postUserProfile = await _supabase
                  .from('user_profiles')
                  .select('exam_id')
                  .eq('id', post['user_id'])
                  .maybeSingle();

              if (postUserProfile != null && postUserProfile['exam_id'] == examId) {
                count++;
              }
            }
            newPosts = count;
          }
        }
      }

      if (mounted) {
        setState(() {
          _unreadMessagesCount = unreadCount;
          _newPostsCount = newPosts;
          _newMatchesCount = 0; // You can implement this later
        });
      }
    } catch (e) {
      print('Error loading notification counts: $e');
    }
  }

  Future<void> _markHomeAsViewed() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'last_viewed_home_$currentUserId',
        DateTime.now().toIso8601String(),
      );

      // Clear the badge count
      setState(() {
        _newPostsCount = 0;
      });
    } catch (e) {
      print('Error marking home as viewed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeTab(),
          SearchTab(),
          CreatePostTab(),
          ChatTab(),
          ProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(Icons.home_rounded, 'Home', 0, false, _newPostsCount),
                _buildNavItem(Icons.extension_rounded, 'Matchs', 1, true, _newMatchesCount),
                _buildCenterButton(),
                _buildNavItem(Icons.chat_bubble_rounded, 'Chats', 3, false, _unreadMessagesCount),
                _buildNavItem(Icons.person_rounded, 'Profile', 4, false, 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isPuzzle, int badgeCount) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);

        // Mark home as viewed when user taps on home tab
        if (index == 0) {
          _markHomeAsViewed();
        } else {
          // Refresh counts when switching to other tabs
          _loadNotificationCounts();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Special styling for puzzle icon
                if (isPuzzle)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                        colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                      )
                          : null,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? Colors.white : Colors.grey.shade400,
                      size: 24,
                    ),
                  )
                else
                  Icon(
                    icon,
                    color: isSelected ? const Color(0xFF8A1FFF) : Colors.grey.shade400,
                    size: 26,
                  ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF8A1FFF) : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            // Badge
            if (badgeCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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

  Widget _buildCenterButton() {
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = 2),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8A1FFF).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}