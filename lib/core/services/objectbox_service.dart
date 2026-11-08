import 'package:kawai_notes/core/utils/logger.dart';
import 'package:kawai_notes/objectbox.g.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Thrown when the store is accessed while a backup restore swaps it.
class StoreRestoringException implements Exception {
  const StoreRestoringException();

  @override
  String toString() => 'StoreRestoringException: database is being restored';
}

class ObjectBoxService {
  Store _store;
  bool _restoring = false;
  final List<Future<void> Function()> _quiesceHooks = [];

  ObjectBoxService._init(this._store);

  /// Wraps an already-open [Store] (e.g. a temp test store) without touching disk.
  ObjectBoxService.forTesting(this._store);

  /// The live store. Throws [StoreRestoringException] while a restore holds
  /// it, so racing writers fail cleanly instead of using a closed store.
  Store get store {
    if (_restoring) throw const StoreRestoringException();
    return _store;
  }

  bool get isRestoring => _restoring;

  /// Registers work (flush pending saves, cancel timers) that must finish
  /// before the store is closed for a restore.
  void addQuiesceHook(Future<void> Function() hook) => _quiesceHooks.add(hook);

  void removeQuiesceHook(Future<void> Function() hook) =>
      _quiesceHooks.remove(hook);

  static Future<ObjectBoxService> create() async {
    final store = await openStore(directory: await _storePath());
    return ObjectBoxService._init(store);
  }

  static Future<String> _storePath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return p.join(docsDir.path, 'notes_db');
  }

  /// Runs quiesce hooks, then gives [swap] exclusive ownership of the store:
  /// every other access throws until it finishes. The store is always
  /// reopened afterwards, even if [swap] fails.
  Future<T> runExclusive<T>(Future<T> Function() swap) async {
    if (_restoring) throw const StoreRestoringException();
    for (final hook in List.of(_quiesceHooks)) {
      try {
        await hook();
      } catch (e, stack) {
        AppLogger.instance.error('Store quiesce hook failed', e, stack);
      }
    }
    _restoring = true;
    try {
      return await swap();
    } finally {
      try {
        if (_store.isClosed()) await restartStore();
      } finally {
        _restoring = false;
      }
    }
  }

  /// The store for the owner of [runExclusive]; bypasses the restore guard.
  Store get exclusiveStore => _store;

  void closeStore() {
    if (!_store.isClosed()) _store.close();
  }

  Future<void> restartStore() async {
    closeStore();
    _store = await openStore(directory: await _storePath());
  }
}
