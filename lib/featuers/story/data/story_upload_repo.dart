import 'dart:io';

import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/story/data/model/delete_story_model.dart';
import 'package:whoxa/featuers/story/data/model/get_all_story_model.dart';
import 'package:whoxa/featuers/story/data/model/story_upload_model.dart';
import 'package:whoxa/featuers/story/data/model/viewed_story_model.dart';
import 'package:whoxa/featuers/story/data/model/viewed_user_list_model.dart';
import 'package:whoxa/utils/logger.dart';

class StoryUploadRepo {
  final ApiClient _apiClient;
  final ConsoleAppLogger _logger = ConsoleAppLogger();

  StoryUploadRepo(this._apiClient);

  StoryUploadModel storyUploadModel = StoryUploadModel();
  Future<StoryUploadModel> stroyUploadRepo(
    String storyType,
    File storyFile,
    String? caption,
    String? thumbnailPath,
  ) async {
    _logger.i('StoryType: $storyType');
    _logger.i('StoryFile: $storyFile');
    _logger.i('StoryCaption: $caption');

    Map<String, dynamic> files = {};

    if (storyType == 'video') {
      List<String> videoFiles = [];
      String videopath = storyFile.path;
      String thumbnail = thumbnailPath!;

      videoFiles.add(videopath);
      videoFiles.add(thumbnail);

      files['files'] = videoFiles;
    } else {
      files['files'] = storyFile.path;
    }

    try {
      final response = await _apiClient.multipartRequest(
        ApiEndpoints.storyUpload,
        body:
            caption!.isEmpty
                ? {'story_type': storyType, 'pictureType': 'story'}
                : {
                  'story_type': storyType,
                  'caption': caption,
                  'pictureType': 'story',
                },
        files: files,
      );

      return storyUploadModel = StoryUploadModel.fromJson(response);
    } catch (e) {
      _logger.e('Error adding stroy:', e.toString());
      rethrow;
    }
  }

  //************************************************************************************/
  //************************************** GET ALL STORIES *****************************/
  //************************************************************************************/
  GetAllStoriesModel getStories = GetAllStoriesModel();
  Future<GetAllStoriesModel> getAllStoriesRepo() async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.storyGetAll,
        method: "GET",
      );

      return getStories = GetAllStoriesModel.fromJson(response);
    } catch (e) {
      _logger.e('Error stroy fetch:', e.toString());
      rethrow;
    }
  }

  //************************************************************************************/
  //************************************** VIEWED STORIES *****************************/
  //************************************************************************************/
  ViewedStoriesModel viewedStories = ViewedStoriesModel();
  Future<ViewedStoriesModel> viewedStoryRepo({required String storyID}) async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.storyView,
        method: "PUT",
        body: {'story_id': storyID},
      );

      return viewedStories = ViewedStoriesModel.fromJson(response);
    } catch (e) {
      _logger.e('Error story viewed:', e.toString());
      rethrow;
    }
  }

  //************************************************************************************/
  //************************************** REMOVE STORIES *****************************/
  //************************************************************************************/
  DeleteStoryModel deleteStoryModel = DeleteStoryModel();

  Future<DeleteStoryModel> removeStoryRepo({required String storyId}) async {
    _logger.d("storyID:$storyId");
    try {
      final response = await _apiClient.request(
        ApiEndpoints.storyDelete,
        method: "DELETE",
        body: {'story_id': storyId},
      );

      return deleteStoryModel = DeleteStoryModel.fromJson(response);
    } catch (e) {
      _logger.e('Error story remove:', e.toString());
      rethrow;
    }
  }

  //************************************************************************************/
  //************************************** VIEWED STORY USER LIST **********************/
  //************************************************************************************/
  ViewedUserListModel viewedUserListModel = ViewedUserListModel();

  Future<ViewedUserListModel> viewedUserRepo({required String storyID}) async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.getStory,
        method: "POST",
        body: {'story_id': storyID},
      );

      return viewedUserListModel = ViewedUserListModel.fromJson(response);
    } catch (e) {
      _logger.e('Error story viewed:', e.toString());
      rethrow;
    }
  }
}
