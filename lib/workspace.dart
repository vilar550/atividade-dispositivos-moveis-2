import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain.dart';
import 'legacy_stub.dart' if (dart.library.js_interop) 'legacy_web.dart';

class Workspace extends ChangeNotifier {
  Workspace._(this._preferences, this._data, this._email);

  static const storageKey = 'workspace.flutter.v1';
  final SharedPreferencesAsync _preferences;
  Json _data;
  String? _email;
  bool _saving = false;
  VoidCallback? _unwatch;

  static Future<Workspace> load({SharedPreferencesAsync? preferences}) async {
    final storage = preferences ?? SharedPreferencesAsync();
    final raw = await storage.getString(storageKey);
    final data = raw == null ? readLegacyData() : jsonDecode(raw) as Json;
    for (final key in [
      'accounts',
      'trips',
      'shipments',
      'reviews',
      'messages',
    ]) {
      data.putIfAbsent(key, () => <Json>[]);
    }
    for (final key in ['profiles', 'readAt']) {
      data.putIfAbsent(key, () => <String, dynamic>{});
    }
    final store = Workspace._(storage, data, data['session']);
    await store._commit((draft) {
      final samples = [
        (
          'T-MARIA',
          'sample-maria',
          'Maria Silva',
          cities[0],
          cities[1],
          7,
          40,
          4.9,
          'Pequenos eletrônicos e documentos. Retirada e entrega a combinar.',
        ),
        (
          'T-RAFAEL',
          'sample-rafael',
          'Rafael Costa',
          cities[2],
          cities[3],
          3,
          35,
          4.7,
          'Itens na embalagem original.',
        ),
      ];
      for (final (
            id,
            owner,
            name,
            origin,
            destination,
            space,
            price,
            rating,
            notes,
          )
          in samples) {
        final row = _rows(
          draft,
          'trips',
        ).where((trip) => trip['id'] == id).firstOrNull;
        if (row == null) {
          _rows(draft, 'trips').add({
            'id': id,
            'ownerId': owner,
            'name': name,
            'origin': origin,
            'destination': destination,
            'date': day(DateTime.now().add(const Duration(days: 3))),
            'space': space,
            'price': price,
            'rating': rating,
            'notes': notes,
            'active': true,
          });
        } else if (row['active'] == true &&
            (row['date'] as String).compareTo(today()) < 0) {
          row['date'] = day(DateTime.now().add(const Duration(days: 3)));
        }
      }
      final progress = draft.remove('legacyProgress');
      if (progress is Json &&
          !_rows(draft, 'shipments').any((row) => row['id'] == 'BG28491')) {
        _seedDemo(draft, progress);
      }
      for (final trip in _rows(draft, 'trips').map(Trip.new)) {
        _finishTrip(draft, trip);
      }
    });
    store._unwatch = watchStorage(storageKey, (raw) {
      if (store._saving) return;
      store._data = jsonDecode(raw) as Json;
      store.notifyListeners();
    });
    return store;
  }

  @override
  void dispose() {
    _unwatch?.call();
    super.dispose();
  }

  String? get email => _email;
  String get user => _email!;
  Json get profile => (_data['profiles'] as Json)[user] as Json;
  List<Trip> get trips => _rows(_data, 'trips').map(Trip.new).toList();
  List<Trip> get myTrips =>
      trips.where((trip) => trip.ownerId == user).toList();
  List<Shipment> get shipments => _shipments(_data);
  List<Shipment> get mine => shipments
      .where(
        (shipment) =>
            shipment.senderId == user || trip(shipment.tripId).ownerId == user,
      )
      .toList()
      .reversed
      .toList();

