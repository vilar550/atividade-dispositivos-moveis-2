import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leva_comigo/domain.dart';
import 'package:leva_comigo/workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const traveler = 'maria@example.com';
const sender = 'lucas@example.com';
const stranger = 'ana@example.com';
const password = 'senha-academica';
const category = 'Documentos';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Workspace store;
  late RouteQuery route;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = await Workspace.load();
    route = RouteQuery(
      'Gravatá, Brasil',
      'Lisboa, Portugal',
      day(DateTime.now().add(const Duration(days: 1))),
      2.5,
      category,
    );
  });

  tearDown(() => store.dispose());

  Future<void> account(String name, String email) async {
    await store.signUp(name, email, password);
    await store.signIn(email, password, false);
  }

  test('duas contas completam a entrega, trocam mensagens e avaliam', () async {
    await account('Maria Silva', traveler);
    await store.saveTrip(route, 30, [category], 'Envelope');
    final tripId = store.myTrips.single.id;
    expect(store.search(route), isEmpty);
    await expectLater(
      store.request(tripId, category, 1, 'Meu item', 0),
      throwsA(isA<RuleError>()),
    );
    await store.signOut();

    await account('Lucas Vilar', sender);
    final query = RouteQuery('Gravata', 'Lisboa', route.date, 2.5, category);
    expect(store.search(query).single.id, tripId);
    expect(
      store.search(
        RouteQuery(query.origin, query.destination, query.date, 2.51, category),
      ),
      isEmpty,
    );
    expect(
      store.search(
        RouteQuery(query.origin, query.destination, query.date, 1, 'Livros'),
      ),
      isEmpty,
    );
    final shipmentId = await store.request(
      tripId,
      category,
      1.2,
      'Contrato',
      50,
    );
    expect(store.shipment(shipmentId)!.price, 36);
    expect(remaining(store.trip(tripId), store.shipments), 1.3);
    await store.sendMessage(shipmentId, 'Onde posso entregar?');
    await expectLater(
      store.advance(shipmentId, Status.accepted),
      throwsA(isA<RuleError>()),
    );
    await expectLater(
      store.rate(shipmentId, 5, {}, ''),
      throwsA(isA<RuleError>()),
    );
    await store.signOut();

    await account('Ana Costa', stranger);
    expect(store.shipment(shipmentId), isNull);
    await expectLater(
      store.sendMessage(shipmentId, 'Fora da conversa'),
      throwsA(isA<RuleError>()),
    );
    await store.signOut();

    await store.signIn(traveler, password, false);
    expect(store.mine.single.id, shipmentId);
    expect(store.messages(shipmentId).first['authorId'], sender);
    expect(store.isUnread(store.mine.single), isTrue);
    await store.markRead();
    expect(store.isUnread(store.mine.single), isFalse);
    await expectLater(
      store.advance(shipmentId, Status.arrived),
      throwsA(isA<RuleError>()),
    );
    for (final stage in [
      Status.accepted,
      Status.received,
      Status.inTransit,
      Status.arrived,
    ]) {
      await store.advance(shipmentId, stage);
    }
    await expectLater(
      store.advance(shipmentId, Status.completed),
      throwsA(isA<RuleError>()),
    );
    await store.signOut();

    await store.signIn(sender, password, true);
    await store.advance(shipmentId, Status.completed);
    await store.rate(shipmentId, 5, {'Comunicação': 4}, 'Chegou bem');
    await expectLater(
      store.rate(shipmentId, 1, {}, 'Duplicada'),
      throwsA(isA<RuleError>()),
    );
    expect(store.mine.where((s) => !s.status.terminal), isEmpty);
    expect(store.sentReviews.single['score'], 5);
    expect(store.trip(tripId).active, isFalse);

    final reloaded = await Workspace.load();
    addTearDown(reloaded.dispose);
    expect(reloaded.email, sender);
    expect(reloaded.mine.single.status, Status.completed);
    expect(reloaded.receivedReviews(traveler).single['comment'], 'Chegou bem');
    expect(reloaded.rating(reloaded.trip(tripId)), 5);
    expect(
      (jsonDecode(reloaded.exportData()) as Json)['shipments'],
      hasLength(1),
    );
  });

  test(
    'reservas decimais, edição, recusa, cancelamento e encerramento',
    () async {
      await account('Maria Silva', traveler);
      await store.saveTrip(route, 30, [category], '');
      final tripId = store.myTrips.single.id;
      final first = await store.request(
        tripId,
        category,
        1.201,
        'A',
        0,
        sample: true,
      );
      final second = await store.request(
        tripId,
        category,
        1.299,
        'B',
        0,
        sample: true,
      );
      expect(remaining(store.trip(tripId), store.shipments), 0);
      await expectLater(
        store.request(tripId, category, 0.1, 'C', 0, sample: true),
        throwsA(isA<RuleError>()),
      );
      final smaller = RouteQuery(
        route.origin,
        route.destination,
        route.date,
        2.49,
        category,
      );
      await expectLater(
        store.saveTrip(smaller, 25, [category], '', id: tripId),
        throwsA(isA<RuleError>()),
      );
      await store.advance(first, Status.refused);
      await store.advance(second, Status.accepted);
      await store.advance(second, Status.cancelled);
      expect(remaining(store.trip(tripId), store.shipments), 2.5);
      await store.saveTrip(smaller, 25, [category], 'Atualizada', id: tripId);
      expect(store.trip(tripId).price, 25);
      await store.closeTrip(tripId);
      expect(store.trip(tripId).active, isFalse);
      await expectLater(
        store.request(tripId, category, 1, 'Fechada', 0, sample: true),
        throwsA(isA<RuleError>()),
      );
    },
  );

  test(
    'cadastro, recuperação, perfil e verificação persistem por conta',
    () async {
      final code = await store.signUp('Lucas Vilar', sender, password);
      await expectLater(
        store.signUp('Lucas Vilar', sender, password),
        throwsA(isA<RuleError>()),
      );
      await expectLater(
        store.recover(sender, 'incorreto', 'senha-nova'),
        throwsA(isA<RuleError>()),
      );
      await store.recover(sender, code, 'senha-nova');
      await expectLater(
        store.signIn(sender, password, true),
        throwsA(isA<RuleError>()),
      );
      await store.signIn(sender, 'senha-nova', false);
      await store.changePassword('senha-nova', 'senha-final');
      await store.saveProfile(
        'Lucas da Silva',
        '81999999999',
        'Gravatá',
        false,
      );
      await store.verifyIdentity('review', 'CNH');
      await store.verifyIdentity('rejected');
      await store.verifyIdentity('review', 'RG');
      await store.verifyIdentity('approved');

      final reloaded = await Workspace.load(
        preferences: SharedPreferencesAsync(),
      );
      addTearDown(reloaded.dispose);
      expect(reloaded.email, isNull);
      await reloaded.signIn(sender, 'senha-final', true);
      expect(reloaded.profile['name'], 'Lucas da Silva');
      expect(reloaded.profile['notifications'], false);
      expect(reloaded.profile['verification']['status'], 'approved');
      await reloaded.signOut();
      await reloaded.signIn(demoEmail, '123456', true);
      expect(reloaded.profile['verification'], isNull);
      expect(reloaded.mine.single.id, 'BG28491');
    },
  );

  test('datas inválidas, peso fora do intervalo e rota igual', () {
    for (final invalid in [
      RouteQuery('Recife', 'Lisboa', '2090-02-31', 1, category),
      RouteQuery('Gravatá', 'Gravata', route.date, 1, category),
      RouteQuery('Recife', 'Lisboa', route.date, 0.01, category),
      RouteQuery('Recife', 'Lisboa', route.date, 1.0001, category),
      RouteQuery('Recife', 'Lisboa', route.date, double.nan, category),
    ]) {
      expect(invalid.validate, throwsA(isA<RuleError>()));
    }
    expect(decimal('1,25'), 1.25);
    expect(decimal('Infinity'), isNull);
  });
}
