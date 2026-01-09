import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../tabs/home_tab.dart';
import '../tabs/search_tab.dart';
import '../tabs/create_post_tab.dart';
import '../tabs/chat_tab.dart';
import '../tabs/profile_tab.dart';
import '../services/chat_service.dart';

class MainAppScreen extends StatefulWidget {
  final int initialTabIndex;

  const MainAppScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  final _supabase = Supabase.instance.client;
  late int _selectedIndex;

  int _unreadMessagesCount = 0;
  int _newPostsCount = 0;
  int _newMatchesCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _loadNotificationCounts();

    // Refresh counts every 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) _loadNotificationCounts();
    });
  }

  Future<void> _loadNotificationCounts() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Get unread messages count
      final unreadCount = await ChatService.getUnreadCount();

      // Get new posts count (posts created in last 24 hours)
      final userProfile = await _supabase
          .from('users')
          .select('exam_id')
          .eq('id', currentUserId)
          .maybeSingle();

      int newPosts = 0;
      if (userProfile != null) {
        final yesterday = DateTime.now().subtract(const Duration(hours: 24));

        // Count posts from last 24 hours
        final postsResponse = await _supabase
            .from('posts')
            .select('id')
            .gte('created_at', yesterday.toIso8601String());

        newPosts = (postsResponse as List).length;
      }

      // Get new matches count (users with 85%+ match that are new)
      int newMatches = 0;
      // You can implement match counting logic here if needed

      if (mounted) {
        setState(() {
          _unreadMessagesCount = unreadCount;
          _newPostsCount = newPosts;
          _newMatchesCount = newMatches;
        });
      }
    } catch (e) {
      print('Error loading notification counts: $e');
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
        // Refresh counts when switching tabs
        _loadNotificationCounts();
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