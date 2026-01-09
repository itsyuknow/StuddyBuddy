import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/match_animation_screen.dart';
import '../services/user_session.dart';
import '../screens/user_profile_screen.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _buddyUsers = [];
  List<Map<String, dynamic>> _otherUsers = [];
  bool _isSearching = false;
  bool _isLoading = true;
  bool _isSearchFocused = false;
  String _selectedTab = 'buddy';// 'buddy' or 'others'


  Map<String, bool> _followStatus = {}; // ADD THIS LINE



  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSuggestedUsers();
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestedUsers() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      if (currentUserId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get current user's full profile
      final currentUserData = await _supabase
          .from('users')
          .select('exam_id, strengths, weaknesses')
          .eq('id', currentUserId)
          .single();

      if (currentUserData == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get all users with same exam
      final response = await _supabase
          .from('users')
          .select('id, full_name, username, bio, avatar_url, is_verified, exam_id, strengths, weaknesses')
          .eq('exam_id', currentUserData['exam_id'])
          .neq('id', currentUserId);

      // Calculate match scores for each user
      final List<Map<String, dynamic>> usersWithScores = [];

      for (var user in response as List) {
        final matchScore = _calculateMatchScore(
          currentUserData,
          user,
        );

        user['match_score'] = matchScore;
        usersWithScores.add(Map<String, dynamic>.from(user));
      }

      // Sort by match score (highest first)
      usersWithScores.sort((a, b) =>
          (b['match_score'] as int).compareTo(a['match_score'] as int)
      );

      // Separate buddy users (50%+) and others
      final buddyList = usersWithScores.where((user) => user['match_score'] >= 50).toList();
      final othersList = usersWithScores.where((user) => user['match_score'] < 50).toList();

      print('Found ${buddyList.length} buddy users (50%+ match)');
      print('Found ${othersList.length} other users');

      // Check follow status for all users
      for (var user in buddyList) {
        _checkFollowStatus(user['id']);
      }
      for (var user in othersList) {
        _checkFollowStatus(user['id']);
      }

      setState(() {
        _buddyUsers = buddyList;
        _otherUsers = othersList;
        _isLoading = false;
      });

    } catch (e) { // ADD THIS CATCH BLOCK
      print('Error loading suggested users: $e');
      setState(() => _isLoading = false);
    }
  }

  int _calculateMatchScore(
      Map<String, dynamic> currentUser,
      Map<String, dynamic> otherUser,
      ) {
    int totalPoints = 0;
    int maxPoints = 0;

    // Get lists safely
    final myStrengths = List<String>.from(currentUser['strengths'] ?? []);
    final myWeaknesses = List<String>.from(currentUser['weaknesses'] ?? []);

    final theirStrengths = List<String>.from(otherUser['strengths'] ?? []);
    final theirWeaknesses = List<String>.from(otherUser['weaknesses'] ?? []);

    // My weaknesses match their strengths = they can help me (50% weight)
    if (myWeaknesses.isNotEmpty && theirStrengths.isNotEmpty) {
      maxPoints += 50;
      final helpMeCount = myWeaknesses.where(
              (weakness) => theirStrengths.contains(weakness)
      ).length;
      totalPoints += ((helpMeCount / myWeaknesses.length) * 50).round();
    }

    // My strengths match their weaknesses = I can help them (50% weight)
    if (myStrengths.isNotEmpty && theirWeaknesses.isNotEmpty) {
      maxPoints += 50;
      final helpThemCount = myStrengths.where(
              (strength) => theirWeaknesses.contains(strength)
      ).length;
      totalPoints += ((helpThemCount / myStrengths.length) * 50).round();
    }

    // Calculate final percentage
    if (maxPoints == 0) return 0;
    return ((totalPoints / maxPoints) * 100).round();
  }

  Future<void> _toggleFollow(String userId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final isFollowing = _followStatus[userId] ?? false;

      if (isFollowing) {
        await _supabase
            .from('follows')
            .delete()
            .eq('follower_id', currentUserId)
            .eq('following_id', userId);
      } else {
        await _supabase.from('follows').insert({
          'follower_id': currentUserId,
          'following_id': userId,
        });
      }

      setState(() {
        _followStatus[userId] = !isFollowing;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _checkFollowStatus(String userId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final response = await _supabase
          .from('follows')
          .select()
          .eq('follower_id', currentUserId)
          .eq('following_id', userId);

      setState(() {
        _followStatus[userId] = response.isNotEmpty;
      });
    } catch (e) {
      print('Error checking follow status: $e');
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      // Search in user_profiles table
      final response = await _supabase
          .from('user_profiles')
          .select('id, full_name, username, bio, avatar_url, is_verified')
          .neq('id', currentUserId!)
          .or('full_name.ilike.%$query%,username.ilike.%$query%')
          .limit(30);

      print('Search results: ${response.length}');

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error searching users: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _navigateToProfile(String userId, {Map<String, dynamic>? userData}) async {
    // Show match animation if match score is 85% or higher
    if (userData != null && userData['match_score'] != null && userData['match_score'] >= 85) {
      // Get current user data
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId != null) {
        try {
          final currentUserData = await _supabase
              .from('users')
              .select('id, full_name, avatar_url')
              .eq('id', currentUserId)
              .single();

          if (!mounted) return;

          // Show match animation
          await Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
                opacity: animation,
                child: MatchAnimationScreen(
                  currentUser: currentUserData,
                  matchedUser: userData,
                  matchPercentage: userData['match_score'],
                ),
              ),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        } catch (e) {
          print('Error loading current user data: $e');
        }
      }
    }

    // Navigate to profile
    // Navigate to profile
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
      ),
    ).then((_) {
      // Refresh follow status when returning
      _checkFollowStatus(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFF8A1FFF), // Match gradient top color
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: _buildSearchHeader(),
            ),
          ),
          if (_searchController.text.isEmpty) _buildTabButtons(),
          Expanded(
            child: Container(
              color: const Color(0xFFFAFAFA),
              child: _searchController.text.isEmpty
                  ? _buildSuggestedSection()
                  : _buildSearchResults(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white24, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: _isSearchFocused
                  ? Border.all(color: Colors.white, width: 2)
                  : Border.all(color: Colors.white.withOpacity(0.3), width: 1),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _searchUsers,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withOpacity(0.9),
                  size: 22,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Color(0xFF8A1FFF),
                      size: 16,
                    ),
                  ),
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButtons() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 'buddy'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: _selectedTab == 'buddy'
                      ? LinearGradient(
                    colors: [const Color(0xFF8A1FFF), const Color(0xFFC43AFF)],
                  )
                      : null,
                  color: _selectedTab == 'buddy' ? null : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'My Match',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _selectedTab == 'buddy' ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 'others'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: _selectedTab == 'others'
                      ? LinearGradient(
                    colors: [const Color(0xFF8A1FFF), const Color(0xFFC43AFF)],
                  )
                      : null,
                  color: _selectedTab == 'others' ? null : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'My Mates',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _selectedTab == 'others' ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedSection() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [const Color(0xFF8A1FFF), const Color(0xFFC43AFF)],
                ),
              ),
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Finding connections...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedTab == 'buddy') {
      return _buildBuddyList();
    } else {
      return _buildOthersList();
    }
  }

  Widget _buildBuddyList() {
    if (_buddyUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No buddy matches found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your profile to find matches',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSuggestedUsers,
      color: const Color(0xFF8A1FFF),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _buddyUsers.length,
        itemBuilder: (context, index) {
          final user = _buddyUsers[index];
          return _buildUserTile(user, showFollowButton: true);
        },
      ),
    );
  }

  Widget _buildOthersList() {
    if (_otherUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No suggestions yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSuggestedUsers,
      color: const Color(0xFF8A1FFF),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: _otherUsers.length,
        itemBuilder: (context, index) {
          final user = _otherUsers[index];
          return _buildSquareProfileCard(user);
        },
      ),
    );
  }

  Widget _buildSquareProfileCard(Map<String, dynamic> user) {
    final fullName = user['full_name'] ?? 'User';
    final username = user['username'];
    final avatarUrl = user['avatar_url'];
    final isVerified = user['is_verified'] == true;

    return GestureDetector(
      onTap: () => _navigateToProfile(user['id'], userData: user),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  const Color(0xFF8A1FFF),
                  const Color(0xFFC43AFF),
                ],
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
              ),
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _buildSquareAvatar(avatarUrl, fullName),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  username ?? fullName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 2),
                const Icon(
                  Icons.verified,
                  color: Color(0xFF8A1FFF),
                  size: 12,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSquareAvatar(String? avatarUrl, String userName) {
    if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl != 'null') {
      return Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildSquareAvatarFallback(userName);
        },
      );
    }
    return _buildSquareAvatarFallback(userName);
  }

  Widget _buildSquareAvatarFallback(String userName) {
    final letter = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF8A1FFF), const Color(0xFFC43AFF)],
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return Center(
        child: Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [const Color(0xFF8A1FFF), const Color(0xFFC43AFF)],
            ),
          ),
          child: const CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching for something else',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserTile(user, showFollowButton: false);
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, {required bool showFollowButton}) {
    final fullName = user['full_name'] ?? 'User';
    final username = user['username'];
    final bio = user['bio'];
    final avatarUrl = user['avatar_url'];
    final isVerified = user['is_verified'] == true;
    final matchScore = user['match_score'] as int?;

    return InkWell(
      onTap: () => _navigateToProfile(user['id'], userData: user),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar with gradient border
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    const Color(0xFF8A1FFF),
                    const Color(0xFFC43AFF),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: _buildAvatar(avatarUrl, fullName, 56),
              ),
            ),
            const SizedBox(width: 12),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          username ?? fullName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: Color(0xFF8A1FFF),
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fullName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (matchScore != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: matchScore >= 90
                                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                  : matchScore >= 75
                                  ? [const Color(0xFF0EA5E9), const Color(0xFF0284C7)]
                                  : matchScore >= 50
                                  ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                                  : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.stars_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$matchScore% Match',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else if (bio != null && bio.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      bio,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Action button - SIMPLIFIED VERSION
            if (showFollowButton)
              GestureDetector(
                onTap: () => _toggleFollow(user['id']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: (_followStatus[user['id']] ?? false)
                        ? null
                        : const LinearGradient(
                      colors: [Color(0xFF8A1FFF), Color(0xFFC43AFF)],
                    ),
                    color: (_followStatus[user['id']] ?? false)
                        ? Colors.grey.shade200
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (_followStatus[user['id']] ?? false) ? 'Following' : 'Follow',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: (_followStatus[user['id']] ?? false)
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.black54,
                ),
              ),
          ],
        ),
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
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size,
              height: size,
              color: Colors.grey.shade200,
              child: Center(
                child: SizedBox(
                  width: size * 0.3,
                  height: size * 0.3,
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildAvatarFallback(userName, size);
          },
        ),
      );
    }
    return _buildAvatarFallback(userName, size);
  }

  Widget _buildAvatarFallback(String userName, double size) {
    final letter = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF8A1FFF), const Color(0xFFC43AFF)],
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}