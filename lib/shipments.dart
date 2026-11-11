import 'package:flutter/material.dart';

import 'domain.dart';
import 'market.dart';
import 'profile.dart';
import 'ui.dart';
import 'workspace.dart';

void openTracking(BuildContext context, Workspace store, String id) =>
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrackingPage(store, id)),
    );

class ShipmentTile extends StatelessWidget {
  const ShipmentTile(this.store, this.shipment, {super.key});
  final Workspace store;
  final Shipment shipment;

  @override
  Widget build(BuildContext context) {
    final trip = store.trip(shipment.tripId);
    final sender = shipment.senderId == store.user;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xffefefeb),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.inventory_2_outlined, size: 22),
        ),
        title: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            '${city(trip.origin)} → ${city(trip.destination)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#${shipment.id} · ${sender ? 'Viajante: ${trip.name}' : 'Remetente: ${shipment.sender}'}',
              style: const TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xffeceee7),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                shipment.status.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: .6,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openTracking(context, store, shipment.id),
      ),
    );
  }
}

enum ShipmentFilter {
  active('Em andamento'),
  done('Concluídas'),
  closed('Canceladas e recusadas');

  const ShipmentFilter(this.label);
  final String label;
}

class ShipmentsPage extends StatefulWidget {
  const ShipmentsPage(this.store, {super.key});
  final Workspace store;

  @override
  State<ShipmentsPage> createState() => _ShipmentsPageState();
}

class _ShipmentsPageState extends State<ShipmentsPage> {
  ShipmentFilter _filter = ShipmentFilter.active;
  Workspace get store => widget.store;

  @override
  Widget build(BuildContext context) {
    final visible = store.mine
        .where(
          (s) => switch (_filter) {
            ShipmentFilter.active => !s.status.terminal,
            ShipmentFilter.done => s.status == Status.completed,
            ShipmentFilter.closed =>
              s.status == Status.cancelled || s.status == Status.refused,
          },
        )
        .toList();
    return AppPage(
      children: [
        const Heading('Viagens e encomendas'),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TripFormPage(store)),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Publicar viagem'),
        ),
        const Heading('Minhas viagens'),
        if (store.myTrips.isEmpty)
          const Text('Você ainda não publicou uma viagem.'),
        for (final trip in store.myTrips.reversed)
          Panel(
            children: [
              TripSummary(store, trip),
              Text(switch (trip.data['completedAt']) {
                final String at => 'Concluída em ${timeLabel(at)}',
                _ =>
                  trip.active
                      ? (trip.date.compareTo(today()) < 0
                            ? 'Data da viagem passou'
                            : 'Publicada')
                      : 'Publicação encerrada',
              }),
              if (trip.active)
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TripFormPage(store, trip: trip),
                        ),
                      ),
                      child: const Text('Editar viagem'),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (await confirm(
                              context,
                              'Encerrar publicação?',
                              'As encomendas existentes podem seguir no app.',
                            ) &&
                            context.mounted) {
                          await perform(
                            context,
                            () => store.closeTrip(trip.id),
                          );
                        }
                      },
                      child: const Text('Encerrar publicação'),
                    ),
                  ],
                ),
              if (trip.active &&
                  trip.date.compareTo(today()) >= 0 &&
                  remaining(trip, store.shipments) >= 1)
                TextButton(
                  onPressed: () => perform(context, () async {
                    final id = await store.request(
                      trip.id,
                      trip.categories.first,
                      1,
                      'Encomenda fictícia para testar a viagem.',
                      50,
                      sample: true,
                    );
                    if (context.mounted) openTracking(context, store, id);
                  }),
                  child: const Text('Testar com solicitação de exemplo'),
                ),
            ],
          ),
        const Heading('Minhas encomendas'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final filter in ShipmentFilter.values)
              ChoiceChip(
                label: Text(filter.label),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
              ),
          ],
        ),
        for (final (title, shipments) in [
          ('Envios', visible.where((s) => s.senderId == store.user)),
          (
            'Solicitações recebidas',
            visible.where((s) => s.senderId != store.user),
          ),
        ]) ...[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (shipments.isEmpty) const Text('Nenhuma encomenda neste filtro.'),
          for (final shipment in shipments) ShipmentTile(store, shipment),
        ],
      ],
    );
  }
}

