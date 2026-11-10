import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'domain.dart';
import 'market.dart';
import 'profile.dart';
import 'shipments.dart';
import 'ui.dart';
import 'workspace.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LevaComigo());
}

class LevaComigo extends StatefulWidget {
  const LevaComigo({super.key, this.workspace});
  final Workspace? workspace;

  @override
  State<LevaComigo> createState() => _LevaComigoState();
}

class _LevaComigoState extends State<LevaComigo> {
  late Future<Workspace> _workspace = _load();
  Workspace? _ownedWorkspace;

  Future<Workspace> _load() async {
    if (widget.workspace case final Workspace workspace) return workspace;
    final workspace = await Workspace.load();
    if (!mounted) {
      workspace.dispose();
    } else {
      _ownedWorkspace = workspace;
    }
    return workspace;
  }

  @override
  void dispose() {
    _ownedWorkspace?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LevaComigo',
    debugShowCheckedModeBanner: false,
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff567b10),
        surface: const Color(0xfffbfcf6),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: const CardThemeData(elevation: 0, color: Color(0xffeef0e6)),
    ),
    home: FutureBuilder(
      future: _workspace,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: AppPage(
              children: [
                const Heading(
                  'Não foi possível abrir o LevaComigo',
                  subtitle:
                      'Confira se o armazenamento do aplicativo está disponível.',
                ),
                FilledButton(
                  onPressed: () => setState(() => _workspace = _load()),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }
        final store = snapshot.data;
        if (store == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return ListenableBuilder(
          listenable: store,
          builder: (context, _) => store.email == null
              ? SignInPage(store)
              : Dashboard(key: ValueKey(store.email), store: store),
        );
      },
    ),
  );
}

enum AccessMode { login, signup, recovery }

class SignInPage extends StatefulWidget {
  const SignInPage(this.store, {super.key});
  final Workspace store;
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _code = TextEditingController();
  AccessMode _mode = AccessMode.login;
  bool _remember = true;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _confirmation, _code]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _switch(AccessMode mode) => setState(() {
    _mode = mode;
    _password.clear();
    _confirmation.clear();
    _code.clear();
  });

  Future<void> _submit({bool demo = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await perform(context, () async {
        final store = widget.store;
        if (demo || _mode == AccessMode.login) {
          await store.signIn(
            demo ? demoEmail : _email.text,
            demo ? '123456' : _password.text,
            _remember,
          );
          return;
        }
        if (_password.text != _confirmation.text) {
          throw const RuleError('As senhas precisam ser iguais.');
        }
        if (_mode == AccessMode.signup) {
          final code = await store.signUp(
            _name.text,
            _email.text,
            _password.text,
          );
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Guarde seu código de recuperação'),
              content: SelectableText(code),
              actions: [
                TextButton(
                  onPressed: () async {
                    try {
                      await FilePicker.platform.saveFile(
                        fileName: 'levacomigo-recuperacao.txt',
                        bytes: utf8.encode(code),
                      );
                    } on PlatformException {
                      if (context.mounted) {
                        notice(
                          context,
                          'Selecione e copie o código para guardá-lo.',
                        );
                      }
                    }
                  },
                  child: const Text('Salvar código'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Concluir cadastro'),
                ),
              ],
            ),
          );
        } else {
          await store.recover(_email.text, _code.text, _password.text);
          if (mounted) {
            notice(context, 'Senha atualizada. Entre com a nova senha.');
          }
        }
        if (mounted) _switch(AccessMode.login);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: AppPage(
        children: [
          const Icon(Icons.route, size: 54, color: Color(0xff567b10)),
          const Text(
            'LevaComigo',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Encontre espaço na bagagem de quem já vai viajar.',
            textAlign: TextAlign.center,
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Panel(
                children: [
                  Heading(switch (_mode) {
                    AccessMode.login => 'Entre na sua conta',
                    AccessMode.signup => 'Crie sua conta',
                    AccessMode.recovery => 'Recupere seu acesso',
                  }),
                  if (_mode == AccessMode.signup)
                    Entry('Nome', controller: _name),
                  Entry('E-mail', controller: _email, email: true),
                  if (_mode == AccessMode.recovery)
                    Entry('Código de recuperação', controller: _code),
                  Entry(
                    _mode == AccessMode.recovery ? 'Nova senha' : 'Senha',
                    controller: _password,
                    secret: true,
                    onSubmitted: _mode == AccessMode.login
                        ? () => _submit()
                        : null,
                  ),
                  if (_mode != AccessMode.login)
                    Entry(
                      'Confirmar senha',
                      controller: _confirmation,
                      secret: true,
                      onSubmitted: () => _submit(),
                    ),
                  if (_mode == AccessMode.login)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _remember,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _remember = value!),
                      title: const Text('Lembrar sessão'),
                    ),
                  FilledButton(
                    onPressed: _busy ? null : () => _submit(),
                    child: Text(switch (_mode) {
                      AccessMode.login => 'Entrar',
                      AccessMode.signup => 'Cadastrar',
                      AccessMode.recovery => 'Redefinir senha',
                    }),
                  ),
                  if (_mode == AccessMode.login) ...[
                    OutlinedButton(
                      onPressed: _busy ? null : () => _submit(demo: true),
                      child: const Text('Explorar demonstração'),
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _switch(AccessMode.signup),
                          child: const Text('Criar conta'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _switch(AccessMode.recovery),
                          child: const Text('Esqueci a senha'),
                        ),
                      ],
                    ),
                  ] else
                    TextButton(
                      onPressed: _busy ? null : () => _switch(AccessMode.login),
                      child: const Text('Voltar ao login'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required this.store});
  final Workspace store;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _tab = 0;
  Workspace get store => widget.store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'LevaComigo',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      leading: const Icon(Icons.route),
      actions: [
        if (store.profile['notifications'] == true)
          IconButton(
            tooltip: 'Notificações',
            icon: Badge(
              isLabelVisible: store.mine.any(store.isUnread),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NotificationsPage(store)),
            ),
          ),
      ],
    ),
    body: SafeArea(
      child: switch (_tab) {
        0 => HomePage(
          store,
          onSearch: () => setState(() => _tab = 1),
          onTrips: () => setState(() => _tab = 2),
        ),
        1 => SearchPage(store),
        2 => ShipmentsPage(store),
        3 => ChatListPage(store),
        _ => ProfilePage(store),
      },
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (index) => setState(() => _tab = index),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Início'),
        NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Viagens',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Mensagens',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Perfil',
        ),
      ],
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage(
    this.store, {
    super.key,
    required this.onSearch,
    required this.onTrips,
  });
  final Workspace store;
  final VoidCallback onSearch;
  final VoidCallback onTrips;

  @override
  Widget build(BuildContext context) {
    final active = store.mine.where((s) => !s.status.terminal);
    return AppPage(
      children: [
        Heading(
          'Olá, ${(store.profile['name'] as String).split(' ').first}!',
          subtitle:
              'Envie uma encomenda ou ofereça espaço na sua próxima viagem.',
        ),
        Panel(
          children: [
            FilledButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search),
              label: const Text('Buscar viagem'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TripFormPage(store)),
              ),
              icon: const Icon(Icons.flight_takeoff),
              label: const Text('Publicar viagem'),
            ),
          ],
        ),
        Heading('Encomendas em andamento (${active.length})'),
        if (active.isEmpty)
          const Text('Você ainda não tem encomendas em andamento.'),
        for (final shipment in active.take(3)) ShipmentTile(store, shipment),
        TextButton(
          onPressed: onTrips,
          child: const Text('Ver viagens e histórico'),
        ),
      ],
    );
  }
}
