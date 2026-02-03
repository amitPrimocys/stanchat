import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/featuers/contacts/data/repository/contact_repo.dart';
import 'package:whoxa/featuers/contacts/data/model/get_contact_model.dart';
import 'package:whoxa/featuers/project-config/provider/config_provider.dart';
import 'package:whoxa/utils/network_info.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'dart:convert';

class ContactNameService {
  static ContactNameService? _instance;
  static ContactNameService get instance =>
      _instance ??= ContactNameService._();

  ContactNameService._() {
    _initializeFromStorage();
  }

  Future<void> _initializeFromStorage() async {
    try {
      // Load contact cache from storage
      final String? cachedData = await SecurePrefs.getString(_cacheKey);
      if (cachedData != null && cachedData.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(cachedData);
        final Map<String, dynamic> contacts = decoded['contacts'] ?? {};
        final String? lastUpdate = decoded['lastUpdate'];

        _userIdToContactNameCache = contacts.map(
          (key, value) => MapEntry(int.parse(key), value.toString()),
        );

        if (lastUpdate != null) {
          _lastCacheUpdate = DateTime.tryParse(lastUpdate);
        }

        if (kDebugMode) {
          debugPrint(
            '✅ Loaded ${_userIdToContactNameCache.length} contacts from storage',
          );
        }
      }

      // Load final display name cache from storage
      final String? finalCachedData = await SecurePrefs.getString(
        _finalNameCacheKey,
      );
      if (finalCachedData != null && finalCachedData.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(finalCachedData);
        _finalDisplayNameCache = decoded.map(
          (key, value) => MapEntry(int.parse(key), value.toString()),
        );

        if (kDebugMode) {
          debugPrint(
            '✅ Loaded ${_finalDisplayNameCache.length} final names from storage',
          );
        }
      }

      // Load API user data cache from storage
      final String? apiCachedData = await SecurePrefs.getString(_apiDataCacheKey);
      if (apiCachedData != null && apiCachedData.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(apiCachedData);
        _apiUserDataCache = decoded.map(
          (key, value) => MapEntry(
            int.parse(key), 
            (value as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, v?.toString())
            )
          ),
        );

        if (kDebugMode) {
          debugPrint('✅ Loaded ${_apiUserDataCache.length} API user data from storage');
        }
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading contact cache from storage: $e');
      }
      _isInitialized = true; // Still mark as initialized to prevent blocking
    }
  }

  final ContactRepo _contactRepo = ContactRepo(
    ApiClient(Dio(), NetworkInfoImpl(Connectivity())),
  );
  Map<int, String> _userIdToContactNameCache = {}; // Local device contact names
  Map<int, String> _finalDisplayNameCache = {}; // Cache for final decided names
  Map<int, Map<String, String?>> _apiUserDataCache = {}; // API user data (userName, fullName, email)
  DateTime? _lastCacheUpdate;
  static const Duration _cacheValidityDuration = Duration(minutes: 10);
  static const String _cacheKey = 'contact_name_cache';
  static const String _finalNameCacheKey = 'final_display_name_cache';
  static const String _apiDataCacheKey = 'api_user_data_cache';

  bool _isLoading = false;
  // ignore: unused_field
  bool _isInitialized = false;

  Future<void> loadAndCacheContacts() async {
    if (_isLoading) return;

    final now = DateTime.now();
    if (_lastCacheUpdate != null &&
        now.difference(_lastCacheUpdate!) < _cacheValidityDuration) {
      debugPrint('Contact cache is still valid, skipping reload');
      return;
    }

    _isLoading = true;
    try {
      // 🔄 UPDATED: Use the new getContactsList method for consistency
      debugPrint('🔄 loadAndCacheContacts: Using getContactsList for contact sync');
      final contactDetailsList = await _contactRepo.getContactsList();

      if (contactDetailsList.isNotEmpty) {
        // Use the new sync method to handle contact updates properly
        await syncContactDataFromApi(contactDetailsList);
        
        _lastCacheUpdate = now;

        if (kDebugMode) {
          debugPrint('✅ loadAndCacheContacts: Synced ${contactDetailsList.length} contacts');
          debugPrint('   Local contacts cached: ${_userIdToContactNameCache.length}');
          debugPrint('   API users cached: ${_apiUserDataCache.length}');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ loadAndCacheContacts: No contacts returned from API');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ loadAndCacheContacts: Error loading contacts: $e');
      }
      // Continue - other contact loading mechanisms might work
    } finally {
      _isLoading = false;
    }
  }

  // Method to manually update the cache with contact data
  Future<void> updateCacheWithContacts(Map<int, String> contacts) async {
    _userIdToContactNameCache.clear();
    _userIdToContactNameCache.addAll(contacts);
    _lastCacheUpdate = DateTime.now();
    await _saveToStorage();

    if (kDebugMode) {
      debugPrint('Contact cache manually updated with ${contacts.length} contacts');
      for (final entry in contacts.entries) {
        debugPrint('Cached contact: userId=${entry.key}, name=${entry.value}');
      }
    }
  }

  // 🎯 SIMPLIFIED: Use ONLY API 'name' field as single source of truth for display names
  Future<void> syncContactDataFromApi(List<ContactDetails> apiContacts) async {
    int nameUpdatesCount = 0;
    List<int> changedUserIds = [];

    for (final apiContact in apiContacts) {
      if (apiContact.userId == null) continue;

      final userId = apiContact.userId!;
      final apiDisplayName = apiContact.name; // This is the ONLY display name we use
      final apiUserName = apiContact.userName; // Store for fallback only
      
      // Check if we have existing cached display name
      final existingDisplayName = _userIdToContactNameCache[userId];
      
      // Update cache if API has a different value
      if (apiDisplayName != null && apiDisplayName.trim().isNotEmpty) {
        if (existingDisplayName != apiDisplayName) {
          _userIdToContactNameCache[userId] = apiDisplayName;
          changedUserIds.add(userId);
          nameUpdatesCount++;
          
          if (kDebugMode) {
            debugPrint('[ContactSync] user_id=$userId, old_name="${existingDisplayName ?? 'null'}", new_name="$apiDisplayName" → updated');
          }
        } else {
          if (kDebugMode) {
            debugPrint('[ContactSync] user_id=$userId, no change');
          }
        }
      } else {
        // If API name is empty/null, remove from primary cache to allow fallback to userName
        if (existingDisplayName != null) {
          _userIdToContactNameCache.remove(userId);
          changedUserIds.add(userId);
          if (kDebugMode) {
            debugPrint('[ContactSync] user_id=$userId, API name empty → removed from primary cache, will use userName fallback');
          }
        }
      }

      // Store API data for fallback (when name is empty)
      _apiUserDataCache[userId] = {
        'userName': apiUserName,
        'fullName': apiDisplayName,
        'email': null,
      };
    }

    // Clear final cache for changed users so they get re-evaluated with updated names
    if (changedUserIds.isNotEmpty) {
      for (final userId in changedUserIds) {
        _finalDisplayNameCache.remove(userId);
      }
      
      if (kDebugMode) {
        debugPrint('[ContactSync] Cleared final cache for ${changedUserIds.length} users with name changes');
      }
    }

    // Save updated caches
    await _saveToStorage();

    if (kDebugMode) {
      debugPrint('[ContactSync] Sync completed: $nameUpdatesCount names updated, ${_userIdToContactNameCache.length} total API names cached');
    }
  }

  // 🔄 DEPRECATED: Keep old method name for compatibility, redirect to new method
  Future<void> syncApiUserData(List<ContactDetails> apiContacts) async {
    await syncContactDataFromApi(apiContacts);
  }

  // Save cache to persistent storage
  Future<void> _saveToStorage() async {
    try {
      final Map<String, dynamic> cacheData = {
        'contacts': _userIdToContactNameCache.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
        'lastUpdate': _lastCacheUpdate?.toIso8601String(),
      };
      await SecurePrefs.setString(_cacheKey, json.encode(cacheData));

      // Also save final display name cache
      final Map<String, dynamic> finalCacheData = _finalDisplayNameCache.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      await SecurePrefs.setString(
        _finalNameCacheKey,
        json.encode(finalCacheData),
      );

      // Save API user data cache
      final Map<String, dynamic> apiCacheData = _apiUserDataCache.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      await SecurePrefs.setString(
        _apiDataCacheKey,
        json.encode(apiCacheData),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving contact cache to storage: $e');
      }
    }
  }

  String getDisplayName({
    required int? userId,
    required String? userFullName,
    required String? userName,
    required String? userEmail,
    required ProjectConfigProvider? configProvider,
  }) {
    // ANTI-FLUCTUATION: First check if we already have a final decision for this user
    if (userId != null && _finalDisplayNameCache.containsKey(userId)) {
      final cachedName = _finalDisplayNameCache[userId]!;
      if (kDebugMode) {
        debugPrint('🔒 ANTI-FLUCTUATION: Using cached final name for userId $userId: "$cachedName"');
      }
      return cachedName;
    }

    final config = configProvider?.configData;

    if (config == null) {
      final fallbackName = _getFallbackName(userFullName, userName, userEmail);
      _saveFinalDisplayName(userId, fallbackName);
      return fallbackName;
    }

    String finalName;

    // 🎯 NEW PRIORITY: API 'name' field is SINGLE SOURCE OF TRUTH
    if (userId != null && _userIdToContactNameCache.containsKey(userId)) {
      // Use API 'name' field as the primary display name (ignores local device contacts)
      finalName = _userIdToContactNameCache[userId]!;
      if (kDebugMode) {
        debugPrint(
          '🎯 API NAME: Using backend-managed name for userId $userId: "$finalName" (Single Source of Truth)',
        );
      }
    } else {
      // Fallback to userName → fullName → email only when no API name available
      finalName = _getCorrectedFallbackName(userFullName, userName, userEmail);
      if (kDebugMode) {
        debugPrint(
          '🔄 FALLBACK: No API name for userId $userId, using fallback: "$finalName"',
        );
      }
    }

    // Cache the final decision to prevent future fluctuation
    _saveFinalDisplayName(userId, finalName);

    return finalName;
  }

  /// 🎯 NEW: Anti-flickering display name method that uses cached API names and proper fallback
  /// This method eliminates flickering while still following the correct priority order
  /// Use this in UI screens to show stable, consistent contact names
  String getDisplayNameStable({
    required int? userId,
    required ProjectConfigProvider? configProvider,
    String? contextFullName, // Full name from the calling context (e.g., PeerUserData)
  }) {
    // ANTI-FLUCTUATION: Always check cached final decision first
    if (userId != null && _finalDisplayNameCache.containsKey(userId)) {
      final cachedName = _finalDisplayNameCache[userId]!;
      if (kDebugMode) {
        debugPrint('🔒 STABLE: Using cached final name for userId $userId: "$cachedName"');
      }
      return cachedName;
    }

    // Priority 1: Use API cached name (from contacts API 'name' field) when number is in local contacts
    if (userId != null && _userIdToContactNameCache.containsKey(userId)) {
      final apiName = _userIdToContactNameCache[userId]!;
      if (kDebugMode) {
        debugPrint('🎯 STABLE API: Using contacts API name for userId $userId: "$apiName"');
      }
      // Cache this as final decision
      _saveFinalDisplayName(userId, apiName);
      return apiName;
    }

    // Priority 2: Use full name from calling context when number is NOT in local contacts
    if (contextFullName != null && contextFullName.trim().isNotEmpty) {
      if (kDebugMode) {
        debugPrint('🎯 CONTEXT FULL NAME: Using full name from context for userId $userId: "$contextFullName"');
      }
      // Cache this decision
      _saveFinalDisplayName(userId, contextFullName);
      return contextFullName;
    }

    // Priority 3: Final fallback - return unknown user only when no data exists
    const unknownName = 'Unknown User';
    if (kDebugMode) {
      debugPrint('❓ STABLE UNKNOWN: No data for userId $userId, using: "$unknownName"');
    }
    // Don't cache this decision - let it re-evaluate when API data comes in
    return unknownName;
  }

  // Save the final display name decision to prevent fluctuation
  void _saveFinalDisplayName(int? userId, String displayName) {
    if (userId != null) {
      _finalDisplayNameCache[userId] = displayName;
      // Save to persistent storage asynchronously
      _saveToStorage().catchError((e) {
        if (kDebugMode) {
          debugPrint('Error saving final display name cache: $e');
        }
      });
    }
  }

  String _getFallbackName(String? fullName, String? userName, String? email) {
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName;
    }
    if (userName != null && userName.trim().isNotEmpty) {
      return userName;
    }
    if (email != null && email.trim().isNotEmpty) {
      return email;
    }
    return 'Unknown User';
  }

  // CORRECTED FALLBACK: userName (Priority 2) → fullName (Priority 3) → email
  String _getCorrectedFallbackName(String? fullName, String? userName, String? email) {
    // PRIORITY FIXED: userName first, then fullName
    if (userName != null && userName.trim().isNotEmpty) {
      if (kDebugMode) {
        debugPrint('🎯 Using userName from API: "$userName"');
      }
      return userName;
    }
    if (fullName != null && fullName.trim().isNotEmpty) {
      if (kDebugMode) {
        debugPrint('📄 Using fullName from API: "$fullName"');
      }
      return fullName;
    }
    if (email != null && email.trim().isNotEmpty) {
      if (kDebugMode) {
        debugPrint('📧 Using email as fallback: "$email"');
      }
      return email;
    }
    if (kDebugMode) {
      debugPrint('❓ No valid name found, using Unknown User');
    }
    return 'Unknown User';
  }

  void clearCache() {
    _userIdToContactNameCache.clear();
    _finalDisplayNameCache.clear();
    _apiUserDataCache.clear();
    _lastCacheUpdate = null;
    // Clear persistent storage
    _clearStorageCache();
    
    if (kDebugMode) {
      debugPrint('🧹 ContactNameService: All caches cleared (local contacts + final names + API data)');
    }
  }

  // Clear only the anti-fluctuation cache to allow priority fix to take effect
  void clearFinalNameCache() {
    _finalDisplayNameCache.clear();
    // Save the updated cache state
    _saveToStorage().catchError((e) {
      if (kDebugMode) {
        debugPrint('Error saving after clearing final name cache: $e');
      }
    });
    
    if (kDebugMode) {
      debugPrint('🧹 ContactNameService: Final name cache cleared, names will be re-evaluated with fixed priority');
    }
  }

  Future<void> _clearStorageCache() async {
    try {
      await SecurePrefs.setString(_cacheKey, '');
      await SecurePrefs.setString(_finalNameCacheKey, '');
      await SecurePrefs.setString(_apiDataCacheKey, '');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error clearing storage cache: $e');
      }
    }
  }

  bool get hasCachedContacts => _userIdToContactNameCache.isNotEmpty;

  int get cachedContactsCount => _userIdToContactNameCache.length;

  // Check if a user is saved in contacts
  bool isUserInContacts(int? userId) {
    if (userId == null) return false;
    return _userIdToContactNameCache.containsKey(userId);
  }

  // Get the current final display name for a user (for debugging)
  String? getFinalDisplayName(int? userId) {
    if (userId == null) return null;
    return _finalDisplayNameCache[userId];
  }

  // Force refresh a specific user's display name (clears final cache for that user)
  void refreshUserDisplayName(int? userId) {
    if (userId != null && _finalDisplayNameCache.containsKey(userId)) {
      _finalDisplayNameCache.remove(userId);
      _saveToStorage().catchError((e) {
        if (kDebugMode) {
          debugPrint('Error saving after refreshing user display name: $e');
        }
      });
      if (kDebugMode) {
        debugPrint('🔄 Refreshed display name cache for userId: $userId');
      }
    }
  }

  // 🐛 DEBUG METHOD: Get detailed source information for a user's name
  Map<String, dynamic> getNameSourceDebugInfo(int? userId) {
    if (userId == null) {
      return {'error': 'userId is null'};
    }

    Map<String, dynamic> debugInfo = {
      'userId': userId,
      'hasLocalContact': _userIdToContactNameCache.containsKey(userId),
      'localContactName': _userIdToContactNameCache[userId],
      'hasFinalCache': _finalDisplayNameCache.containsKey(userId),
      'finalCachedName': _finalDisplayNameCache[userId],
      'cacheTimestamp': _lastCacheUpdate?.toIso8601String(),
    };

    if (kDebugMode) {
      debugPrint('🐛 DEBUG INFO for userId $userId:');
      debugInfo.forEach((key, value) {
        debugPrint('   $key: $value');
      });
    }

    return debugInfo;
  }

  // 🐛 DEBUG METHOD: Trace name selection process step by step
  String getDisplayNameWithTrace({
    required int? userId,
    required String? userFullName,
    required String? userName,
    required String? userEmail,
    required ProjectConfigProvider? configProvider,
  }) {
    if (kDebugMode) {
      debugPrint('🔍 TRACE: Starting name resolution for userId $userId');
      debugPrint('   Input: fullName="$userFullName", userName="$userName", email="$userEmail"');
    }
    
    // Get regular display name with enhanced logging
    String result = getDisplayName(
      userId: userId,
      userFullName: userFullName,
      userName: userName,
      userEmail: userEmail,
      configProvider: configProvider,
    );

    if (kDebugMode) {
      debugPrint('🎯 TRACE RESULT: userId $userId → "$result"');
      getNameSourceDebugInfo(userId); // Print debug info
    }
    
    return result;
  }

  // 🐛 DEBUG METHOD: List all cached contacts
  void printAllCachedContacts() {
    if (kDebugMode) {
      debugPrint('📋 ALL CACHED LOCAL CONTACTS (${_userIdToContactNameCache.length}):');
      _userIdToContactNameCache.forEach((userId, name) {
        debugPrint('   userId: $userId → "$name"');
      });
      
      debugPrint('📋 ALL FINAL CACHED NAMES (${_finalDisplayNameCache.length}):');
      _finalDisplayNameCache.forEach((userId, name) {
        debugPrint('   userId: $userId → "$name"');
      });

      debugPrint('📋 ALL API USER DATA (${_apiUserDataCache.length}):');
      _apiUserDataCache.forEach((userId, userData) {
        debugPrint('   userId: $userId → userName:"${userData['userName']}", fullName:"${userData['fullName']}"');
      });
    }
  }

  // 🐛 DEBUG METHOD: Check if API data exists for a specific user
  Map<String, String?> getApiUserData(int userId) {
    return _apiUserDataCache[userId] ?? {'userName': null, 'fullName': null, 'email': null};
  }

  // 🧪 TEST METHOD: Simulate API response with updated name field (single source of truth)
  Future<void> simulateApiNameUpdate(int userId, String newApiName, {String? userName}) async {
    if (kDebugMode) {
      debugPrint('🧪 SIMULATING API NAME UPDATE for userId=$userId');
      debugPrint('   New API name field: "$newApiName" (single source of truth)');
      debugPrint('   UserName: "${userName ?? 'unchanged'}"');
      
      // Show current state
      final currentApiName = _userIdToContactNameCache[userId];
      final currentFinalName = _finalDisplayNameCache[userId];
      debugPrint('   Current API name: "${currentApiName ?? 'none'}"');
      debugPrint('   Current final cached name: "${currentFinalName ?? 'none'}"');
      
      // Create fake ContactDetails representing API response
      final fakeApiResponse = ContactDetails(
        userId: userId,
        userName: userName,
        name: newApiName, // This is the ONLY display name source
        number: 'test_number',
        profilePic: null,
      );
      
      // Call sync method (simulating API response processing)
      await syncContactDataFromApi([fakeApiResponse]);
      
      // Show result
      final updatedApiName = _userIdToContactNameCache[userId];
      final updatedFinalName = _finalDisplayNameCache[userId];
      debugPrint('🧪 SIMULATION COMPLETE:');
      debugPrint('   Final API name: "${updatedApiName ?? 'none'}"');
      debugPrint('   Final display cache: "${updatedFinalName ?? 'cleared - will re-evaluate'}"');
      debugPrint('   Name change applied: ${currentApiName != updatedApiName ? 'YES' : 'NO'}');
      debugPrint('   UI will refresh: ${currentFinalName != null && updatedFinalName == null ? 'YES' : 'NO'}');
    }
  }

  // 🧪 TEST METHOD: Test API-only name display across all screens
  Future<void> testApiOnlyNameDisplay(int userId, String newApiName) async {
    if (kDebugMode) {
      debugPrint('🧪 TESTING API-ONLY NAME DISPLAY for userId=$userId');
      debugPrint('   New API name: "$newApiName" (ignores local device contacts)');
      
      await simulateApiNameUpdate(userId, newApiName);
      
      debugPrint('🧪 TEST COMPLETE: All screens should show API name');
      debugPrint('   Expected display name: "$newApiName"');
      debugPrint('   Screens affected: Chat List, Call Screen, Starred Messages, etc.');
    }
  }
}
