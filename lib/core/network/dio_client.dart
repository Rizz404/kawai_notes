// * Uncomment kalo dibutuhin
/* import 'package:flutter_setup_riverpod/core/constants/api_constant.dart';
import 'package:flutter_setup_riverpod/core/network/api_wrapper.dart';
import 'package:flutter_setup_riverpod/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_setup_riverpod/core/network/interceptors/locale_interceptor.dart';
import 'package:flutter_setup_riverpod/core/network/interceptors/network_error_interceptor.dart';
import 'package:flutter_setup_riverpod/core/services/auth_service.dart';
import 'package:flutter_setup_riverpod/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class DioClient {
  final Dio _dio;
  final LocaleInterceptor _localeInterceptor;
  final AuthInterceptor _authInterceptor;
  final NetworkErrorInterceptor _networkErrorInterceptor;

  DioClient(
    this._dio,
    AuthService authService, {
    void Function()? onTokenInvalid,
  }) : _localeInterceptor = LocaleInterceptor(),
       _authInterceptor = AuthInterceptor(
         authService,
         onTokenInvalid: onTokenInvalid,
       ),
       _networkErrorInterceptor = NetworkErrorInterceptor() {
    _dio.interceptors.clear();
    _dio
      ..options.baseUrl = ApiConstant.baseUrl
      ..options.connectTimeout = const Duration(
        milliseconds: ApiConstant.defaultConnectTimeout,
      )
      ..options.receiveTimeout = const Duration(
        milliseconds: ApiConstant.defaultReceiveTimeout,
      )
      ..options.responseType = ResponseType.json
      ..options.headers = {'Accept': 'application/json'}
      ..interceptors.add(_localeInterceptor)
      ..interceptors.add(_authInterceptor)
      ..interceptors.add(_networkErrorInterceptor);

    _dio.interceptors.add(logger.dioLogger);
  }

  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

      _validateHtmlResponse(response);

      return ApiResult.fromJson(
        response.data as Map<String, dynamic>,
        fromJson,
      );
    } on DioException catch (e) {
      return _handleError<T>(e);
    } catch (e) {
      return ApiFailure<T>(message: e.toString());
    }
  }

  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

      _validateHtmlResponse(response);

      return ApiResult.fromJson(
        response.data as Map<String, dynamic>,
        fromJson,
      );
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  Future<ApiResult<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

      _validateHtmlResponse(response);

      return ApiResult.fromJson(
        response.data as Map<String, dynamic>,
        fromJson,
      );
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  Future<ApiResult<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

      _validateHtmlResponse(response);

      return ApiResult.fromJson(
        response.data as Map<String, dynamic>,
        fromJson,
      );
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  Future<ApiResult<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final response = await _dio.delete<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

      _validateHtmlResponse(response);

      return ApiResult.fromJson(
        response.data as Map<String, dynamic>,
        fromJson,
      );
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  void updateLocale(Locale locale) {
    _localeInterceptor.updateLocale(locale);
  }

  void _validateHtmlResponse(Response<dynamic> response) {
    if (response.data is String &&
        (response.data as String?)?.trim().startsWith('<!DOCTYPE html>') ==
            true) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Server returned HTML instead of JSON',
      );
    }
  }

  ApiFailure<T> _handleError<T>(DioException error) {
    if (error.response?.data != null && error.response?.data is Map) {
      try {
        final data = error.response!.data as Map<String, dynamic>;
        return ApiFailure.fromJson(data);
      } catch (_) {}
    }

    String message = 'Unknown error occurred';
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        message = 'Connection timeout. Please check your internet.';
        break;
      case DioExceptionType.connectionError:
        message = 'No internet connection.';
        break;
      default:
        message = error.message ?? message;
    }

    return ApiFailure<T>(message: message);
  }
}
 */
