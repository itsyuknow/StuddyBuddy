import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_picker_service.dart';
import 'user_session.dart';
import 'dart:typed_data';


class ChallengeService {
  static final _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>> createChallenge({
    required String title,
    required String description,
    required String examId,
    required String subject,
    required String difficulty,
    required int durationDays,
    int? targetScore,
    dynamic imageFile, // Changed from File?
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final userId = currentUser.id;
      String? imageUrl;

      // Upload image if provided
      if (imageFile != null) {
        try {
          final fileName = ImagePickerService.getFileName(imageFile, userId);
          final filePath = 'challenges/$userId/$fileName';
          final bytes = await ImagePickerService.getImageBytes(imageFile);

          if (bytes != null) {
            // ✅ FIX: convert List<int> → Uint8List
            final Uint8List uint8Bytes = Uint8List.fromList(bytes);

            await _supabase.storage.from('post-images').uploadBinary(
              filePath,
              uint8Bytes,
              fileOptions: const FileOptions(upsert: true),
            );

            imageUrl =
                _supabase.storage.from('post-images').getPublicUrl(filePath);
          }
        } catch (e) {
          print('Error uploading image: $e');
        }
      }

      // Get user name
      String userName = 'Anonymous';
      if (UserSession.userData != null &&
          UserSession.userData!['full_name'] != null) {
        userName = UserSession.userData!['full_name'];
      } else {
        userName = currentUser.email?.split('@')[0] ?? 'Anonymous';
      }

      // Calculate expiry date
      final expiresAt = DateTime.now().add(Duration(days: durationDays));

      // Create challenge
      final response = await _supabase.from('challenges').insert({
        'user_id': userId,
        'user_name': userName,
        'title': title,
        'description': description,
        'exam_id': examId,
        'subject': subject,
        'difficulty': difficulty,
        'duration_days': durationDays,
        'target_score': targetScore,
        'image_url': imageUrl,
        'expires_at': expiresAt.toIso8601String(),
        'status': 'active',
      }).select().single();

      return {'success': true, 'data': response};
    } catch (e) {
      print('Error creating challenge: $e');
      return {'success': false, 'error': e.toString()};
    }
  }


