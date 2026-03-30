// * Uncomment kalo dibutuhin
/* sealed class ApiResult<T> {
  const ApiResult();

  factory ApiResult.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    final isSuccess = json['success'] as bool? ?? false;

    if (!isSuccess) {
      return ApiFailure.fromJson(json);
    }

    if (json.containsKey('meta') && json['meta'] != null) {
      return ApiCursorSuccess.fromJson(json, fromJsonT);
    }

    return ApiSuccess.fromJson(json, fromJsonT);
  }
}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  final String message;

  const ApiSuccess({required this.data, required this.message});

  factory ApiSuccess.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    return ApiSuccess(
      data: fromJsonT(json['data']),
      message: json['message'] as String? ?? 'Success',
    );
  }
}

class ApiCursorSuccess<T> extends ApiResult<T> {
  final List<T> items;
  final CursorMeta meta;
  final String message;

  const ApiCursorSuccess({
    required this.items,
    required this.meta,
    required this.message,
  });

  factory ApiCursorSuccess.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    return ApiCursorSuccess(
      items: (json['data'] as List<dynamic>).map((e) => fromJsonT(e)).toList(),
      meta: CursorMeta.fromJson(json['meta'] as Map<String, dynamic>),
      message: json['message'] as String? ?? 'Success',
    );
  }
}

class ApiFailure<T> extends ApiResult<T> {
  final String message;
  final dynamic errors;

  const ApiFailure({required this.message, this.errors});

  factory ApiFailure.fromJson(Map<String, dynamic> json) {
    return ApiFailure(
      message: json['message'] as String? ?? 'Something went wrong',
      errors: json['errors'],
    );
  }
}

class CursorMeta {
  final int perPage;
  final String? nextCursor;
  final String? prevCursor;
  final bool hasMore;

  const CursorMeta({
    required this.perPage,
    this.nextCursor,
    this.prevCursor,
    required this.hasMore,
  });

  factory CursorMeta.fromJson(Map<String, dynamic> json) {
    return CursorMeta(
      perPage: json['per_page'] as int? ?? 15,
      nextCursor: json['next_cursor'] as String?,
      prevCursor: json['prev_cursor'] as String?,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}
 */
