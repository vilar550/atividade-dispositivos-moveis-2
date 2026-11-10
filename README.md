# LevaComigo

O LevaComigo é um projeto da disciplina de Dispositivos Móveis feito em Flutter e Dart. A ideia é aproveitar o espaço livre na bagagem de quem já vai viajar para transportar pequenas encomendas.

# Grupo

Alunos: Lucas vilar do nascimento nunes, José kayo e Gabriel Rodrigues

## Como rodar

Com Flutter 3.41 ou mais recente, abra o terminal na raiz do projeto:

```sh
flutter pub get
flutter run -d chrome
```

Para testar no Android, abra um emulador no Android Studio ou conecte um celular com depuração USB. Rode `flutter devices` para ver o ID e use `flutter run -d ID_DO_DISPOSITIVO`.

## Como testar a entrega

- Para ver o fluxo mais rápido, clique em **Explorar demonstração**. Abra a encomenda Recife → Lisboa, use **Simular chegada**, confirme o recebimento e avalie. A encomenda sai do painel e aparece no histórico.
- Para testar os dois papéis, crie duas contas na mesma instalação. Na conta do viajante, publique uma viagem. Na do remetente, busque a mesma rota e data, envie uma solicitação e abra a conversa. Volte à conta do viajante para aceitar, registrar a coleta, iniciar a viagem e registrar a chegada. Na conta do remetente, confirme o recebimento e avalie.

O cadastro fornece um código de recuperação de senha. Guarde esse código se quiser testar a recuperação depois.

## Onde ficam os dados

Os dados ficam no próprio aplicativo ou no navegador. Para testar com duas contas, troque de conta no mesmo dispositivo e, na web, mantenha o mesmo endereço. Se a versão React já foi usada naquele endereço, a versão Flutter importa os dados locais na primeira abertura. Entre novamente com suas credenciais.

Mensagens e notificações funcionam dentro do protótipo. A verificação de identidade é simulada. O aplicativo exibe o preço combinado, e o acompanhamento depende dos registros do viajante e do remetente.

## Testes

```sh
flutter analyze
flutter test
flutter build web
```
