// File: lib/features/groups/providers/group_provider.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:whoxa/featuers/chat/group/data/model/create_group_response.dart';
import 'package:whoxa/featuers/chat/group/data/model/group_member_response.dart';
import 'package:whoxa/featuers/chat/group/data/repository/group_repository.dart';
import 'package:whoxa/utils/logger.dart';

class GroupProvider with ChangeNotifier {
  final GroupRepo _repo;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  GroupProvider(this._repo);

  // Loading states
  bool _isLoading = false;
  bool _isMembersLoading = false;
  bool _isMemberActionLoading = false;

  // Error states
  String? _error;
  String? _membersError;

  // Data
  CreateGroupResponse? _response;
  GroupMembersResponse? _membersResponse;
  List<GroupMember> _members = [];

  // Group info
  String? _groupName;
  String? _groupDescription;
  String? _groupIcon;

  // Getters
  bool get isLoading => _isLoading;
  bool get isMembersLoading => _isMembersLoading;
  bool get isMemberActionLoading => _isMemberActionLoading;

  String? get error => _error;
  String? get membersError => _membersError;

  CreateGroupResponse? get response => _response;
  GroupMembersResponse? get membersResponse => _membersResponse;
  List<GroupMember> get members => _members;

  // Group info getters
  String? get groupName => _groupName;
  String? get groupDescription => _groupDescription;
  String? get groupIcon => _groupIcon;

  // Helper getters
  int get memberCount => _members.length;
  List<GroupMember> get admins => _members.where((m) => m.isAdmin).toList();
  List<GroupMember> get regularMembers =>
      _members.where((m) => !m.isAdmin).toList();
  int get adminCount => admins.length;
  int get onlineMemberCount => _members.where((m) => m.isOnline == true).length;

  bool isMember(String userId) {
    final parsedId = int.tryParse(userId);
    if (parsedId == null) return false;
    return members.any((e) => e.userId == parsedId);
  }

