/// Stub implementation for non-web platforms.
/// Returns null since localStorage is not available.
String? getSavedConsent() => null;

/// Stub: no-op on non-web platforms.
void gtagLogEvent(String name, Map<String, Object>? params) {}

/// Stub: no-op on non-web platforms.
void gtagSetUserId(String? uid) {}
