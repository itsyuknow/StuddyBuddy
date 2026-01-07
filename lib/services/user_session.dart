import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class UserSession {
  static final supabase = Supabase.instance.client;
  static String? userId;
  static Map<String, dynamic>? userData;
  static bool hasCompletedOnboarding = false;

  /// Save user session to local storage
  /// Supabase automatically handles auth tokens, we just cache user data
  static Future<void> setUser(String id, Map<String, dynamic> data) async {
    userId = id;
    userData = data;
    hasCompletedOnboarding = true;

    // Save to SharedPreferences for quick access
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', id);
    await prefs.setString('userData', jsonEncode(data));
    await prefs.setBool('hasCompletedOnboarding', true);
  }

  /// Load user session from Supabase Auth + local storage
  /// This checks if the Supabase session is still valid
  static Future<bool> loadSession() async {
    try {
      // First, check if Supabase has an active session
      final session = supabase.auth.currentSession;

      if (session == null) {
        // No active Supabase session, clear local data
        await clearUser();
        return false;
      }

      // Supabase session exists, get user ID
      final authUserId = session.user.id;

      // Try to load cached user data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedUserId = prefs.getString('userId');
      final userDataString = prefs.getString('userData');
      hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;

      // If cached data matches current auth user, use it
      if (cachedUserId == authUserId && userDataString != null) {
        userId = authUserId;
        userData = jsonDecode(userDataString);
        return true;
      }

      // If cache is outdated or missing, fetch fresh data from database
      final freshUserData = await supabase
          .from('users')
          .select()
          .eq('id', authUserId)
          .single();

      // Save fresh data
      await setUser(authUserId, freshUserData);
      return true;

    } catch (e) {
      // If anything fails, clear session
      await clearUser();
      return false;
    }
  }

  /// Check if user is logged in with valid Supabase session
  static Future<bool> checkLogin() async {
    // Check if Supabase has an active session
    final session = supabase.auth.currentSession;

    if (session == null) {
      await clearUser();
      return false;
    }

    // If we have a session but no cached data, load it
    if (userId == null || userData == null) {
      return await loadSession();
    }

    // Verify cached userId matches current session
    if (userId != session.user.id) {
      return await loadSession();
    }

    return true;
  }

  /// Refresh user data from database
  static Future<void> refreshUserData() async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) {
        await clearUser();
        return;
      }

      final freshUserData = await supabase
          .from('users')
          .select()
          .eq('id', session.user.id)
          .single();

      await setUser(session.user.id, freshUserData);
    } catch (e) {
      print('Error refreshing user data: $e');
    }
  }

  /// Update specific user data field
  static Future<bool> updateUserField(String field, dynamic value) async {
    try {
      if (userId == null) return false;

      // Update in database
      await supabase
          .from('users')
          .update({field: value})
          .eq('id', userId!);

      // Update local cache
      if (userData != null) {
        userData![field] = value;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', jsonEncode(userData));
      }

      return true;
    } catch (e) {
      print('Error updating user field: $e');
      return false;
    }
  }

  /// Clear user session and sign out from Supabase
  static Future<void> clearUser() async {
    try {
      // Sign out from Supabase Auth
      await supabase.auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }

    // Clear local data
    userId = null;
    userData = null;
    hasCompletedOnboarding = false;

    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('userData');
    await prefs.remove('hasCompletedOnboarding');
  }

  /// Get current user email
  static String? getUserEmail() {
    return supabase.auth.currentUser?.email ?? userData?['email'];
  }

  /// Check if session is still valid (not expired)
  static bool isSessionValid() {
    final session = supabase.auth.currentSession;
    if (session == null) return false;

    // Supabase automatically refreshes tokens, so if session exists, it's valid
    return true;
  }

  /// Listen to auth state changes
  static void setupAuthListener(Function(AuthChangeEvent, Session?) callback) {
    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedOut) {
        clearUser();
      } else if (event == AuthChangeEvent.signedIn && session != null) {
        // Optionally reload user data when signed in
        loadSession();
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        // Token was refreshed, session is still valid
        print('Session token refreshed');
      }

      callback(event, session);
    });
  }
}