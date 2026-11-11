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
    theme: levaTheme(),
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
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(30, 28, 30, 22),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppBrand(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        padding: EdgeInsets.all(
                          constraints.maxWidth > 720 ? 35 : 24,
                        ),
                        decoration: BoxDecoration(
                          color: paper,
                          border: Border.all(color: line),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: ink.withValues(alpha: .05),
                              blurRadius: 50,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Eyebrow(switch (_mode) {
                              AccessMode.login => 'Bem-vindo de volta',
                              AccessMode.signup => 'Primeiro acesso',
                              AccessMode.recovery => 'Acesso à conta',
                            }),
                            const SizedBox(height: 10),
                            Text(
                              switch (_mode) {
                                AccessMode.login => 'Entre na sua conta',
                                AccessMode.signup => 'Crie sua conta',
                                AccessMode.recovery => 'Recupere seu acesso',
                              },
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _mode == AccessMode.recovery
                                  ? 'Use seu código de recuperação para definir uma nova senha.'
                                  : 'Acesse suas viagens e acompanhe suas encomendas.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 28),
                            if (_mode == AccessMode.signup) ...[
                              Entry('Nome', controller: _name),
                              const SizedBox(height: 16),
                            ],
                            Entry('E-mail', controller: _email, email: true),
                            const SizedBox(height: 16),
                            if (_mode == AccessMode.recovery) ...[
                              Entry('Código de recuperação', controller: _code),
                              const SizedBox(height: 16),
                            ],
                            Entry(
                              _mode == AccessMode.recovery
                                  ? 'Nova senha'
                                  : 'Senha',
                              controller: _password,
                              secret: true,
                              onSubmitted: _mode == AccessMode.login
                                  ? () => _submit()
                                  : null,
                            ),
                            if (_mode != AccessMode.login) ...[
                              const SizedBox(height: 16),
                              Entry(
                                'Confirmar senha',
                                controller: _confirmation,
                                secret: true,
                                onSubmitted: () => _submit(),
                              ),
                            ],
                            const SizedBox(height: 12),
                            if (_mode == AccessMode.login)
                              Row(
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 30,
                                    child: Checkbox(
                                      value: _remember,
                                      onChanged: _busy
                                          ? null
                                          : (value) => setState(
                                              () => _remember = value!,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  const Expanded(
                                    child: Text(
                                      'Lembrar sessão',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _switch(AccessMode.recovery),
                                    child: const Text(
                                      'Esqueci a senha',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _busy ? null : () => _submit(),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(switch (_mode) {
                                    AccessMode.login => 'Entrar',
                                    AccessMode.signup => 'Cadastrar',
                                    AccessMode.recovery => 'Redefinir senha',
                                  }),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.arrow_forward, size: 17),
                                ],
                              ),
                            ),
                            if (_mode == AccessMode.login) ...[
                              const SizedBox(height: 15),
                              const Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: Text(
                                      'ou',
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 15),
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _switch(AccessMode.signup),
                                child: const Text('Criar conta'),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _submit(demo: true),
                                child: const Text('Explorar demonstração'),
                              ),
                            ] else ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _switch(AccessMode.login),
                                child: const Text('Voltar ao login'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 30),
                  child: Text(
                    'Pequenas encomendas. Grandes conexões.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
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
  static const _labels = ['Início', 'Buscar', 'Viagens', 'Mensagens', 'Perfil'];
  static const _icons = [
    Icons.home_outlined,
    Icons.search,
    Icons.inventory_2_outlined,
    Icons.chat_bubble_outline,
    Icons.person_outline,
  ];

  Widget _sidebar(bool compact) => Container(
    width: compact ? 86 : 248,
    color: const Color(0xff191b18),
    padding: EdgeInsets.fromLTRB(compact ? 14 : 20, 32, compact ? 14 : 20, 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _tab = 0),
          child: AppBrand(compact: compact, dark: true),
        ),
        const SizedBox(height: 64),
        for (var index = 0; index < _labels.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Tooltip(
              message: _labels[index],
              child: Material(
                color: _tab == index
                    ? const Color(0xff2c2f2a)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => setState(() => _tab = index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 13,
                    ),
                    child: Row(
                      mainAxisAlignment: compact
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        Icon(
                          _icons[index],
                          size: 20,
                          color: _tab == index
                              ? Colors.white
                              : const Color(0xffaeb1aa),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              _labels[index],
                              style: TextStyle(
                                color: _tab == index
                                    ? Colors.white
                                    : const Color(0xffaeb1aa),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                        if (!compact &&
                            index == 2 &&
                            store.mine.any((s) => !s.status.terminal))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${store.mine.where((s) => !s.status.terminal).length}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
        if (!compact)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xff393c36)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, color: accent, size: 22),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ambiente seguro',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Acompanhe cada etapa da sua encomenda.',
                        style: TextStyle(
                          color: Color(0xff999c95),
                          fontSize: 10,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        const Divider(color: Color(0xff343632), height: 1),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => setState(() => _tab = 4),
          child: Row(
            children: [
              IdentityAvatar(store.profile['name'] as String),
              if (!compact) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.profile['name'] as String,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'Ver meu perfil',
                        style: TextStyle(
                          color: Color(0xff8d9089),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white, size: 17),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth > 720;
      final name = store.profile['name'] as String;
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              if (desktop) _sidebar(constraints.maxWidth <= 1000),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: desktop ? 94 : 68,
                      padding: EdgeInsets.symmetric(
                        horizontal: desktop ? 40 : 18,
                      ),
                      decoration: const BoxDecoration(
                        color: paper,
                        border: Border(bottom: BorderSide(color: line)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (desktop) ...[
                                  const Eyebrow('Leva Comigo'),
                                  const SizedBox(height: 4),
                                ],
                                Text(
                                  _labels[_tab],
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                          ),
                          if (store.profile['notifications'] == true)
                            IconButton.outlined(
                              tooltip: 'Notificações',
                              style: IconButton.styleFrom(
                                side: const BorderSide(color: line),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              icon: Badge(
                                isLabelVisible: store.mine.any(store.isUnread),
                                backgroundColor: accent,
                                child: const Icon(
                                  Icons.notifications_outlined,
                                  size: 20,
                                ),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NotificationsPage(store),
                                ),
                              ),
                            ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () => setState(() => _tab = 4),
                            child: Row(
                              children: [
                                IdentityAvatar(name, size: 34),
                                if (desktop) ...[
                                  const SizedBox(width: 10),
                                  Text(
                                    name.split(' ').first,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
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
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: desktop
            ? null
            : NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (index) => setState(() => _tab = index),
                destinations: [
                  for (var i = 0; i < _labels.length; i++)
                    NavigationDestination(
                      icon: Icon(_icons[i], size: 21),
                      label: _labels[i],
                    ),
                ],
              ),
      );
    },
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
        Eyebrow('Olá, ${(store.profile['name'] as String).split(' ').first}'),
        Text(
          'O que você deseja fazer hoje?',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const Text(
          'Envie sua encomenda ou aproveite sua próxima viagem.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 6),
        ResponsiveRow(
          children: [
            _ActionCard(
              dark: true,
              title: 'Enviar uma\nencomenda',
              label: 'Quero enviar',
              description:
                  'Encontre alguém que já vai viajar para o destino da sua encomenda.',
              icon: Icons.inventory_2_outlined,
              button: 'Buscar viagem',
              onPressed: onSearch,
            ),
            _ActionCard(
              dark: false,
              title: 'Oferecer espaço\nna bagagem',
              label: 'Quero transportar',
              description:
                  'Você vai viajar? Ganhe uma renda extra levando pequenas encomendas.',
              icon: Icons.flight_takeoff_outlined,
              button: 'Publicar viagem',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TripFormPage(store)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Eyebrow('Em andamento'),
        Heading('Encomendas em andamento (${active.length})'),
        if (active.isEmpty)
          const Panel(
            children: [
              Text(
                'Você ainda não tem encomendas em andamento.',
                style: TextStyle(color: muted),
              ),
            ],
          ),
        for (final shipment in active.take(3)) ShipmentTile(store, shipment),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onTrips,
            child: const Text('Ver viagens e histórico →'),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.dark,
    required this.title,
    required this.label,
    required this.description,
    required this.icon,
    required this.button,
    required this.onPressed,
  });
  final bool dark;
  final String title;
  final String label;
  final String description;
  final IconData icon;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: dark ? ink : paper,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: dark ? ink : line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: dark ? accent : Colors.transparent,
                border: dark
                    ? null
                    : Border.all(color: const Color(0xffc5c7c0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: ink, size: 28),
            ),
            const Spacer(),
            Eyebrow(label, color: dark ? const Color(0xff9b9e96) : muted),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -1,
            color: dark ? Colors.white : ink,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: TextStyle(
            color: dark ? const Color(0xff9fa29b) : muted,
            fontSize: 12,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 22),
        if (dark)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: ink,
            ),
            onPressed: onPressed,
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(button),
          )
        else
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(button),
          ),
      ],
    ),
  );
}