class TrackingPage extends StatelessWidget {
  const TrackingPage(this.store, this.id, {super.key});
  final Workspace store;
  final String id;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Encomenda #$id')),
    body: ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final shipment = store.shipment(id);
        if (shipment == null) {
          return const Center(child: Text('Encomenda indisponível.'));
        }
        final trip = store.trip(shipment.tripId);
        final sender = shipment.senderId == store.user;
        final actions = allowedActions(trip, shipment, store.user);
        final review = store.review(id);
        return AppPage(
          children: [
            const Eyebrow('Acompanhe sua encomenda'),
            ResponsiveRow(
              flexes: const [2, 1],
              breakpoint: 780,
              children: [
                Panel(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Eyebrow('Código da encomenda'),
                              const SizedBox(height: 8),
                              Text(
                                '#$id',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.inventory_2_outlined, size: 32),
                      ],
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Eyebrow('Origem'),
                              const SizedBox(height: 8),
                              Text(
                                city(trip.origin),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(
                            Icons.flight_takeoff_outlined,
                            color: muted,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Eyebrow('Destino'),
                              const SizedBox(height: 8),
                              Text(
                                city(trip.destination),
                                style: Theme.of(context).textTheme.titleLarge,
                                textAlign: TextAlign.end,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(),

                    Heading(shipment.status.label),
                    const Divider(),
                    const Heading('Histórico da encomenda'),
                    for (final status in Status.values.where(
                      (status) => shipment.events.containsKey(status.key),
                    ))
                      ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: status == shipment.status
                              ? accent
                              : ink,
                          foregroundColor: status == shipment.status
                              ? ink
                              : Colors.white,
                          child: const Icon(Icons.check, size: 17),
                        ),
                        title: Text(
                          status.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(timeLabel(shipment.events[status.key]!)),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Panel(
                      children: [
                        const Eyebrow('Detalhes da encomenda'),
                        Row(
                          children: [
                            IdentityAvatar(
                              sender ? trip.name : shipment.sender,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Eyebrow('Responsáveis pela entrega'),
                                  Text('Viajante: ${trip.name}'),
                                  Text(
                                    'Remetente: ${shipment.sender}',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${shipment.category} · ${kg(shipment.weight)} kg',
                        ),
                        Text(shipment.description),
                        Text(
                          'Valor declarado: ${money(shipment.declaredValue)}',
                        ),
                        Text('Total combinado: ${money(shipment.price)}'),
                        if (shipment.example || trip.example)
                          const Text(
                            'Demonstração. Você pode simular as ações da outra parte.',
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    for (final child in <Widget>[
                      if (actions.isNotEmpty)
                        Panel(
                          children: [
                            const Text('Próximas ações'),
                            for (final action in actions)
                              OutlinedButton(
                                onPressed: () async {
                                  if ([
                                    Status.refused,
                                    Status.cancelled,
                                    Status.completed,
                                  ].contains(action)) {
                                    if (!await confirm(
                                      context,
                                      '${actionLabels[action]}?',
                                      'A etapa será registrada no histórico.',
                                    )) {
                                      return;
                                    }
                                  }
                                  if (context.mounted) {
                                    await perform(
                                      context,
                                      () => store.advance(id, action),
                                    );
                                  }
                                },
                                child: Text(
                                  (trip.example &&
                                          sender &&
                                          action == Status.arrived)
                                      ? 'Simular chegada'
                                      : actionLabels[action]!,
                                ),
                              ),
                          ],
                        ),
                      if (sender &&
                          shipment.status == Status.completed &&
                          review == null)
                        FilledButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RatingPage(store, id),
                            ),
                          ),
                          child: const Text('Avaliar entrega'),
                        ),
                      if (review != null) ReviewTile(review),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(store, id),
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Abrir conversa'),
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: child,
                      ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

class RatingPage extends StatefulWidget {
  const RatingPage(this.store, this.id, {super.key});
  final Workspace store;
  final String id;

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  final _comment = TextEditingController();
  final _criteria = <String, int>{};
  int _score = 0;
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Widget _stars(String label, int score, ValueChanged<int> change) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Wrap(
        children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              tooltip: '$label: $i de 5',
              isSelected: i <= score,
              onPressed: () => change(i),
              icon: const Icon(Icons.star_outline),
              selectedIcon: const Icon(Icons.star),
            ),
        ],
      ),
    ],
  );

  Future<void> _submit() async {
    setState(() => _busy = true);
    await perform(context, () async {
      await widget.store.rate(widget.id, _score, _criteria, _comment.text);
      if (mounted) Navigator.pop(context);
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Avaliar entrega')),
    body: AppPage(
      children: [
        Panel(
          children: [
            _stars(
              'Nota geral',
              _score,
              (score) => setState(() => _score = score),
            ),
            for (final criterion in reviewCriteria)
              _stars(
                criterion,
                _criteria[criterion] ?? 0,
                (score) => setState(() => _criteria[criterion] = score),
              ),
            Entry('Comentário (opcional)', controller: _comment, lines: 3),
            FilledButton(
              onPressed: _score == 0 || _busy ? null : _submit,
              child: const Text('Enviar avaliação'),
            ),
          ],
        ),
      ],
    ),
  );
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage(this.store, {super.key});
  final Workspace store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notificações')),
    body: ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.mine;
        String lastEvent(Shipment s) => s.events.values.fold(
          '',
          (latest, at) => latest.compareTo(at) >= 0 ? latest : at,
        );
        items.sort((a, b) => lastEvent(b).compareTo(lastEvent(a)));
        return AppPage(
          children: [
            if (items.isEmpty) const Text('Nenhuma notificação por enquanto.'),
            if (items.any(store.isUnread))
              OutlinedButton(
                onPressed: () => perform(context, store.markRead),
                child: const Text('Marcar todas como lidas'),
              ),
            for (final shipment in items)
              Card(
                child: ListTile(
                  leading: Icon(
                    store.isUnread(shipment)
                        ? Icons.mark_email_unread_outlined
                        : Icons.drafts_outlined,
                  ),
                  title: Text('#${shipment.id} · ${shipment.status.label}'),
                  subtitle: Text(
                    lastEvent(shipment).isEmpty
                        ? ''
                        : timeLabel(lastEvent(shipment)),
                  ),
                  onTap: () => openTracking(context, store, shipment.id),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class ChatListPage extends StatelessWidget {
  const ChatListPage(this.store, {super.key});
  final Workspace store;

  @override
  Widget build(BuildContext context) => AppPage(
    children: [
      const Heading(
        'Conversas',
        subtitle: 'As mensagens ficam salvas neste dispositivo.',
      ),
      if (store.mine.isEmpty)
        const Text('As conversas aparecem quando há uma encomenda.'),
      for (final shipment in store.mine)
        Card(
          child: ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: Text(
              '#${shipment.id} · ${shipment.senderId == store.user ? store.trip(shipment.tripId).name : shipment.sender}',
            ),
            subtitle: Text(
              store.messages(shipment.id).lastOrNull?['text'] ??
                  'Ainda sem mensagens',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatPage(store, shipment.id)),
            ),
          ),
        ),
    ],
  );
}

class ChatPage extends StatefulWidget {
  const ChatPage(this.store, this.id, {super.key});
  final Workspace store;
  final String id;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _message = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() => _busy = true);
    await perform(context, () async {
      await widget.store.sendMessage(widget.id, _message.text);
      if (!mounted) return;
      _message.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Conversa #${widget.id}')),
    body: ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final messages = widget.store.messages(widget.id);
        return AppPage(
          controller: _scroll,
          children: [
            if (messages.isEmpty)
              const Text('Ainda não há mensagens nesta conversa.'),
            for (final message in messages)
              Align(
                alignment: message['authorId'] == widget.store.user
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: message['authorId'] == widget.store.user
                          ? ink
                          : paper,
                      border: Border.all(color: line),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message['author'] == 'system'
                              ? 'Atualização da encomenda'
                              : message['authorId'] == widget.store.user ||
                                    message['authorId'] == null
                              ? 'Enviada'
                              : 'Recebida',
                          style: TextStyle(
                            color: message['authorId'] == widget.store.user
                                ? accent
                                : muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          message['text'],
                          style: TextStyle(
                            color: message['authorId'] == widget.store.user
                                ? Colors.white
                                : ink,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          timeLabel(message['at']),
                          style: TextStyle(
                            fontSize: 9,
                            color: message['authorId'] == widget.store.user
                                ? const Color(0xffaeb1aa)
                                : muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Entry('Mensagem', controller: _message, onSubmitted: _send),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: const Text('Enviar mensagem'),
            ),
          ],
        );
      },
    ),
  );
}
