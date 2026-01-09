import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_session.dart';

class PostService {
  static final _supabase = Supabase.instance.client;

  // Create a new post
  static Future<Map<String, dynamic>> createPost({
    required String title,
    required String description,
    String? challengeType,
    File? imageFile,
  }) async {
    try {
      // Check if user is authenticated
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return {
          'success': false,
          'error': 'User not authenticated. Please log in.'
        };
      }

      final userId = currentUser.id;
      String? imageUrl;

      // Upload image if provided
      if (imageFile != null) {
        try {
          final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final filePath = '$userId/$fileName';

          await _supabase.storage.from('post-images').upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

          imageUrl = _supabase.storage.from('post-images').getPublicUrl(filePath);
        } catch (e) {
          print('Error uploading image: $e');
          // Continue without image if upload fails
        }
      }

      // Get user name from UserSession or users table
      String userName = 'Anonymous';

      if (UserSession.userData != null && UserSession.userData!['full_name'] != null) {
        userName = UserSession.userData!['full_name'];
      } else {
        // Try to get from users table
        try {
          final userProfile = await _supabase
              .from('users')
              .select('full_name')
              .eq('id', userId)
              .maybeSingle();

          if (userProfile != null && userProfile['full_name'] != null) {
            userName = userProfile['full_name'];
          }
        } catch (e) {
          print('Error fetching user name: $e');
          // Use email as fallback
          userName = currentUser.email?.split('@')[0] ?? 'Anonymous';
        }
      }

      // Create post
      final response = await _supabase.from('posts').insert({
        'user_id': userId,
        'user_name': userName,
        'title': title,
        'description': description,
        'challenge_type': challengeType,
        'image_url': imageUrl,
        'likes_count': 0,
        'comments_count': 0,
      }).select().single();

      return {'success': true, 'data': response};
    } catch (e) {
      print('Error creating post: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get all posts (feed) - OPTIMIZED VERSION
  static Future<List<Map<String, dynamic>>> getPosts({String? examId, int? limit, int? offset}) async {
    try {
      // Step 1: If examId is provided, get user IDs with that exam
      List<String>? userIdsWithExam;

      if (examId != null) {
        final usersResponse = await _supabase
            .from('user_profiles')
            .select('id')
            .eq('exam_id', examId);

        userIdsWithExam = (usersResponse as List)
            .map((user) => user['id'] as String)
            .toList();

        print('Users with exam $examId: ${userIdsWithExam.length}');

        if (userIdsWithExam.isEmpty) {
          return []; // No users with this exam
        }
      }

      // Step 2: Build query for posts (without join since there's no FK)
      PostgrestFilterBuilder query = _supabase.from('posts').select('*');

      // Filter by user IDs if we have them
      if (userIdsWithExam != null && userIdsWithExam.isNotEmpty) {
        query = query.inFilter('user_id', userIdsWithExam);
      }

      // Apply ordering
      PostgrestTransformBuilder transformQuery = query.order('created_at', ascending: false);

      // Add pagination
      if (limit != null) {
        if (offset != null && offset > 0) {
          transformQuery = transformQuery.range(offset, offset + limit - 1);
        } else {
          transformQuery = transformQuery.limit(limit);
        }
      }

      final postsResponse = await transformQuery;
      print('Posts fetched: ${(postsResponse as List).length}');

      // Step 3: Get user profiles for these posts
      final posts = <Map<String, dynamic>>[];

      for (var post in (postsResponse as List)) {
        String userName = post['user_name'] ?? 'Anonymous';
        String? avatarUrl;

        // Get user profile
        try {
          final profileResponse = await _supabase
              .from('user_profiles')
              .select('full_name, avatar_url')
              .eq('id', post['user_id'])
              .maybeSingle();

          if (profileResponse != null) {
            userName = profileResponse['full_name'] ?? userName;
            avatarUrl = profileResponse['avatar_url'];
          }
        } catch (e) {
          print('Error fetching profile for ${post['user_id']}: $e');
        }

        posts.add({
          'id': post['id'],
          'user_id': post['user_id'],
          'user_name': userName,
          'avatar_url': avatarUrl,
          'title': post['title'],
          'description': post['description'],
          'challenge_type': post['challenge_type'],
          'image_url': post['image_url'],
          'likes_count': post['likes_count'] ?? 0,
          'comments_count': post['comments_count'] ?? 0,
          'created_at': post['created_at'],
        });
      }

      return posts;
    } catch (e) {
      print('Error fetching posts: $e');
      return [];
    }
  }

  // Get single post by ID
  static Future<Map<String, dynamic>?> getPostById(String postId) async {
    try {
      try {
        final response = await _supabase
            .from('posts')
            .select('''
            *,
            user_profiles (
              full_name,
              avatar_url
            )
          ''')
            .eq('id', postId)
            .maybeSingle();

        if (response == null) return null;

        final userProfile = response['user_profiles'];

        return {
          'id': response['id'],
          'user_id': response['user_id'],
          'user_name': userProfile?['full_name'] ?? response['user_name'] ?? 'Anonymous',
          'avatar_url': userProfile?['avatar_url'],
          'title': response['title'],
          'description': response['description'],
          'challenge_type': response['challenge_type'],
          'image_url': response['image_url'],
          'likes_count': response['likes_count'] ?? 0,
          'comments_count': response['comments_count'] ?? 0,
          'created_at': response['created_at'],
        };
      } catch (joinError) {
        print('Join query failed: $joinError');

        final response = await _supabase
            .from('posts')
            .select()
            .eq('id', postId)
            .maybeSingle();

        if (response == null) return null;

        String userName = response['user_name'] ?? 'Anonymous';
        String? avatarUrl;

        try {
          final profileResponse = await _supabase
              .from('user_profiles')
              .select('full_name, avatar_url')
              .eq('id', response['user_id'])
              .maybeSingle();

          if (profileResponse != null) {
            userName = profileResponse['full_name'] ?? userName;
            avatarUrl = profileResponse['avatar_url'];
          }
        } catch (e) {
          print('Error fetching profile: $e');
        }

        return {
          'id': response['id'],
          'user_id': response['user_id'],
          'user_name': userName,
          'avatar_url': avatarUrl,
          'title': response['title'],
          'description': response['description'],
          'challenge_type': response['challenge_type'],
          'image_url': response['image_url'],
          'likes_count': response['likes_count'] ?? 0,
          'comments_count': response['comments_count'] ?? 0,
          'created_at': response['created_at'],
        };
      }
    } catch (e) {
      print('Error fetching post: $e');
      return null;
    }
  }

  // Like a post
  static Future<bool> toggleLike(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Check if already liked
      final existingLike = await _supabase
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLike != null) {
        // Unlike
        await _supabase
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);

        // Decrease count
        await _supabase.rpc('decrement_likes', params: {'post_id': postId});
      } else {
        // Like
        await _supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': userId,
        });