  Trip trip(String id) => _trip(_data, id);
  Shipment? shipment(String id) =>
      mine.where((shipment) => shipment.id == id).firstOrNull;
  List<Json> messages(String id) => shipment(id) == null
      ? []
      : _rows(
          _data,
          'messages',
        ).where((row) => row['shipmentId'] == id).toList();
  Json? review(String id) => _rows(
    _data,
    'reviews',
  ).where((row) => row['shipmentId'] == id).firstOrNull;
  List<Json> receivedReviews(String owner) => _rows(_data, 'reviews')
      .where(
        (row) => shipments.any(
          (s) =>
              s.id == row['shipmentId'] &&
              s.status == Status.completed &&
              s.senderId != owner &&
              trip(s.tripId).ownerId == owner,
        ),
      )
      .toList();
  List<Json> get sentReviews => mine
      .where((s) => s.senderId == user)
      .map((s) => review(s.id))
      .nonNulls
      .toList();
  num rating(Trip trip) {
    final reviews = receivedReviews(trip.ownerId);
    return reviews.isEmpty
        ? trip.rating
        : reviews.fold<num>(0, (sum, row) => sum + (row['score'] as num)) /
              reviews.length;
  }

  bool isUnread(Shipment shipment) {
    final readAt = (_data['readAt'] as Json)[user] as String?;
    final read = readAt == null ? null : DateTime.tryParse(readAt);
    return read == null ||
        shipment.events.values.any((at) => DateTime.parse(at).isAfter(read));
  }

  Future<void> markRead() => _commit((draft) => draft['readAt'][user] = now());

  List<Trip> search(RouteQuery query) {
    query.validate();
    final allShipments = shipments;
    return trips
        .where(
          (trip) =>
              trip.active &&
              trip.ownerId != user &&
              normalizedCity(trip.origin) == normalizedCity(query.origin) &&
              normalizedCity(trip.destination) ==
                  normalizedCity(query.destination) &&
              trip.date == query.date &&
              trip.categories.contains(query.category) &&
              remaining(trip, allShipments) >= query.weight,
        )
        .toList();
  }

  Future<void> signIn(String email, String password, bool remember) async {
    email = email.trim().toLowerCase();
    if (email != demoEmail || password != '123456') {
      final account = _account(_data, email);
      if (account == null ||
          await _hash(password, account['salt']) != account['hash']) {
        throw const RuleError('E-mail ou senha incorretos.');
      }
    }
    await _startSession(email, remember);
  }

