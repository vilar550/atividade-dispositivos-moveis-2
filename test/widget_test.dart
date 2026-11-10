import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leva_comigo/main.dart';
import 'package:leva_comigo/workspace.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('demonstração conclui a entrega e a remove do painel móvel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = await Workspace.load();
    addTearDown(store.dispose);
    await tester.pumpWidget(LevaComigo(workspace: store));
    await tester.pumpAndSettle();

    Future<void> tap(String label) async {
      final item = find.text(label);
      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pumpAndSettle();
    }

    await tap('Explorar demonstração');
    expect(find.text('Encomendas em andamento (1)'), findsOneWidget);
    await tap('Recife → Lisboa');
    await tap('Simular chegada');
    await tap('Confirmar recebimento');
    await tap('Confirmar');
    await tap('Avaliar entrega');
    await tester.tap(find.byTooltip('Nota geral: 5 de 5'));
    await tester.pumpAndSettle();
    await tap('Enviar avaliação');
    expect(find.textContaining('Avaliação: 5/5'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Encomendas em andamento (0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
