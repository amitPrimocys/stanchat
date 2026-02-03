import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CountryCodeService {
  static Map<String, dynamic>? _countryCodesData;
  static bool _isInitialized = false;

  // Initialize the service by loading the JSON file
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/country_codes.json',
      );
      _countryCodesData = json.decode(jsonString);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error loading country codes: $e');
      _countryCodesData = {};
      _isInitialized = true;
    }
  }

  // Get country codes data
  static Map<String, dynamic> get countryCodesData {
    if (!_isInitialized) {
      throw Exception(
        'CountryCodeService not initialized. Call initialize() first.',
      );
    }
    return _countryCodesData?['country_codes'] ?? {};
  }

  // Check if a country code exists
  static bool isValidCountryCode(String code) {
    return countryCodesData.containsKey(code);
  }

  // Get country info by code
  static Map<String, dynamic>? getCountryInfo(String code) {
    return countryCodesData[code];
  }

  // Get primary country code for a country code
  static String? getPrimaryCountry(String code) {
    final info = getCountryInfo(code);
    if (info != null &&
        info['countries'] is List &&
        (info['countries'] as List).isNotEmpty) {
      return (info['countries'] as List).first;
    }
    return null;
  }

  // Get all possible country codes sorted by length (longest first for better matching)
  static List<String> getAllCountryCodesSorted() {
    final codes = countryCodesData.keys.toList();
    codes.sort((a, b) => b.length.compareTo(a.length));
    return codes;
  }

  // Find the best matching country code for a phone number
  static String? findBestMatchingCountryCode(String phoneNumber) {
    if (!phoneNumber.startsWith('+')) return null;

    final numberWithoutPlus = phoneNumber.substring(1);
    final sortedCodes = getAllCountryCodesSorted();

    for (String code in sortedCodes) {
      if (numberWithoutPlus.startsWith(code)) {
        return code;
      }
    }

    return null;
  }
}
