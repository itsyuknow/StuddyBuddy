import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  static final _supabase = Supabase.instance.client;

  // Get or create a conversation between two users
  static Future<String> getOrCreateConversation(String otherUserId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Not authenticated');

      final response = await _supabase.rpc(
        'get_or_create_conversation',
        params: {
          'user1_id': currentUserId,
          'user2_id': otherUserId,
        },
      );

      return response as String;
    } catch (e) {
      print('Error getting/creating conversation: $e');
      rethrow;
    }
  }

  // Get all conversations for current user with proper joins
  static Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return [];

      // Get conversations
      final convResponse = await _supabase
          .from('conversations')
          .select('*')
          .or('participant1_id.eq.$currentUserId,participant2_id.eq.$currentUserId')
          .order('updated_at', ascending: false);

      final conversations = <Map<String, dynamic>>[];

      for (var conv in convResponse) {
        // Get the other user's ID
        final otherUserId = conv['participant1_id'] == currentUserId
            ? conv['participant2_id']
            : conv['participant1_id'];

        // Fetch other user's details
        try {
          final userData = await _supabase
              .from('users')
              .select('id, full_name, username, avatar_url')
              .eq('id', otherUserId)
              .single();

          // Get unread count for this conversation
          final unreadResponse = await _supabase
              .from('messages')
              .select('id')
              .eq('conversation_id', conv['id'])
              .eq('receiver_id', currentUserId)
              .eq('is_read', false);

          final unreadCount = (unreadResponse as List).length;

          conversations.add({
            'id': conv['id'],
            'last_message': conv['last_message'],
            'last_message_time': conv['last_message_time'],
            'updated_at': conv['updated_at'],
            'unread_count': unreadCount,
            'other_user': userData,
          });
        } catch (e) {
          print('Error fetching user $otherUserId: $e');
        }
      }

      return conversations;
    } catch (e) {
      print('Error getting conversations: $e');
      return [];
    }
  }

  // Send a message
  static Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String receiverId,
    required String content,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Not authenticated');

      final response = await _supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'receiver_id': receiverId,
        'content': content,
      }).select().single();

      return response;
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Get messages for a conversation
  static Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      final messages = <Map<String, dynamic>>[];

      for (var message in response) {
        try {
          final sender = await _supabase
              .from('users')
              .select('id, full_name, avatar_url')
              .eq('id', message['sender_id'])
              .single();

          messages.add({
            ...message,
            'sender': sender,
          });
        } catch (e) {
          print('Error fetching sender: $e');
          messages.add({
            ...message,
            'sender': {
              'id': message['sender_id'],
              'full_name': 'User',
              'avatar_url': null,
            },
          });
        }
      }

      return messages;
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }

  // Mark messages as read
  static Future<void> markMessagesAsRead(String conversationId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .eq('receiver_id', currentUserId)
          .eq('is_read', false);
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Get unread message count
  static Future<int> getUnreadCount() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return 0;

      final response = await _supabase
          .from('messages')
          .select('id')
          .eq('receiver_id', currentUserId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Delete a conversation
  static Future<void> deleteConversation(String conversationId) async {
    try {
      await _supabase
          .from('conversations')
          .delete()
          .eq('id', conversationId);
    } catch (e) {
      print('Error deleting conversation: $e');
      rethrow;
    }
  }
}