        // Increase count
        await _supabase.rpc('increment_likes', params: {'post_id': postId});
      }

      return true;
    } catch (e) {
      print('Error toggling like: $e');
      return false;
    }
  }

  // Check if user liked a post
  static Future<bool> hasUserLiked(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking like status: $e');
      return false;
    }
  }

  // Get comments for a post
  static Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      // Get comments
      final commentsResponse = await _supabase
          .from('post_comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: false);

      final comments = <Map<String, dynamic>>[];

      for (var comment in commentsResponse as List) {
        final commentId = comment['id'];

        // Get user info
        String userName = comment['user_name'] ?? 'Anonymous';
        String? avatarUrl;

        try {
          final userProfile = await _supabase
              .from('user_profiles')
              .select('full_name, avatar_url')
              .eq('id', comment['user_id'])
              .maybeSingle();

          if (userProfile != null) {
            userName = userProfile['full_name'] ?? userName;
            avatarUrl = userProfile['avatar_url'];
          }
        } catch (e) {
          print('Could not fetch user profile for comment: $e');
        }

        // Get likes count
        final likesResponse = await _supabase
            .from('comment_likes')
            .select()
            .eq('comment_id', commentId);
        final likesCount = (likesResponse as List).length;

        // Get replies count
        final repliesResponse = await _supabase
            .from('comment_replies')
            .select()
            .eq('comment_id', commentId);
        final repliesCount = (repliesResponse as List).length;

        comments.add({
          'id': comment['id'],
          'post_id': comment['post_id'],
          'user_id': comment['user_id'],
          'user_name': userName,
          'avatar_url': avatarUrl,
          'comment_text': comment['comment_text'],
          'created_at': comment['created_at'],
          'likes_count': likesCount,
          'replies_count': repliesCount,
        });
      }

      return comments;
    } catch (e) {
      print('Error getting comments: $e');
      return [];
    }
  }

  // Add comment
  static Future<bool> addComment(String postId, String commentText) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Get user name
      String userName = 'Anonymous';
      if (UserSession.userData != null && UserSession.userData!['full_name'] != null) {
        userName = UserSession.userData!['full_name'];
      } else {
        // Fallback to email
        final currentUser = _supabase.auth.currentUser;
        userName = currentUser?.email?.split('@')[0] ?? 'Anonymous';
      }

      // Insert into post_comments table
      await _supabase.from('post_comments').insert({
        'post_id': postId,
        'user_id': userId,
        'user_name': userName,
        'comment_text': commentText,
      });

      // Increase comment count
      try {
        await _supabase.rpc('increment_comments', params: {'post_id': postId});
      } catch (e) {
        print('RPC increment_comments not found, updating manually: $e');
        // Manual increment if RPC doesn't exist
        final post = await _supabase
            .from('posts')
            .select('comments_count')
            .eq('id', postId)
            .single();

        await _supabase
            .from('posts')
            .update({'comments_count': (post['comments_count'] ?? 0) + 1})
            .eq('id', postId);
      }

      return true;
    } catch (e) {
      print('Error adding comment: $e');
      return false;
    }
  }

  // Add reply to a comment
  static Future<bool> addReply(String commentId, String replyText) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase.from('comment_replies').insert({
        'comment_id': commentId,
        'user_id': userId,
        'reply_text': replyText,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error adding reply: $e');
      return false;
    }
  }

  // Get replies for a comment
  static Future<List<Map<String, dynamic>>> getReplies(String commentId) async {
    try {
      // Get replies
      final repliesResponse = await _supabase
          .from('comment_replies')
          .select()
          .eq('comment_id', commentId)
          .order('created_at', ascending: true);

      final replies = <Map<String, dynamic>>[];

      for (var reply in repliesResponse as List) {
        // Get user info for each reply
        String userName = 'Anonymous';
        String? avatarUrl;

        try {
          final userProfile = await _supabase
              .from('user_profiles')
              .select('full_name, avatar_url')
              .eq('id', reply['user_id'])
              .maybeSingle();

          if (userProfile != null) {
            userName = userProfile['full_name'] ?? 'Anonymous';
            avatarUrl = userProfile['avatar_url'];
          }
        } catch (e) {
          print('Could not fetch user profile for reply: $e');
        }

        replies.add({
          'id': reply['id'],
          'comment_id': reply['comment_id'],
          'user_id': reply['user_id'],
          'user_name': userName,
          'avatar_url': avatarUrl,
          'reply_text': reply['reply_text'],
          'created_at': reply['created_at'],
          'likes_count': reply['likes_count'] ?? 0,
        });
      }

      return replies;
    } catch (e) {
      print('Error getting replies: $e');
      return [];
    }
  }

  // Toggle comment like
  static Future<bool> toggleCommentLike(String commentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final existing = await _supabase
          .from('comment_likes')
          .select()
          .eq('comment_id', commentId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Remove like
        await _supabase
            .from('comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', userId);
      } else {
        // Add like
        await _supabase.from('comment_likes').insert({
          'comment_id': commentId,
          'user_id': userId,
        });
      }

      return true;
    } catch (e) {
      print('Error toggling comment like: $e');
      return false;
    }
  }

  // Check if user liked a comment
  static Future<bool> hasUserLikedComment(String commentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final result = await _supabase
          .from('comment_likes')
          .select()
          .eq('comment_id', commentId)
          .eq('user_id', userId)
          .maybeSingle();

      return result != null;
    } catch (e) {
      print('Error checking comment like: $e');
      return false;
    }
  }

  // Accept challenge
  static Future<bool> acceptChallenge(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Check if already accepted
      final existing = await _supabase
          .from('challenge_acceptances')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        return true; // Already accepted
      }

      // Get user name
      String userName = 'Anonymous';
      if (UserSession.userData != null && UserSession.userData!['full_name'] != null) {
        userName = UserSession.userData!['full_name'];
      } else {
        final currentUser = _supabase.auth.currentUser;
        userName = currentUser?.email?.split('@')[0] ?? 'Anonymous';
      }

      await _supabase.from('challenge_acceptances').insert({
        'post_id': postId,
        'user_id': userId,
        'user_name': userName,
      });

      return true;
    } catch (e) {
      print('Error accepting challenge: $e');
      return false;
    }
  }

  // Check if user accepted challenge
  static Future<bool> hasUserAcceptedChallenge(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('challenge_acceptances')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking challenge acceptance: $e');
      return false;
    }
  }

  // Get challenge acceptances count
  static Future<int> getChallengeAcceptancesCount(String postId) async {
    try {
      final response = await _supabase
          .from('challenge_acceptances')
          .select()
          .eq('post_id', postId);

      return (response as List).length;
    } catch (e) {
      print('Error getting acceptances count: $e');
      return 0;
    }
  }
}