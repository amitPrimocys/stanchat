// File: lib/features/groups/repository/group_repo.dart
import 'dart:io';
import 'package:stanchat/core/api/api_client.dart';
import 'package:stanchat/core/api/api_endpoint.dart';
import 'package:stanchat/featuers/chat/group/data/model/create_group_response.dart';
import 'package:stanchat/featuers/chat/group/data/model/group_member_response.dart';
import 'package:stanchat/utils/logger.dart';

class GroupRepo {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger.forModule('GroupRepo');
  GroupRepo(this._apiClient);

  Future<CreateGroupResponse> createGroup({
    required List<int> participants,
    required String groupName,
    required String description,
    File? groupIcon,
  }) async {
    _logger.d('check group icon before send: $groupIcon');
    final body = {
      'participants': participants,
      'group_name': groupName,
      'group_description': description,
    };

    if (groupIcon != null) {
      _logger.d('groupIcon is passed: $groupIcon');
      body['pictureType'] = 'group_icon';

      // Use multipart request for file uploads
      final files = {'group_icon': groupIcon.path};

      final resp = await _apiClient.multipartRequest(
        ApiEndpoints.groupCreate,
        body: body,
        files: files,
      );
      _logger.d('createGroup body passed: $body');
      return CreateGroupResponse.fromJson(resp as Map<String, dynamic>);
    } else {
      _logger.d('groupIcon is faild reason is null: $groupIcon');
      // Use regular request when no file is involved
      final resp = await _apiClient.request(
        ApiEndpoints.groupCreate,
        method: 'POST',
        body: body,
      );
      _logger.d('createGroup body passed: $body');
      return CreateGroupResponse.fromJson(resp as Map<String, dynamic>);
    }
  }

  Future<Map<String, dynamic>?> updateGroup({
    required int chatId,
    required String groupName,
    required String groupDescription,
    String? pictureType,
    File? groupIcon,
  }) async {
    _logger.i('Updating group with chat ID: $chatId');

    final body = {
      'chat_id': chatId,
      'group_name': groupName,
      'group_description': groupDescription,
    };

    if (pictureType != null) {
      body['pictureType'] = pictureType;
    }

    try {
      final dynamic resp;

      if (groupIcon != null) {
        // Use multipart request for file uploads
        final files = {'group_icon': groupIcon.path};

        resp = await _apiClient.multipartRequest(
          ApiEndpoints.groupUpdate,
          body: body,
          files: files,
        );
      } else {
        // Use regular request when no file is involved
        resp = await _apiClient.request(
          ApiEndpoints.groupUpdate,
          method: 'POST',
          body: body,
        );
      }

      _logger.i('Group updated successfully');
      _logger.d('Update response: $resp');
      return resp as Map<String, dynamic>?;
    } catch (e) {
      _logger.e('Error updating group', e);
      rethrow;
    }
  }

  Future<GroupMembersResponse> getGroupMembers({required int chatId}) async {
    _logger.i('Fetching group members for chat ID: $chatId');

    try {
      final resp = await _apiClient.request(
        ApiEndpoints.groupMembers,
        method: 'POST',
        body: {"chat_id": chatId},
      );

      _logger.i('Group members fetched successfully');
      return GroupMembersResponse.fromJson(resp as Map<String, dynamic>);
    } catch (e) {
      _logger.e('Error fetching group members', e);
      rethrow;
    }
  }

  Future<bool> removeGroupMember({
    required int chatId,
    required int userId,
  }) async {
    _logger.i('Removing member $userId from chat $chatId');
    final body = {'chat_id': chatId, 'user_id': userId, 'delete_chat': false};
    try {
      final resp = await _apiClient.request(
        ApiEndpoints.removeMember,
        method: 'POST',
        body: body,
      );
      _logger.i('Member removed successfully');
      return resp['status'] ?? false;
    } catch (e) {
      _logger.e('Error removing group member', e);
      rethrow;
    }
  }

  // Add Group Member
  Future<bool> addGroupMember({
    required int chatId,
    required List<int> userIds,
  }) async {
    _logger.i('Adding member to chat $chatId');
    final body = {'chat_id': chatId, 'user_id': userIds};
    try {
      final resp = await _apiClient.request(
        ApiEndpoints.addMember,
        method: 'POST',
        body: body,
      );
      _logger.i('Member added successfully');
      return resp['status'] ?? false;
    } catch (e) {
      _logger.e('Error adding group member', e);
      rethrow;
    }
  }

  // Make Group Admin
  Future<bool> makeGroupAdmin({
    required int chatId,
    required int userId,
  }) async {
    _logger.i('Making user $userId admin of chat $chatId');
    final body = {'chat_id': chatId, 'admin_user_id': userId};
    try {
      final resp = await _apiClient.request(
        ApiEndpoints.makeGroupAdmin,
        method: 'POST',
        body: body,
      );
      _logger.i('User made admin successfully');
      return resp['status'] ?? false;
    } catch (e) {
      _logger.e('Error making user admin', e);
      rethrow;
    }
  }

  // Remove Group Admin
  Future<bool> removeGroupAdmin({
    required int chatId,
    required int userId,
  }) async {
    _logger.i('Removing admin rights from user $userId in chat $chatId');
    final body = {'chat_id': chatId, 'user_id': userId};
    try {
      final resp = await _apiClient.request(
        ApiEndpoints.removeGroupAdmin,
        method: 'POST',
        body: body,
      );
      _logger.i('Admin rights removed successfully');
      return resp['status'] ?? false;
    } catch (e) {
      _logger.e('Error removing admin rights', e);
      rethrow;
    }
  }
}
