import 'package:flutter/material.dart';
import 'package:flutter_setup_riverpod/core/router/app_router_delegate.dart';

extension NavigatorExtension on BuildContext {
  /// Mendapatkan instance AppRouterDelegate dari BuildContext
  AppRouterDelegate get _appRouter {
    final delegate = Router.of(this).routerDelegate;
    assert(
      delegate is AppRouterDelegate,
      'Router delegate is not AppRouterDelegate',
    );
    return delegate as AppRouterDelegate;
  }

  /// Menambahkan route baru ke dalam stack (Navigator.push)
  void push(String path, {Map<String, dynamic>? extra}) =>
      _appRouter.push(path, extra: extra);

  /// Menggantikan route saat ini dengan route baru (Navigator.pushReplacement)
  void replace(String path, {Map<String, dynamic>? extra}) =>
      _appRouter.replace(path, extra: extra);

  /// Membersihkan seluruh stack navigasi dan menggantinya dengan route baru
  void replaceAll(String path, {Map<String, dynamic>? extra}) =>
      _appRouter.replaceAll(path, extra: extra);

  /// Pindah ke route baru sambil menghapus route lama hingga kondisi [predicate] terpenuhi
  void pushAndRemoveUntil(
    String path,
    bool Function(Page<dynamic> page) predicate, {
    Map<String, dynamic>? extra,
  }) => _appRouter.pushAndRemoveUntil(path, predicate, extra: extra);

  /// Kembali ke route sebelumnya (Navigator.pop)
  void pop() => _appRouter.pop();

  /// Kembali ke route sebelumnya jika memungkinkan
  bool maybePop() => _appRouter.maybePop();

  /// Mengecek apakah stack navigasi bisa melakukan pop
  bool canPop() => _appRouter.canPop();

  /// Kembali pop secara berturut-turut hingga kondisi [predicate] terpenuhi
  void popUntil(bool Function(Page<dynamic> page) predicate) =>
      _appRouter.popUntil(predicate);

  /// Kembali pop secara berturut-turut sampai menemukan path route yang spesifik
  void popUntilPath(String path) => _appRouter.popUntilPath(path);
}