  Future<String> signUp(String name, String email, String password) async {
    email = email.trim().toLowerCase();
    name = name.trim();
    if (name.length < 3) throw const RuleError('Informe seu nome.');
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      throw const RuleError('Informe um e-mail válido.');
    }
    _validatePassword(password);
    final salt = randomCode(16);
    final recovery = randomCode(16);
    final hash = await _hash(password, salt);
    final recoveryHash = await _hash(recovery, salt);
    await _commit((draft) {
      if (email == demoEmail || _account(draft, email) != null) {
        throw const RuleError('Este e-mail já tem uma conta.');
      }
      _rows(draft, 'accounts').add({
        'name': name,
        'email': email,
        'salt': salt,
        'hash': hash,
        'recoveryHash': recoveryHash,
      });
    });
    return recovery;
  }

  Future<void> recover(String email, String code, String password) async {
    email = email.trim().toLowerCase();
    final account = _account(_data, email);
    if (account == null ||
        await _hash(code.trim(), account['salt']) != account['recoveryHash']) {
      throw const RuleError('E-mail ou código de recuperação inválido.');
    }
    await _setPassword(account, password);
  }

  Future<void> changePassword(String current, String password) async {
    final account = _account(_data, user);
    if (account == null ||
        await _hash(current, account['salt']) != account['hash']) {
      throw const RuleError('Senha atual incorreta.');
    }
    await _setPassword(account, password);
  }

  Future<void> _setPassword(Json account, String password) async {
    _validatePassword(password);
    final hash = await _hash(password, account['salt']);
    await _commit((draft) {
      final latest = _account(draft, account['email'])!;
      if (latest['hash'] != account['hash']) {
        throw const RuleError('A senha mudou. Tente novamente.');
      }
      latest['hash'] = hash;
    });
  }

  Future<void> _startSession(String email, bool remember) async {
    await _commit((draft) {
      final name = email == demoEmail
          ? 'João Silva'
          : _account(draft, email)!['name'];
      (draft['profiles'] as Json).putIfAbsent(
        email,
        () => {
          'name': name,
          'email': email,
          'city': cities.first,
          'phone': '',
          'notifications': true,
        },
      );
      if (email == demoEmail &&
          !_rows(draft, 'shipments').any((row) => row['id'] == 'BG28491')) {
        _seedDemo(draft, null);
      }
      draft['session'] = remember ? email : null;
    }, afterSave: () => _email = email);
  }

  Future<void> signOut() => _commit(
    (draft) => draft['session'] = null,
    afterSave: () => _email = null,
  );

  Future<void> saveProfile(
    String name,
    String phone,
    String city,
    bool notifications,
  ) => _commit((draft) {
    if (name.trim().length < 3) throw const RuleError('Informe seu nome.');
    final updated = draft['profiles'][user] as Json;
    updated.addAll({
      'name': name.trim(),
      'phone': phone.trim(),
      'city': city.trim(),
      'notifications': notifications,
    });
    for (final trip in _rows(
      draft,
      'trips',
    ).where((row) => row['ownerId'] == user)) {
      trip['name'] = name.trim();
    }
    for (final shipment in _rows(
      draft,
      'shipments',
    ).where((row) => row['senderId'] == user)) {
      shipment['sender'] = name.trim();
    }
  });

  Future<void> verifyIdentity(String status, [String? document]) => _commit((
    draft,
  ) {
    final profile = draft['profiles'][user] as Json;
    final previous = profile['verification'] as Json? ?? {};
    final current = previous['status'] ?? 'pending';
    final allowed = switch (current) {
      'pending' || 'rejected' =>
        status == 'review' && ['RG', 'CNH', 'Passaporte'].contains(document),
      'review' => ['approved', 'rejected'].contains(status),
      'approved' => status == 'pending',
      _ => false,
    };
    if (!allowed) throw const RuleError('Ação de verificação indisponível.');
    profile['verification'] = {
      if (status != 'pending') ...previous,
      'status': status,
      'updatedAt': now(),
      if (status == 'review') ...{
        'documentType': document,
        'submittedAt': now(),
      },
    };
  });

  Future<void> saveTrip(
    RouteQuery route,
    num price,
    List<String> categories,
    String notes, {
    String? id,
  }) => _commit((draft) {
    if (id == null) {
      route.validate();
    } else if (!validWeight(route.weight)) {
      throw const RuleError(
        'Informe uma capacidade entre 0,1 e 30 kg, com até três casas decimais.',
      );
    }
    if (!price.isFinite || price < 0.01 || price > 100000) {
      throw const RuleError(
        'Informe um preço por kg entre R\$ 0,01 e R\$ 100.000,00.',
      );
    }
    if (categories.isEmpty || !categories.every(itemTypes.contains)) {
      throw const RuleError('Selecione ao menos uma categoria.');
    }
    final fields = {
      'space': route.weight,
      'price': price,
      'notes': notes.trim(),
      'acceptedTypes': categories,
    };
    if (id == null) {
      _rows(draft, 'trips').add({
        'id': 'T-${randomCode(8)}',
        'ownerId': user,
        'name': profile['name'],
        'origin': route.origin.trim(),
        'destination': route.destination.trim(),
        'date': route.date,
        'rating': 0,
        'active': true,
        ...fields,
      });
    } else {
      final current = _ownedActiveTrip(draft, id);
      final related = _shipments(
        draft,
      ).where((s) => s.tripId == id && !s.status.terminal);
      if ((route.weight * 1000).round() <
          reservedGrams(current, _shipments(draft))) {
        throw const RuleError(
          'A capacidade deve cobrir as reservas existentes.',
        );
      }
      if (related.any((shipment) => !categories.contains(shipment.category))) {
        throw const RuleError(
          'Mantenha as categorias das encomendas em andamento.',
        );
      }
      current.data.addAll(fields);
    }
  });

  Future<void> closeTrip(String id) => _commit((draft) {
    final trip = _ownedActiveTrip(draft, id);
    trip.data['active'] = false;
  });

  Future<String> request(
    String tripId,
    String category,
    num weight,
    String description,
    num value, {
    bool sample = false,
  }) async {
    final id = 'BG${randomCode(6)}';
    await _commit((draft) {
      final trip = _trip(draft, tripId);
      final ownsTrip = trip.ownerId == user;
      if (ownsTrip != sample) {
        throw const RuleError('Você não pode solicitar sua própria viagem.');
      }
      if (!trip.active || trip.date.compareTo(today()) < 0) {
        throw const RuleError(
          'Esta viagem não está aceitando novas solicitações.',
        );
      }
      if (!validWeight(weight) || weight > remaining(trip, _shipments(draft))) {
        throw const RuleError(
          'Confira o peso e o espaço disponível para esta viagem.',
        );
      }
      if (!trip.categories.contains(category) ||
          description.trim().isEmpty ||
          !value.isFinite ||
          value < 0 ||
          value > 1000000) {
        throw const RuleError(
          'Informe uma categoria aceita, a descrição e um valor declarado válido.',
        );
      }
      final at = now();
      _rows(draft, 'shipments').add({
        'id': id,
        'tripId': tripId,
        'senderId': sample ? sampleSender : user,
        'sender': sample ? 'Ana Costa (exemplo)' : profile['name'],
        'itemType': category,
        'weight': weight,
        'description': description.trim(),
        'declaredValue': value,
        'price': (trip.price * weight * 100).round() / 100,
        'status': Status.pending.key,
        'createdAt': at,
        'events': {Status.pending.key: at},
      });
    });
    return id;
  }

  Future<void> advance(String id, Status next) => _commit((draft) {
    final shipment = _visibleShipment(draft, id);
    final trip = _trip(draft, shipment.tripId);
    if (!allowedActions(trip, shipment, user).contains(next)) {
      throw const RuleError('Esta etapa está indisponível para sua conta.');
    }
    final at = now();
    shipment.data['status'] = next.key;
    shipment.events[next.key] = at;
    _rows(draft, 'messages').add({
      'id': randomCode(8),
      'shipmentId': id,
      'text': 'Status atualizado: ${next.label}.',
      'at': at,
      'author': 'system',
    });
    _finishTrip(draft, trip);
  });

  Future<void> sendMessage(String id, String text) => _commit((draft) {
    _visibleShipment(draft, id);
    if (text.trim().isEmpty) throw const RuleError('Escreva uma mensagem.');
    _rows(draft, 'messages').add({
      'id': randomCode(8),
      'shipmentId': id,
      'text': text.trim(),
      'at': now(),
      'author': 'user',
      'authorId': user,
    });
  });

  Future<void> rate(
    String id,
    int score,
    Map<String, int> criteria,
    String comment,
  ) => _commit((draft) {
    final shipment = _visibleShipment(draft, id);
    if (shipment.senderId != user ||
        shipment.status != Status.completed ||
        _rows(draft, 'reviews').any((row) => row['shipmentId'] == id)) {
      throw const RuleError('Esta encomenda não pode ser avaliada novamente.');
    }
    if (score < 1 ||
        score > 5 ||
        criteria.entries.any(
          (entry) =>
              !reviewCriteria.contains(entry.key) ||
              entry.value < 1 ||
              entry.value > 5,
        )) {
      throw const RuleError('Escolha uma nota de 1 a 5.');
    }
    _rows(draft, 'reviews').add({
      'shipmentId': id,
      'score': score,
      'criteria': criteria,
      'comment': comment.trim(),
      'at': now(),
    });
  });

  String exportData() => const JsonEncoder.withIndent('  ').convert({
    'profile': profile,
    'trips': myTrips.map((trip) => trip.data).toList(),
    'shipments': mine.map((shipment) => shipment.data).toList(),
    'reviews': [...sentReviews, ...receivedReviews(user)],
    'messages': mine.expand((shipment) => messages(shipment.id)).toList(),
  });

  Future<void> _commit(
    void Function(Json) edit, {
    VoidCallback? afterSave,
  }) async {
    if (_saving) {
      throw const RuleError('Aguarde a operação atual e tente novamente.');
    }
    _saving = true;
    try {
      await withStorageLock(storageKey, () async {
        final latest = await _preferences.getString(storageKey);
        final draft = jsonDecode(latest ?? jsonEncode(_data)) as Json;
        edit(draft);
        try {
          await _preferences.setString(storageKey, jsonEncode(draft));
        } catch (_) {
          throw const RuleError(
            'Não foi possível salvar os dados neste dispositivo.',
          );
        }
        _data = draft;
        afterSave?.call();
        notifyListeners();
      });
    } finally {
      _saving = false;
    }
  }

  Trip _ownedActiveTrip(Json draft, String id) {
    final trip = _trip(draft, id);
    if (trip.ownerId != user || !trip.active) {
      throw const RuleError('Viagem indisponível para edição.');
    }
    return trip;
  }

  Shipment _visibleShipment(Json draft, String id) {
    final shipment = _shipments(
      draft,
    ).where((shipment) => shipment.id == id).firstOrNull;
    if (shipment == null ||
        (shipment.senderId != user &&
            _trip(draft, shipment.tripId).ownerId != user)) {
      throw const RuleError('Encomenda indisponível nesta conta.');
    }
    return shipment;
  }
}

