import 'package:flutter/foundation.dart';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/contacts/data/model/get_contact_model.dart';

class ContactRepo {
  final ApiClient _apiClient;

  ContactRepo(this._apiClient);

  GetContactModel contactModel = GetContactModel();

  Future<GetContactModel> contactGet(List<Map<String, dynamic>> contact) async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.userCreateContact,
        method: "POST",
        body: {'contact_details': contact},
      );

      contactModel = GetContactModel.fromJson(response);

      return contactModel;
    } catch (e) {
      rethrow;
    }
  }

  Future<GetContactModel> getContacts() async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.getContacts,
        method: "GET",
      );

      final contactModel = GetContactModel.fromJson(response);
      return contactModel;
    } catch (e) {
      rethrow;
    }
  }

  // New method specifically for parsing get-contacts response
  Future<List<ContactDetails>> getContactsList() async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.getContacts,
        method: "GET",
      );

      // For get-contacts, response.data is directly an array
      if (response['status'] == true && response['data'] != null) {
        final contactDataList = response['data'] as List<dynamic>;
        return contactDataList
            .where((contact) => contact != null)
            .map((contact) => ContactDetails.fromJson(contact as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Incremental sync: sends only changes since last sync.
  /// Returns raw response map so provider can read sync_timestamp & newly_registered_users.
  Future<Map<String, dynamic>> syncContacts({
    required String? lastSyncTimestamp,
    required List<Map<String, dynamic>> addedContacts,
    required List<Map<String, dynamic>> updatedContacts,
    required List<Map<String, dynamic>> deletedContacts,
  }) async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.syncContacts,
        method: "POST",
        body: {
          'last_sync_timestamp': lastSyncTimestamp,
          'added_contacts': addedContacts,
          'updated_contacts': updatedContacts,
          'deleted_contacts': deletedContacts,
        },
      );
      return response;
    } catch (e) {
      debugPrint('Sync API error: $e');
      rethrow;
    }
  }
}
