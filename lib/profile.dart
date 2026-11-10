import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'domain.dart';
import 'shipments.dart';
import 'ui.dart';
import 'workspace.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage(this.store, {super.key});
  final Workspace store;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Workspace get store => widget.store;
  late final _name = TextEditingController(text: store.profile['name']);
  late final _phone = TextEditingController(text: store.profile['phone']);
  late final _city = TextEditingController(text: store.profile['city']);
  late bool _notifications = store.profile['notifications'] == true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
    children: [
      Heading('Meu perfil', subtitle: store.user),
      Panel(
        children: [
          Entry('Nome', controller: _name),
          Entry('Telefone', controller: _phone),
          Entry('Cidade', controller: _city),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Exibir notificações'),
            value: _notifications,
            onChanged: (value) => setState(() => _notifications = value),
          ),
          FilledButton(
            onPressed: () => perform(context, () async {
              await store.saveProfile(
                _name.text,
                _phone.text,
                _city.text,
                _notifications,
              );
              if (context.mounted) notice(context, 'Perfil atualizado.');
            }),
            child: const Text('Salvar perfil'),
          ),
        ],
      ),
      Panel(
        children: [
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Histórico'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HistoryPage(store)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Reputação'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReputationPage(store)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Verificação de identidade'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => VerificationPage(store)),
            ),
          ),
          if (store.user != demoEmail)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Alterar senha'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PasswordPage(store)),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Exportar dados em JSON'),
            onTap: () async {
              try {
                await FilePicker.platform.saveFile(
                  fileName: 'levacomigo.json',
                  bytes: utf8.encode(store.exportData()),
                );
              } on PlatformException {
                if (context.mounted) {
                  notice(context, 'Não foi possível exportar os dados.');
                }
              }
            },
          ),
        ],
      ),
      OutlinedButton.icon(
        onPressed: () => perform(context, store.signOut),
        icon: const Icon(Icons.logout),
        label: const Text('Sair da conta'),
      ),
    ],
  );
}

class PasswordPage extends StatefulWidget {
  const PasswordPage(this.store, {super.key});
  final Workspace store;

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await perform(context, () async {
      if (_new.text != _confirmation.text) {
        throw const RuleError('As senhas precisam ser iguais.');
      }
      await widget.store.changePassword(_current.text, _new.text);
      if (mounted) {
        Navigator.pop(context);
        notice(context, 'Senha atualizada.');
      }
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Alterar senha')),
    body: AppPage(
      children: [
        Panel(
          children: [
            Entry('Senha atual', controller: _current, secret: true),
            Entry('Nova senha', controller: _new, secret: true),
            Entry(
              'Confirmar nova senha',
              controller: _confirmation,
              secret: true,
            ),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Salvar senha'),
            ),
          ],
        ),
      ],
    ),
  );
}

class VerificationPage extends StatefulWidget {
  const VerificationPage(this.store, {super.key});
  final Workspace store;

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  String _document = 'RG';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verificação de identidade')),
    body: ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final verification =
            widget.store.profile['verification'] as Json? ?? {};
        final status = verification['status'] ?? 'pending';
        return AppPage(
          children: [
            const Heading(
              'Verificação simulada',
              subtitle:
                  'Para a demonstração, selecione somente o tipo de documento.',
            ),
            Panel(
              children: [
                Heading(switch (status) {
                  'review' => 'Em análise',
                  'approved' => 'Aprovada',
                  'rejected' => 'Reprovada',
                  _ => 'Pendente',
                }),
                if (verification['documentType'] case final String document)
                  Text('Documento: $document'),
                if (verification['updatedAt'] case final String at)
                  Text('Atualizada em ${timeLabel(at)}'),
                if (status == 'pending' || status == 'rejected') ...[
                  Choice(
                    'Tipo de documento',
                    value: _document,
                    options: const ['RG', 'CNH', 'Passaporte'],
                    onChanged: (value) => setState(() => _document = value),
                  ),
                  FilledButton(
                    onPressed: () => perform(
                      context,
                      () => widget.store.verifyIdentity('review', _document),
                    ),
                    child: const Text('Solicitar análise'),
                  ),
                ],
                if (status == 'review') ...[
                  OutlinedButton(
                    onPressed: () => perform(
                      context,
                      () => widget.store.verifyIdentity('approved'),
                    ),
                    child: const Text('Simular aprovação'),
                  ),
                  OutlinedButton(
                    onPressed: () => perform(
                      context,
                      () => widget.store.verifyIdentity('rejected'),
                    ),
                    child: const Text('Simular reprovação'),
                  ),
                ],
                if (status == 'approved')
                  TextButton(
                    onPressed: () => perform(
                      context,
                      () => widget.store.verifyIdentity('pending'),
                    ),
                    child: const Text('Reiniciar simulação'),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

class HistoryPage extends StatelessWidget {
  const HistoryPage(this.store, {super.key});
  final Workspace store;

  @override
  Widget build(BuildContext context) {
    final completed = store.mine
        .where((s) => s.status == Status.completed)
        .toList();
    final trips = store.myTrips.where(
      (trip) => trip.data['completedAt'] != null,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: AppPage(
        children: [
          for (final (role, items) in [
            (
              'Como remetente',
              completed.where((s) => s.senderId == store.user),
            ),
            ('Como viajante', completed.where((s) => s.senderId != store.user)),
          ]) ...[
            Heading(role),
            if (items.isEmpty) const Text('Nenhuma entrega concluída.'),
            for (final item in items) ShipmentTile(store, item),
          ],
          const Heading('Viagens concluídas'),
          if (trips.isEmpty) const Text('Nenhuma viagem concluída.'),
          for (final trip in trips)
            Panel(
              children: [
                Text('${city(trip.origin)} → ${city(trip.destination)}'),
                Text('Concluída em ${timeLabel(trip.data['completedAt'])}'),
              ],
            ),
        ],
      ),
    );
  }
}

class ReputationPage extends StatelessWidget {
  const ReputationPage(this.store, {super.key});
  final Workspace store;

  @override
  Widget build(BuildContext context) {
    final received = store.receivedReviews(store.user);
    final average = received.isEmpty
        ? null
        : received.fold<num>(0, (sum, row) => sum + (row['score'] as num)) /
              received.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Reputação')),
      body: AppPage(
        children: [
          Heading(
            'Avaliações recebidas',
            subtitle: average == null
                ? null
                : 'Média de ${average.toStringAsFixed(1)}/5',
          ),
          if (received.isEmpty) const Text('Nenhuma avaliação recebida.'),
          for (final review in received) ReviewTile(review),
          const Heading('Avaliações enviadas'),
          if (store.sentReviews.isEmpty)
            const Text('Nenhuma avaliação enviada.'),
          for (final review in store.sentReviews) ReviewTile(review),
        ],
      ),
    );
  }
}

class ReviewTile extends StatelessWidget {
  const ReviewTile(this.review, {super.key});
  final Json review;

  @override
  Widget build(BuildContext context) => Panel(
    children: [
      Text('Avaliação: ${review['score']}/5 · #${review['shipmentId']}'),
      if (review['comment'] case final String comment when comment.isNotEmpty)
        Text(comment),
      for (final entry in (review['criteria'] as Json? ?? {}).entries)
        Text('${entry.key}: ${entry.value}/5'),
      Text(timeLabel(review['at'])),
    ],
  );
}
