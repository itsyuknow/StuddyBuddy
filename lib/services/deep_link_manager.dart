class DeepLinkManager {
  static final DeepLinkManager _instance = DeepLinkManager._internal();
  factory DeepLinkManager() => _instance;
  DeepLinkManager._internal();

  // Store the pending navigation globally
  Map<String, dynamic>? _pendingNavigation;

  // Set pending navigation
  void setPendingNavigation(Map<String, dynamic>? navigation) {
    _pendingNavigation = navigation;
    print('📌 Deep link stored: $_pendingNavigation');
  }

  // Get pending navigation
  Map<String, dynamic>? getPendingNavigation() {
    return _pendingNavigation;
  }

  // Clear pending navigation after use
  void clearPendingNavigation() {
    print('🗑️ Deep link cleared: $_pendingNavigation');
    _pendingNavigation = null;
  }

  // Check if there's a pending navigation
  bool hasPendingNavigation() {
    return _pendingNavigation != null;
  }
}