  // Create Group
  Future<void> createGroup({
    required List<int> participants,
    required String groupName,
    required String description,
    File? groupIcon,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logger.i('Creating group: $groupName');
      _response = await _repo.createGroup(
        participants: participants,
        groupName: groupName,
        description: description,
        groupIcon: groupIcon,
      );
      _logger.i('Group created successfully');
    } catch (e) {
      _error = e.toString();
      _logger.e('Error creating group', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update Group
  Future<Map<String, dynamic>?> updateGroup({
    required int chatId,
    required String groupName,
    required String groupDescription,
    String? pictureType,
    File? groupIcon,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logger.i('Updating group: $groupName (Chat ID: $chatId)');
      final response = await _repo.updateGroup(
        chatId: chatId,
        groupName: groupName,
        groupDescription: groupDescription,
        pictureType: pictureType,
        groupIcon: groupIcon,
      );

      if (response != null && (response['status'] == true)) {
        _logger.i('Group updated successfully');
        _logger.d('Update response data: ${response['data']}');

        // Update local group info from response
        final data = response['data'];
        if (data != null) {
          _groupName = data['group_name']?.toString();
          _groupDescription = data['group_description']?.toString();
          _groupIcon = data['group_icon']?.toString();
        }

        return response;
      } else {
        _logger.w('Group update returned false or null response');
        return null;
      }
    } catch (e) {
      _error = e.toString();
      _logger.e('Error updating group', e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get Group Members
  Future<void> getGroupMembers({required int chatId}) async {
    _isMembersLoading = true;
    _membersError = null;
    notifyListeners();

    try {
      _logger.i('Fetching group members for chat: $chatId');
      _membersResponse = await _repo.getGroupMembers(chatId: chatId);
      _members = _membersResponse?.data.records ?? [];
      _logger.i('Fetched ${_members.length} group members');

      // Log member details for debugging
      for (final member in _members) {
        _logger.d(
          'Member: ${member.displayName} (ID: ${member.userId}, Admin: ${member.isAdmin})',
        );
      }
      notifyListeners();
    } catch (e) {
      _membersError = e.toString();
      _logger.e('Error fetching group members', e);
    } finally {
      _isMembersLoading = false;
      notifyListeners();
    }
  }

  // Remove Group Member
  Future<bool> removeGroupMember({
    required int chatId,
    required int userId,
  }) async {
    _isMemberActionLoading = true;
    notifyListeners();

    try {
      _logger.i('Removing member $userId from group $chatId');
      final success = await _repo.removeGroupMember(
        chatId: chatId,
        userId: userId,
      );

      if (success) {
        // Remove member from local list
        _members.removeWhere((member) => member.userId == userId);
        _logger.i('Member removed successfully from local list');
      }

      return success;
    } catch (e) {
      _logger.e('Error removing group member', e);
      return false;
    } finally {
      _isMemberActionLoading = false;
      notifyListeners();
    }
  }

  // Add Group Member
  Future<bool> addGroupMember({
    required int chatId,
    required List<int> userIds,
  }) async {
    _isMemberActionLoading = true;
    notifyListeners();

    try {
      _logger.i('Adding member group $chatId');
      final success = await _repo.addGroupMember(
        chatId: chatId,
        userIds: userIds,
      );

      if (success) {
        // Refresh members list to get the new member
        await getGroupMembers(chatId: chatId);
        _logger.i('Member added successfully and list refreshed');
      }

      return success;
    } catch (e) {
      _logger.e('Error adding group member', e);
      return false;
    } finally {
      _isMemberActionLoading = false;
      notifyListeners();
    }
  }

  // Make Group Admin
  Future<bool> makeGroupAdmin({
    required int chatId,
    required int userId,
    required bool isRemove,
  }) async {
    _isMemberActionLoading = true;
    notifyListeners();

    try {
      if (isRemove) {
        _logger.i(
          'Removing admin privileges from user $userId in group $chatId',
        );
      } else {
        _logger.i('Making user $userId admin of group $chatId');
      }

      final success = await _repo.makeGroupAdmin(
        chatId: chatId,
        userId: userId,
        // isRemove: isRemove, // Pass the isRemove parameter to repository
      );

      if (success) {
        // Update member's admin status in local list
        final memberIndex = _members.indexWhere(
          (member) => member.userId == userId,
        );

        if (memberIndex != -1) {
          _members[memberIndex] = GroupMember(
            participantId: _members[memberIndex].participantId,
            isAdmin: !isRemove, // Set to false if removing, true if adding
            updateCounter: _members[memberIndex].updateCounter,
            isDeleted: _members[memberIndex].isDeleted,
            lastMessageId: _members[memberIndex].lastMessageId,
            createdAt: _members[memberIndex].createdAt,
            updatedAt: DateTime.now().toIso8601String(),
            chatId: _members[memberIndex].chatId,
            userId: _members[memberIndex].userId,
            user: _members[memberIndex].user,
            isOnline: _members[memberIndex].isOnline,
            lastSeen: _members[memberIndex].lastSeen,
          );

          if (isRemove) {
            _logger.i('Removed admin privileges from user locally');
          } else {
            _logger.i('Updated member admin status locally');
          }
        }
      }

      return success;
    } catch (e) {
      if (isRemove) {
        _logger.e('Error removing admin privileges', e);
      } else {
        _logger.e('Error making user admin', e);
      }
      return false;
    } finally {
      _isMemberActionLoading = false;
      notifyListeners();
    }
  }

  // Remove Group Admin
  Future<bool> removeGroupAdmin({
    required int chatId,
    required int userId,
  }) async {
    _isMemberActionLoading = true;
    notifyListeners();

    try {
      _logger.i('Removing admin rights from user $userId in group $chatId');
      final success = await _repo.removeGroupAdmin(
        chatId: chatId,
        userId: userId,
      );

      if (success) {
        // Update member's admin status in local list
        final memberIndex = _members.indexWhere(
          (member) => member.userId == userId,
        );
        if (memberIndex != -1) {
          _members[memberIndex] = GroupMember(
            participantId: _members[memberIndex].participantId,
            isAdmin: false,
            updateCounter: _members[memberIndex].updateCounter,
            isDeleted: _members[memberIndex].isDeleted,
            lastMessageId: _members[memberIndex].lastMessageId,
            createdAt: _members[memberIndex].createdAt,
            updatedAt: DateTime.now().toIso8601String(),
            chatId: _members[memberIndex].chatId,
            userId: _members[memberIndex].userId,
            user: _members[memberIndex].user,
            isOnline: _members[memberIndex].isOnline,
            lastSeen: _members[memberIndex].lastSeen,
          );
          _logger.i('Updated member admin status locally');
        }
      }

      return success;
    } catch (e) {
      _logger.e('Error removing admin rights', e);
      return false;
    } finally {
      _isMemberActionLoading = false;
      notifyListeners();
    }
  }

  // Update member online status (called from ChatProvider or external source)
  void updateMemberOnlineStatus({
    required int userId,
    required bool isOnline,
    String? lastSeen,
  }) {
    final memberIndex = _members.indexWhere(
      (member) => member.userId == userId,
    );
    if (memberIndex != -1) {
      _members[memberIndex] = _members[memberIndex].copyWith(
        isOnline: isOnline,
        lastSeen: lastSeen,
      );
      notifyListeners();
      _logger.d('Updated online status for user $userId: $isOnline');
    }
  }

  // Set group info (useful for initializing from chat data)
  void setGroupInfo({
    String? groupName,
    String? groupDescription,
    String? groupIcon,
  }) {
    _groupName = groupName;
    _groupDescription = groupDescription;
    _groupIcon = groupIcon;
    // notifyListeners();
  }

  // Clear all data
  void clearData() {
    _response = null;
    _membersResponse = null;
    _members.clear();
    _error = null;
    _membersError = null;
    _groupName = null;
    _groupDescription = null;
    _groupIcon = null;
    notifyListeners();
  }

  // Check if user is admin
  bool isUserAdmin(int userId) {
    return _members.any((member) => member.userId == userId && member.isAdmin);
  }

  // Get member by user ID
  GroupMember? getMemberByUserId(int userId) {
    try {
      return _members.firstWhere((member) => member.userId == userId);
    } catch (e) {
      return null;
    }
  }

  // Get display name for a user ID
  String getMemberDisplayName(int userId) {
    final member = getMemberByUserId(userId);
    return member?.displayName ?? 'User $userId';
  }

  // Check if a user exists in the group
  bool isMemberInGroup(int userId) {
    return _members.any((member) => member.userId == userId);
  }

  // Get available contacts for adding to group (not already members)
  List<int> getAvailableContactIds(List<int> allContactIds) {
    final memberIds = _members.map((m) => m.userId).toSet();
    return allContactIds.where((id) => !memberIds.contains(id)).toList();
  }
}