  // Get all active challenges
  static Future<List<Map<String, dynamic>>> getChallenges({String? examId, String? difficulty}) async {
    try {
      print('ChallengeService.getChallenges called with examId: $examId, difficulty: $difficulty');

      var query = _supabase.from('challenges').select('*').eq('status', 'active');

      if (examId != null) {
        query = query.eq('exam_id', examId);
      }
      if (difficulty != null) {
        query = query.eq('difficulty', difficulty);
      }

      final response = await query.order('created_at', ascending: false);

      print('Raw response count: ${(response as List).length}');

      // Fetch user profiles separately for each challenge
      final challenges = <Map<String, dynamic>>[];

      for (var challenge in (response as List)) {
        // Get user profile separately
        Map<String, dynamic>? userProfile;
        try {
          userProfile = await _supabase
              .from('user_profiles')
              .select('full_name, avatar_url')
              .eq('id', challenge['user_id'])
              .maybeSingle();
        } catch (e) {
          print('Error fetching user profile for ${challenge['user_id']}: $e');
        }

        challenges.add({
          'id': challenge['id'],
          'user_id': challenge['user_id'],
          'user_name': userProfile?['full_name'] ?? challenge['user_name'] ?? 'Anonymous',
          'avatar_url': userProfile?['avatar_url'],
          'title': challenge['title'],
          'description': challenge['description'],
          'exam_id': challenge['exam_id'],
          'subject': challenge['subject'],
          'difficulty': challenge['difficulty'],
          'duration_days': challenge['duration_days'],
          'target_score': challenge['target_score'],
          'image_url': challenge['image_url'],
          'likes_count': challenge['likes_count'] ?? 0,
          'participants_count': challenge['participants_count'] ?? 0,
          'comments_count': challenge['comments_count'] ?? 0,
          'status': challenge['status'],
          'created_at': challenge['created_at'],
          'expires_at': challenge['expires_at'],
        });
      }

      print('Transformed challenges count: ${challenges.length}');
      return challenges;
    } catch (e, stackTrace) {
      print('Error fetching challenges: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Get challenge by ID
  static Future<Map<String, dynamic>?> getChallengeById(String challengeId) async {
    try {
      print('Fetching challenge with ID: $challengeId');

      final response = await _supabase
          .from('challenges')
          .select('*')
          .eq('id', challengeId)
          .maybeSingle();

      print('Raw response: $response');

      if (response == null) {
        print('No challenge found with ID: $challengeId');
        return null;
      }

      // Get user profile separately
      Map<String, dynamic>? userProfile;
      try {
        userProfile = await _supabase
            .from('user_profiles')
            .select('full_name, avatar_url')
            .eq('id', response['user_id'])
            .maybeSingle();
      } catch (e) {
        print('Error fetching user profile: $e');
      }

      final result = {
        'id': response['id'],
        'user_id': response['user_id'],
        'user_name': userProfile?['full_name'] ?? response['user_name'] ?? 'Anonymous',
        'avatar_url': userProfile?['avatar_url'],
        'title': response['title'],
        'description': response['description'],
        'exam_id': response['exam_id'],
        'subject': response['subject'],
        'difficulty': response['difficulty'],
        'duration_days': response['duration_days'],
        'target_score': response['target_score'],
        'image_url': response['image_url'],
        'likes_count': response['likes_count'] ?? 0,
        'participants_count': response['participants_count'] ?? 0,
        'comments_count': response['comments_count'] ?? 0,
        'status': response['status'],
        'created_at': response['created_at'],
        'expires_at': response['expires_at'],
      };

      print('Transformed challenge: $result');
      return result;
    } catch (e, stackTrace) {
      print('Error fetching challenge: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  // Join challenge
  static Future<bool> joinChallenge(String challengeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Check if already joined
      final existing = await _supabase
          .from('challenge_participants')
          .select()
          .eq('challenge_id', challengeId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) return true;

      String userName = 'Anonymous';
      if (UserSession.userData != null && UserSession.userData!['full_name'] != null) {
        userName = UserSession.userData!['full_name'];
      } else {
        userName = _supabase.auth.currentUser?.email?.split('@')[0] ?? 'Anonymous';
      }

      await _supabase.from('challenge_participants').insert({
        'challenge_id': challengeId,
        'user_id': userId,
        'user_name': userName,
      });

      await _supabase.rpc('increment_challenge_participants', params: {'challenge_id': challengeId});

      return true;
    } catch (e) {
      print('Error joining challenge: $e');
      return false;
    }
  }

  // Check if user joined challenge
  static Future<bool> hasUserJoinedChallenge(String challengeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('challenge_participants')
          .select()
          .eq('challenge_id', challengeId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking participation: $e');
      return false;
    }
  }

  // Get challenge participants
  static Future<List<Map<String, dynamic>>> getParticipants(String challengeId) async {
    try {
      final response = await _supabase
          .from('challenge_participants')
          .select('*')
          .eq('challenge_id', challengeId)
          .order('progress', ascending: false);

      final participants = <Map<String, dynamic>>[];

      for (var participant in (response as List)) {
        // Get user profile separately
        Map<String, dynamic>? userProfile;
        try {
          userProfile = await _supabase
              .from('user_profiles')
              .select('full_name, avatar_url')
              .eq('id', participant['user_id'])
              .maybeSingle();
        } catch (e) {
          print('Error fetching user profile: $e');
        }

        participants.add({
          'id': participant['id'],
          'user_id': participant['user_id'],
          'user_name': userProfile?['full_name'] ?? participant['user_name'] ?? 'Anonymous',
          'avatar_url': userProfile?['avatar_url'],
          'progress': participant['progress'] ?? 0,
          'completed': participant['completed'] ?? false,
          'score': participant['score'],
          'proof_image_url': participant['proof_image_url'],
          'joined_at': participant['joined_at'],
          'completed_at': participant['completed_at'],
        });
      }

      return participants;
    } catch (e) {
      print('Error getting participants: $e');
      return [];
    }
  }

  // Update progress
  static Future<bool> updateProgress(String challengeId, int progress, {File? proofImage}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      String? proofImageUrl;
      if (proofImage != null) {
        try {
          final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final filePath = 'challenge-proofs/$challengeId/$fileName';

          await _supabase.storage.from('post-images').upload(
            filePath,
            proofImage,
            fileOptions: const FileOptions(upsert: true),
          );

          proofImageUrl = _supabase.storage.from('post-images').getPublicUrl(filePath);
        } catch (e) {
          print('Error uploading proof image: $e');
        }
      }

      final updateData = {
        'progress': progress,
        if (proofImageUrl != null) 'proof_image_url': proofImageUrl,
        if (progress >= 100) ...{
          'completed': true,
          'completed_at': DateTime.now().toIso8601String(),
        },
      };

      await _supabase
          .from('challenge_participants')
          .update(updateData)
          .eq('challenge_id', challengeId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('Error updating progress: $e');
      return false;
    }
  }

  // Post update to challenge
  static Future<bool> postUpdate(String challengeId, String updateText, int progress, {File? imageFile}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      String? imageUrl;
      if (imageFile != null) {
        try {
          final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final filePath = 'challenge-updates/$challengeId/$fileName';

          await _supabase.storage.from('post-images').upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

          imageUrl = _supabase.storage.from('post-images').getPublicUrl(filePath);
        } catch (e) {
          print('Error uploading update image: $e');
        }
      }

      String userName = 'Anonymous';
      if (UserSession.userData != null && UserSession.userData!['full_name'] != null) {
        userName = UserSession.userData!['full_name'];
      } else {
        userName = _supabase.auth.currentUser?.email?.split('@')[0] ?? 'Anonymous';
      }

      await _supabase.from('challenge_updates').insert({
        'challenge_id': challengeId,
        'user_id': userId,
        'user_name': userName,
        'update_text': updateText,
        'progress': progress,
        'image_url': imageUrl,
      });

      // Also update participant progress
      await updateProgress(challengeId, progress, proofImage: imageFile);

      return true;
    } catch (e) {
      print('Error posting update: $e');
      return false;
    }
  }

  // Get challenge updates
  static Future<List<Map<String, dynamic>>> getUpdates(String challengeId) async {
    try {
      final response = await _supabase
          .from('challenge_updates')
          .select('*')
          .eq('challenge_id', challengeId)
          .order('created_at', ascending: false);

      final updates = <Map<String, dynamic>>[];

      for (var update in (response as List)) {
        // Get user profile separately
        Map<String, dynamic>? userProfile;
        try {
          userProfile = await _supabase
              .from('user_profiles')
              .select('full_name, avatar_url')
              .eq('id', update['user_id'])
              .maybeSingle();
        } catch (e) {
          print('Error fetching user profile: $e');
        }

        updates.add({
          'id': update['id'],
          'user_id': update['user_id'],
          'user_name': userProfile?['full_name'] ?? update['user_name'] ?? 'Anonymous',
          'avatar_url': userProfile?['avatar_url'],
          'update_text': update['update_text'],
          'progress': update['progress'],
          'image_url': update['image_url'],
          'created_at': update['created_at'],
        });
      }

      return updates;
    } catch (e) {
      print('Error getting updates: $e');
      return [];
    }
  }

  // Toggle like
  static Future<bool> toggleLike(String challengeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final existing = await _supabase
          .from('challenge_likes')
          .select()
          .eq('challenge_id', challengeId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('challenge_likes')
            .delete()
            .eq('challenge_id', challengeId)
            .eq('user_id', userId);
        await _supabase.rpc('decrement_challenge_likes', params: {'challenge_id': challengeId});
      } else {
        await _supabase.from('challenge_likes').insert({
          'challenge_id': challengeId,
          'user_id': userId,
        });
        await _supabase.rpc('increment_challenge_likes', params: {'challenge_id': challengeId});
      }

      return true;
    } catch (e) {
      print('Error toggling like: $e');
      return false;
    }
  }

  // Check if user liked
  static Future<bool> hasUserLiked(String challengeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('challenge_likes')
          .select()
          .eq('challenge_id', challengeId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking like: $e');
      return false;
    }
  }

  // Add comment
  static Future<bool> addComment(String challengeId, String commentText) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      String userName = 'Anonymous';
      if (UserSession.userData != null && UserSession.userData!['full_name'] != null) {
        userName = UserSession.userData!['full_name'];
      } else {
        userName = _supabase.auth.currentUser?.email?.split('@')[0] ?? 'Anonymous';
      }

      await _supabase.from('challenge_comments').insert({
        'challenge_id': challengeId,
        'user_id': userId,
        'user_name': userName,
        'comment_text': commentText,
      });

      await _supabase.rpc('increment_challenge_comments', params: {'challenge_id': challengeId});

      return true;
    } catch (e) {
      print('Error adding comment: $e');
      return false;
    }
  }

  // Get comments
  // Get comments
  static Future<List<Map<String, dynamic>>> getComments(String challengeId) async {
    try {
      final response = await _supabase
          .from('challenge_comments')
          .select('*')
          .eq('challenge_id', challengeId)
          .order('created_at', ascending: false);

      final comments = <Map<String, dynamic>>[];

      for (var comment in (response as List)) {
        // Get user profile separately
        Map<String, dynamic>? userProfile;
        try {
          userProfile = await _supabase
              .from('user_profiles')
              .select('full_name, avatar_url')
              .eq('id', comment['user_id'])
              .maybeSingle();
        } catch (e) {
          print('Error fetching user profile: $e');
        }

        comments.add({
          'id': comment['id'],
          'user_id': comment['user_id'],
          'user_name': userProfile?['full_name'] ?? comment['user_name'] ?? 'Anonymous',
          'avatar_url': userProfile?['avatar_url'],
          'comment_text': comment['comment_text'],
          'likes_count': comment['likes_count'] ?? 0,  // ADD THIS LINE
          'created_at': comment['created_at'],
        });
      }

      return comments;
    } catch (e) {
      print('Error getting comments: $e');
      return [];
    }
  }

  // Get exam subjects
  // Get exam subjects
  static Future<List<String>> getExamSubjects(String examId) async {
    try {
      final response = await _supabase
          .from('exams')
          .select('strengths')
          .eq('id', examId)
          .single();

      if (response['strengths'] == null) {
        print('No strengths found for exam $examId');
        return [];
      }

      // Parse the JSON array
      final strengths = response['strengths'] as List;

      // Extract just the subject names (not subtopics)
      final subjects = <String>[];
      for (var item in strengths) {
        if (item is Map && item.containsKey('subject')) {
          subjects.add(item['subject'].toString());
        }
      }

      print('Extracted subjects: $subjects');
      return subjects;
    } catch (e) {
      print('Error getting subjects: $e');
      return [];
    }
  }

  // Like/unlike a comment
  static Future<bool> toggleCommentLike(String commentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final existingLike = await _supabase
          .from('comment_likes')
          .select()
          .eq('comment_id', commentId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLike != null) {
        await _supabase
            .from('comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', userId);
      } else {
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

// Check if user has liked a comment
  static Future<bool> hasUserLikedComment(String commentId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('comment_likes')
          .select()
          .eq('comment_id', commentId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking comment like: $e');
      return false;
    }
  }



  static Future<bool> addReply(String commentId, String replyText) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      await Supabase.instance.client.from('challenge_comment_replies').insert({  // ✅ CORRECT TABLE
        'comment_id': commentId,
        'user_id': user.id,
        'reply_text': replyText,
      });

      return true;
    } catch (e) {
      print('Error adding reply: $e');
      return false;
    }
  }

// Get replies for a comment
  // CORRECT - Use the constraint name
  static Future<List<Map<String, dynamic>>> getReplies(String commentId) async {
    try {
      print('=== FETCHING REPLIES FOR COMMENT: $commentId ===');

      final response = await Supabase.instance.client
          .from('challenge_comment_replies')
          .select('''
          id,
          reply_text,
          created_at,
          user_id
        ''')
          .eq('comment_id', commentId)
          .order('created_at', ascending: true);

      print('Raw replies response: $response');
      print('Number of replies: ${(response as List).length}');

      final replies = <Map<String, dynamic>>[];

      for (var reply in (response as List)) {
        print('Processing reply: ${reply['id']}');

        // Get user profile separately
        Map<String, dynamic>? userProfile;
        try {
          userProfile = await Supabase.instance.client
              .from('user_profiles')
              .select('full_name, avatar_url')
              .eq('id', reply['user_id'])
              .maybeSingle();

          print('User profile for ${reply['user_id']}: $userProfile');
        } catch (e) {
          print('Error fetching user profile: $e');
        }

        replies.add({
          'id': reply['id'],
          'reply_text': reply['reply_text'],
          'created_at': reply['created_at'],
          'user_id': reply['user_id'],
          'user_name': userProfile?['full_name'] ?? 'Unknown',
          'avatar_url': userProfile?['avatar_url'],
        });
      }

      print('=== FINAL REPLIES COUNT: ${replies.length} ===');
      return replies;
    } catch (e, stackTrace) {
      print('Error fetching replies: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  // Toggle reply like
  static Future<bool> toggleReplyLike(String replyId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final existingLike = await _supabase
          .from('reply_likes')
          .select()
          .eq('reply_id', replyId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLike != null) {
        await _supabase
            .from('reply_likes')
            .delete()
            .eq('reply_id', replyId)
            .eq('user_id', userId);
        await _supabase.rpc('decrement_reply_likes', params: {'reply_id': replyId});
      } else {
        await _supabase.from('reply_likes').insert({
          'reply_id': replyId,
          'user_id': userId,
        });
        await _supabase.rpc('increment_reply_likes', params: {'reply_id': replyId});
      }

      return true;
    } catch (e) {
      print('Error toggling reply like: $e');
      return false;
    }
  }

// Check if user has liked a reply
  static Future<bool> hasUserLikedReply(String replyId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('reply_likes')
          .select()
          .eq('reply_id', replyId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking reply like: $e');
      return false;
    }
  }

// Add reply to a reply
  static Future<bool> addReplyToReply(String replyId, String replyText) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase.from('challenge_reply_replies').insert({
        'reply_id': replyId,
        'user_id': user.id,
        'reply_text': replyText,
      });

      return true;
    } catch (e) {
      print('Error adding reply to reply: $e');
      return false;
    }
  }

// Get nested replies for a reply
  static Future<List<Map<String, dynamic>>> getNestedReplies(String replyId) async {
    try {
      final response = await _supabase
          .from('challenge_reply_replies')
          .select('*')
          .eq('reply_id', replyId)
          .order('created_at', ascending: true);

      final nestedReplies = <Map<String, dynamic>>[];

      for (var reply in (response as List)) {
        Map<String, dynamic>? userProfile;
        try {
          userProfile = await _supabase
              .from('user_profiles')
              .select('full_name, avatar_url')
              .eq('id', reply['user_id'])
              .maybeSingle();
        } catch (e) {
          print('Error fetching user profile: $e');
        }

        nestedReplies.add({
          'id': reply['id'],
          'reply_text': reply['reply_text'],
          'created_at': reply['created_at'],
          'user_id': reply['user_id'],
          'user_name': userProfile?['full_name'] ?? 'Unknown',
          'avatar_url': userProfile?['avatar_url'],
        });
      }

      return nestedReplies;
    } catch (e) {
      print('Error fetching nested replies: $e');
      return [];
    }
  }

  // Delete challenge
  static Future<bool> deleteChallenge(String challengeId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Verify ownership
      final challenge = await _supabase
          .from('challenges')
          .select('user_id, image_url')
          .eq('id', challengeId)
          .single();

      if (challenge['user_id'] != userId) {
        return false; // Not the owner
      }

      // Delete image from storage if exists
      if (challenge['image_url'] != null) {
        try {
          final imageUrl = challenge['image_url'] as String;
          final filePath = imageUrl.split('/post-images/').last.split('?').first;
          await _supabase.storage.from('post-images').remove([filePath]);
        } catch (e) {
          print('Error deleting image: $e');
        }
      }

      // Delete challenge (cascading deletes should handle related data)
      await _supabase.from('challenges').delete().eq('id', challengeId);

      return true;
    } catch (e) {
      print('Error deleting challenge: $e');
      return false;
    }
  }

// Update challenge
  static Future<Map<String, dynamic>> updateChallenge({
    required String challengeId,
    required String title,
    required String description,
    required String subject,
    required String difficulty,
    int? targetScore,
    dynamic imageFile,
    bool removeImage = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Verify ownership
      final challenge = await _supabase
          .from('challenges')
          .select('user_id, image_url')
          .eq('id', challengeId)
          .single();

      if (challenge['user_id'] != userId) {
        return {'success': false, 'error': 'Not authorized'};
      }

      String? imageUrl = challenge['image_url'];

      // Handle image removal
      if (removeImage && imageUrl != null) {
        try {
          final filePath = imageUrl.split('/post-images/').last.split('?').first;
          await _supabase.storage.from('post-images').remove([filePath]);
          imageUrl = null;
        } catch (e) {
          print('Error removing image: $e');
        }
      }

      // Upload new image if provided
      if (imageFile != null) {
        try {
          // Delete old image if exists
          if (imageUrl != null) {
            final oldPath = imageUrl.split('/post-images/').last.split('?').first;
            await _supabase.storage.from('post-images').remove([oldPath]);
          }

          final fileName = ImagePickerService.getFileName(imageFile, userId);
          final filePath = 'challenges/$userId/$fileName';
          final bytes = await ImagePickerService.getImageBytes(imageFile);

          if (bytes != null) {
            final Uint8List uint8Bytes = Uint8List.fromList(bytes);
            await _supabase.storage.from('post-images').uploadBinary(
              filePath,
              uint8Bytes,
              fileOptions: const FileOptions(upsert: true),
            );
            imageUrl = _supabase.storage.from('post-images').getPublicUrl(filePath);
          }
        } catch (e) {
          print('Error uploading new image: $e');
        }
      }

      // Update challenge
      final response = await _supabase.from('challenges').update({
        'title': title,
        'description': description,
        'subject': subject,
        'difficulty': difficulty,
        'target_score': targetScore,
        'image_url': imageUrl,
      }).eq('id', challengeId).select().single();

      return {'success': true, 'data': response};
    } catch (e) {
      print('Error updating challenge: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}