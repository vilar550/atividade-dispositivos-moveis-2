Map<String, dynamic> readLegacyData() => {};

Future<void> withStorageLock(String key, Future<void> Function() action) =>
    action();

void Function() watchStorage(
  String key,
  void Function(String value) onChanged,
) => () {};
