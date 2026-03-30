// * Uncomment kalo dibutuhin
// import 'dart:convert';

// import 'package:flutter_setup_riverpod/core/constants/storage_key_constant.dart';
// import 'package:flutter_setup_riverpod/core/extensions/logger_extension.dart';
// import 'package:flutter_setup_riverpod/feature/user/models/user.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// abstract class AuthService {
//   Future<String?> getAccessToken();
//   Future<void> saveAccessToken(String token);
//   Future<void> deleteAccessToken();

//   Future<User?> getUser();
//   Future<void> saveUser(User user);
//   Future<void> deleteUser();

//   Future<void> clearAuth();
// }

// class AuthServiceImpl implements AuthService {
//   final FlutterSecureStorage _flutterSecureStorage;
//   final SharedPreferencesWithCache _sharedPreferencesWithCache;

//   AuthServiceImpl(this._flutterSecureStorage, this._sharedPreferencesWithCache);

//   @override
//   Future<String?> getAccessToken() async {
//     final token = await _flutterSecureStorage.read(
//       key: StorageKeyConstant.accessTokenKey,
//     );
//     logData('GET accessToken: ${token != null ? 'Token exists' : 'No token'}');
//     return token;
//   }

//   @override
//   Future<void> saveAccessToken(String token) async {
//     await _flutterSecureStorage.write(
//       key: StorageKeyConstant.accessTokenKey,
//       value: token,
//     );
//     logData('SAVE accessToken: Token saved successfully');
//   }

//   @override
//   Future<void> deleteAccessToken() async {
//     await _flutterSecureStorage.delete(key: StorageKeyConstant.accessTokenKey);
//     logData('DELETE accessToken');
//   }

//   @override
//   Future<User?> getUser() async {
//     final userJson = _sharedPreferencesWithCache.getString(
//       StorageKeyConstant.userKey,
//     );

//     if (userJson != null) {
//       final userModelJson = User.fromJson(jsonDecode(userJson) as String);
//       logData('GET user: User found: ${userModelJson.name}');
//       return userModelJson;
//     }

//     logData('GET user: No user found');
//     return null;
//   }

//   @override
//   Future<void> saveUser(User userModel) async {
//     await _sharedPreferencesWithCache.setString(
//       StorageKeyConstant.userKey,
//       jsonEncode(userModel.toJson()),
//     );
//     logData('SAVE user: User saved: ${userModel.name}');
//   }

//   @override
//   Future<void> deleteUser() async {
//     await _sharedPreferencesWithCache.remove(StorageKeyConstant.userKey);
//     logData('DELETE user');
//   }

//   @override
//   Future<void> clearAuth() async {
//     await deleteAccessToken();
//     await deleteUser();
//     logData('CLEAR auth: All auth data cleared');
//   }
// }
