import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart';

dynamic _read(String key) {
  try {
    return jsonDecode(window.localStorage.getItem(key) ?? 'null');
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> readLegacyData() {
  final storedAccounts = _read('leva:accounts');
  final accounts = storedAccounts is List ? storedAccounts : [];
  final emails = <String>{'teste@exemplo.com'};
  for (final account in accounts.whereType<Map<String, dynamic>>()) {
    final email = account['email'];
    if (email is String) emails.add(email);
  }
  final workspaces = [
    for (final email in emails) _read('leva:workspace:v2:$email'),
  ].whereType<Map<String, dynamic>>();
  final storedMarket = _read('leva:marketplace:v3');
  final market = storedMarket is Map<String, dynamic> ? storedMarket : null;
  final progress = _read('leva-comigo:delivery-progress');
  final data = <String, dynamic>{
    'accounts': accounts,
    'profiles': {
      for (final workspace in workspaces)
        if (workspace['profile'] case final Map<String, dynamic> profile)
          profile['email'] as String: profile,
    },
    'readAt': {
      for (final email in emails)
        if (_read('leva:read:$email') case final String value) email: value,
    },
    'legacyProgress': progress,
  };
  for (final key in ['trips', 'shipments', 'messages', 'reviews']) {
    final records = <String, Map<String, dynamic>>{};
    for (final source in [...workspaces, ?market]) {
      for (final row
          in (source[key] as List? ?? []).whereType<Map<String, dynamic>>()) {
        final id = row[key == 'reviews' ? 'shipmentId' : 'id'];
        if (id is String) records[id] = row;
      }
    }
    data[key] = records.values.toList();
  }
  return data;
}

Future<void> withStorageLock(String key, Future<void> Function() action) async {
  if (!window.isSecureContext ||
      !window.navigator.hasProperty('locks'.toJS).toDart) {
    await action();
    return;
  }
  Object? failure;
  StackTrace? trace;
  Future<JSAny?> run() async {
    try {
      await action();
    } catch (error, stackTrace) {
      failure = error;
      trace = stackTrace;
    }
    return null;
  }

  await window.navigator.locks
      .request(key, ((JSAny? _) => run().toJS).toJS)
      .toDart;
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
}

void Function() watchStorage(
  String key,
  void Function(String value) onChanged,
) {
  final listener = ((StorageEvent event) {
    if (event.key != key) return;
    if (event.newValue case final String raw) {
      final value = jsonDecode(raw);
      if (value is String) onChanged(value);
    }
  }).toJS;
  window.addEventListener('storage', listener);
  return () => window.removeEventListener('storage', listener);
}
