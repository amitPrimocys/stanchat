// ✅ Core Services
import 'package:dio/dio.dart';
import 'package:stanchat/core/api/api_client.dart';
import 'package:stanchat/core/network/network_listner.dart';
import 'package:stanchat/dependency_injection.dart';
import 'package:stanchat/featuers/auth/data/repositories/login_repository.dart';
import 'package:stanchat/featuers/auth/provider/auth_provider.dart';
import 'package:stanchat/featuers/provider/theme_provider.dart';
import 'package:stanchat/utils/network_info.dart';
import 'package:stanchat/utils/preference_key/sharedpref_key.dart';

final authRepo = getIt<LoginRepository>();

final authProvider = getIt<AuthProvider>();
final themeProvider = getIt<ThemeProvider>();

final dio = getIt<Dio>();
final networkInfo = getIt<NetworkInfo>();
final apiClient = getIt<ApiClient>();
final securePrefs = getIt<SecurePrefs>();
final networkListener = getIt<NetworkListener>();
