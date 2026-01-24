import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

class ShareService {
  static final _supabase = Supabase.instance.client;

  // 👇 PRODUCTION URL with auto-detection
  static String get baseUrl {
    try {
      // Get current window location
      final currentUrl = html.window.location.href;
      final uri = Uri.parse(currentUrl);

      // Check if running on production domain
      if (uri.host == 'edormy.in' || uri.host.endsWith('.edormy.in')) {
        return 'https://edormy.in';
      }

      // For local development, use current origin
      return uri.origin; // e.g., http://localhost:55407
    } catch (e) {
      print('Error getting base URL: $e');
      // Fallback to production URL
      return 'https://edormy.in';
    }
  }

  // Generate shareable link for post
  static Future<String> generatePostLink(String postId) async {
    try {
      // Check if link already exists
      final existing = await _supabase
          .from('shared_links')
          .select('short_code')
          .eq('content_id', postId)
          .eq('content_type', 'post')
          .maybeSingle();

      String shortCode;

      if (existing != null) {
        shortCode = existing['short_code'];
      } else {
        // Generate unique short code
        shortCode = _generateShortCode();

        // Save to database
        await _supabase.from('shared_links').insert({
          'content_id': postId,
          'content_type': 'post',
          'short_code': shortCode,
          'user_id': _supabase.auth.currentUser?.id,
        });
      }

      return '$baseUrl/p/$shortCode';
    } catch (e) {
      print('Error generating link: $e');
      return '$baseUrl/post/$postId'; // Fallback
    }
  }

  // Generate shareable link for challenge
  static Future<String> generateChallengeLink(String challengeId) async {
    try {
      final existing = await _supabase
          .from('shared_links')
          .select('short_code')
          .eq('content_id', challengeId)
          .eq('content_type', 'challenge')
          .maybeSingle();

      String shortCode;

      if (existing != null) {
        shortCode = existing['short_code'];
      } else {
        shortCode = _generateShortCode();

        await _supabase.from('shared_links').insert({
          'content_id': challengeId,
          'content_type': 'challenge',
          'short_code': shortCode,
          'user_id': _supabase.auth.currentUser?.id,
        });
      }

      return '$baseUrl/c/$shortCode';
    } catch (e) {
      print('Error generating link: $e');
      return '$baseUrl/challenge/$challengeId';
    }
  }

  // Copy link to clipboard (WEB VERSION)
  static Future<bool> copyLinkToClipboard(String link) async {
    try {
      // For web, use both methods for better compatibility
      await Clipboard.setData(ClipboardData(text: link));

      // Also try the web Clipboard API
      try {
        await html.window.navigator.clipboard?.writeText(link);
      } catch (e) {
        print('Web clipboard API not available: $e');
      }

      return true;
    } catch (e) {
      print('Error copying to clipboard: $e');
      return false;
    }
  }

  // Web Share API (optional - for mobile browsers)
  static Future<void> shareContentWeb({
    required String link,
    String? title,
  }) async {
    try {
      // Check if Web Share API is available
      if (html.window.navigator.share != null) {
        await html.window.navigator.share({
          'title': title ?? 'Check this out!',
          'url': link,
        });
      } else {
        // Fallback: just copy to clipboard
        await copyLinkToClipboard(link);
      }
    } catch (e) {
      print('Error sharing: $e');
      // Fallback to clipboard
      await copyLinkToClipboard(link);
    }
  }

  // Generate random short code
  static String _generateShortCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(8, (index) => chars[(random + index) % chars.length]).join();
  }



  // Replace the resolveLink method in your share_service.dart with this:

  static Future<Map<String, dynamic>?> resolveLink(String shortCode) async {
    try {
      print('🔍 Resolving short code: $shortCode');

      final response = await _supabase
          .from('shared_links')
          .select('content_id, content_type, click_count')
          .eq('short_code', shortCode)
          .maybeSingle();

      if (response == null) {
        print('❌ No link found for short code: $shortCode');
        return null;
      }

      print('✅ Found link: ${response['content_type']} - ${response['content_id']}');

      // Increment click count
      try {
        final currentCount = response['click_count'] ?? 0;
        await _supabase
            .from('shared_links')
            .update({'click_count': currentCount + 1})
            .eq('short_code', shortCode);

        print('📊 Click count updated to ${currentCount + 1}');
      } catch (e) {
        print('⚠️ Failed to update click count: $e');
        // Don't fail the entire operation if click count update fails
      }

      return {
        'content_id': response['content_id'],
        'content_type': response['content_type'],
      };
    } catch (e) {
      print('❌ Error resolving link: $e');
      return null;
    }
  }

  // Generate shareable link for user profile
  static Future<String> generateUserProfileLink(String userId) async {
    try {
      final existing = await _supabase
          .from('shared_links')
          .select('short_code')
          .eq('content_id', userId)
          .eq('content_type', 'user')
          .maybeSingle();

      String shortCode;

      if (existing != null) {
        shortCode = existing['short_code'];
      } else {
        shortCode = _generateShortCode();

        await _supabase.from('shared_links').insert({
          'content_id': userId,
          'content_type': 'user',
          'short_code': shortCode,
          'user_id': _supabase.auth.currentUser?.id,
        });
      }

      return '$baseUrl/u/$shortCode';
    } catch (e) {
      print('Error generating user profile link: $e');
      return '$baseUrl/user/$userId';
    }
  }
}