List<Json> _rows(Json draft, String key) => (draft[key] as List).cast<Json>();
List<Shipment> _shipments(Json draft) =>
    _rows(draft, 'shipments').map(Shipment.new).toList();
Trip _trip(Json draft, String id) =>
    Trip(_rows(draft, 'trips').firstWhere((row) => row['id'] == id));
Json? _account(Json draft, String email) =>
    _rows(draft, 'accounts').where((row) => row['email'] == email).firstOrNull;

void _finishTrip(Json draft, Trip trip) {
  final related = _shipments(draft).where((s) => s.tripId == trip.id);
  final dates =
      related
          .where((s) => s.status == Status.completed)
          .map(
            (s) =>
                s.events[Status.completed.key] ?? s.data['createdAt'] as String,
          )
          .toList()
        ..sort();
  if (dates.isNotEmpty && related.every((s) => s.status.terminal)) {
    trip.data['active'] = false;
    trip.data['completedAt'] ??= dates.last;
  }
}

void _seedDemo(Json draft, Json? progress) {
  final trip = _trip(draft, 'T-MARIA');
  final at = now();
  final status = ['arrived', 'completed'].contains(progress?['status'])
      ? Status.parse(progress!['status'])
      : Status.inTransit;
  _rows(draft, 'shipments').add({
    'id': 'BG28491',
    'tripId': trip.id,
    'senderId': demoEmail,
    'sender': 'João Silva',
    'itemType': itemTypes.first,
    'weight': 2,
    'description': 'Fone de ouvido na embalagem original',
    'declaredValue': 800,
    'price': 80,
    'createdAt': at,
    'status': status.key,
    'events': {
      for (final step in [
        Status.pending,
        Status.accepted,
        Status.received,
        Status.inTransit,
      ])
        step.key: at,
      if (status.index >= Status.arrived.index)
        'arrived': progress?['arrivedAt'] ?? at,
      if (status == Status.completed)
        'completed': progress?['completedAt'] ?? at,
    },
  });
}

void _validatePassword(String password) {
  if (password.length < 6 || password.length > 128) {
    throw const RuleError('Use uma senha de 6 a 128 caracteres.');
  }
}

Future<String> _hash(String secret, String salt) async {
  final key = await Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000,
    bits: 256,
  ).deriveKeyFromPassword(password: secret, nonce: utf8.encode(salt));
  final bytes = await key.extractBytes();
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
