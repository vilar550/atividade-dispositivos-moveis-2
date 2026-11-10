# LevaComigo

Aplicativo Flutter em Dart com suporte a Android e web.

- `lib/main.dart` inicializa o aplicativo e define as telas de acesso e o painel.
- `lib/domain.dart` define as regras de rota, capacidade e etapas de entrega.
- `lib/workspace.dart` aplica as regras e persiste os dados locais.
- `lib/market.dart`, `lib/shipments.dart` e `lib/profile.dart` contêm as telas dos fluxos.
- `test/` cobre as regras do aplicativo e a demonstração em tela móvel.

Use `dart format lib test`, `flutter analyze` e `flutter test` para verificar alterações em Dart.
