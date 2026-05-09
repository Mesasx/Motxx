import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  Box get cache => Hive.box('cache');
  Box get settings => Hive.box('settings');

  T? get<T>(String key, {String boxName = 'cache'}) {
    final box = Hive.box(boxName);
    return box.get(key) as T?;
  }

  Future<void> set(String key, dynamic value,
      {String boxName = 'cache'}) async {
    final box = Hive.box(boxName);
    await box.put(key, value);
  }

  Future<void> remove(String key, {String boxName = 'cache'}) async {
    final box = Hive.box(boxName);
    await box.delete(key);
  }
}
