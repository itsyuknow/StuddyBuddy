import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_session.dart';

class ChallengeService {
  static final _supabase = Supabase.instance.client;

  // Create a new challenge
  static Future<Map<String, dynamic>> createChallenge({
    required String title,
    required String description,
    required String examId,
    required String subject,
    required String difficulty,
    required int durationDays,
    int? targetScore,
    File? imageFile,
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
          final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final filePath = 'challenges/$userId/$fileName';

          await _supabase.storage.from('post-images').upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

          imageUrl = _supabase.storage.from('post-images').getPublicUrl(filePath);
        } catch (e) {
          print('Error uploading image: $e');
        }
      }

      // Get user name
      String userName = 'Anonymous';
      if (UserSession.userData != null && UserSession.userData!['full_name'] != null) {
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
      var query = _supabase.from('challenges').select('''
            *,
            user_profiles (
              full_name,
              avatar_url
            )
          ''').eq('status', 'active');

      if (examId != null) {
        query = query.eq('exam_id', examId);
      }
      if (difficulty != null) {
        query = query.eq('difficulty', difficulty);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List).map((challenge) {
        final userProfile = challenge['user_profiles'];
        return {
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
        };
      }).toList();
    } catch (e) {
      print('Error fetching challenges: $e');
      return [];
    }
  }

  // Get challenge by ID
  static Future<Map<String, dynamic>?> getChallengeById(String challengeId) async {
    try {
      final response = await _supabase
          .from('challenges')
          .select('''
            *,
            user_profiles (
              full_name,
              avatar_url
            )
          ''')
          .eq('id', challengeId)
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
    } catch (e) {
      print('Error fetching challenge: $e');
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
          .select('''
            *,
            user_profiles (
              full_name,
              avatar_url
            )
          ''')
          .eq('challenge_id', challengeId)
          .order('progress', ascending: false);

      return (response as List).map((participant) {
        final userProfile = participant['user_profiles'];
        return {
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
        };
      }).toList();
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
          .select('''
            *,
            user_profiles (
              full_name,
              avatar_url
            )
          ''')
          .eq('challenge_id', challengeId)
          .order('created_at', ascending: false);

      return (response as List).map((update) {
        final userProfile = update['user_profiles'];
        return {
          'id': update['id'],
          'user_id': update['user_id'],
          'user_name': userProfile?['full_name'] ?? update['user_name'] ?? 'Anonymous',
          'avatar_url': userProfile?['avatar_url'],
          'update_text': update['update_text'],
          'progress': update['progress'],
          'image_url': update['image_url'],
          'created_at': update['created_at'],
        };
      }).toList();
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
  static Future<List<Map<String, dynamic>>> getComments(String challengeId) async {
    try {
      final response = await _supabase
          .from('challenge_comments')
          .select('''
            *,
            user_profiles (
              full_name,
              avatar_url
            )
          ''')
          .eq('challenge_id', challengeId)
          .order('created_at', ascending: false);

      return (response as List).map((comment) {
        final userProfile = comment['user_profiles'];
        return {
          'id': comment['id'],
          'user_id': comment['user_id'],
          'user_name': userProfile?['full_name'] ?? comment['user_name'] ?? 'Anonymous',
          'avatar_url': userProfile?['avatar_url'],
          'comment_text': comment['comment_text'],
          'created_at': comment['created_at'],
        };
      }).toList();
    } catch (e) {
      print('Error getting comments: $e');
      return [];
    }
  }

  // Get exam subjects
  static Future<List<String>> getExamSubjects(String examId) async {
    try {
      final response = await _supabase
          .from('exams')
          .select('strengths')
          .eq('id', examId)
          .single();

      final strengths = response['strengths'] as List;
      return strengths.map((s) => s.toString()).toList();
    } catch (e) {
      print('Error getting subjects: $e');
      return [];
    }
  }
}