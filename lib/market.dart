import 'package:flutter/material.dart';

import 'domain.dart';
import 'profile.dart';
import 'shipments.dart';
import 'ui.dart';
import 'workspace.dart';

class SearchPage extends StatefulWidget {
  const SearchPage(this.store, {super.key});
  final Workspace store;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _origin = TextEditingController(text: cities[0]);
  final _destination = TextEditingController(text: cities[1]);
  final _weight = TextEditingController(text: '2');
  final _originFocus = FocusNode();
  final _destinationFocus = FocusNode();
  late DateTime _date = DateTime.parse(widget.store.trip('T-MARIA').date);
  String _category = itemTypes.first;
  RouteQuery? _query;
  String _sort = 'Avaliação';

  @override
  void dispose() {
    _origin.dispose();
    _destination.dispose();
    _weight.dispose();
    _originFocus.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final query = _query;
    final results = query == null || query.date.compareTo(today()) < 0
        ? <Trip>[]
        : store.search(query);
    results.sort(
      (a, b) => switch (_sort) {
        'Preço' => a.price.compareTo(b.price),
        'Espaço' => remaining(
          b,
          store.shipments,
        ).compareTo(remaining(a, store.shipments)),
        _ => store.rating(b).compareTo(store.rating(a)),
      },
    );
    return AppPage(
      children: [
        const Heading(
          'Buscar viagem',
          subtitle: 'Preencha a rota e os dados da sua encomenda.',
        ),
        Panel(
          children: [
            CityEntry('Origem', controller: _origin, focus: _originFocus),
            CityEntry(
              'Destino',
              controller: _destination,
              focus: _destinationFocus,
            ),
            DateEntry(
              date: _date,
              onChanged: (date) => setState(() => _date = date),
            ),
            Entry('Peso (kg)', controller: _weight, numeric: true),
            Choice(
              'Categoria',
              value: _category,
              options: itemTypes,
              onChanged: (value) => setState(() => _category = value),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Encontrar viagens'),
              onPressed: () => perform(context, () async {
                FocusScope.of(context).unfocus();
                final query = RouteQuery(
                  _origin.text,
                  _destination.text,
                  day(_date),
                  decimal(_weight.text) ?? 0,
                  _category,
                );
                query.validate();
                setState(() => _query = query);
              }),
            ),
          ],
        ),
        if (query != null) ...[
          Heading(
            '${results.length} viagens encontradas',
            subtitle: '${city(query.origin)} → ${city(query.destination)}',
          ),
          if (results.isEmpty)
            const Text(
              'Nenhuma viagem combina com essa busca. Ajuste a rota, a data, a categoria ou o peso.',
            ),
          if (results.isNotEmpty)
            Choice(
              'Ordenar por',
              value: _sort,
              options: const ['Avaliação', 'Preço', 'Espaço'],
              onChanged: (value) => setState(() => _sort = value),
            ),
          for (final trip in results)
            Panel(
              children: [
                TripSummary(store, trip),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TravelerPage(store, trip, query),
                    ),
                  ),
                  child: const Text('Ver viagem e viajante'),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class TripSummary extends StatelessWidget {
  const TripSummary(this.store, this.trip, {super.key});
  final Workspace store;
  final Trip trip;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${city(trip.origin)} → ${city(trip.destination)}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text('${dateLabel(trip.date)} · ${trip.name}'),
      Text(
        '${kg(remaining(trip, store.shipments))} kg livres · ${money(trip.price)}/kg',
      ),
      if (store.rating(trip) > 0)
        Text('Avaliação: ${store.rating(trip).toStringAsFixed(1)}/5'),
      if (trip.example) const Text('Viagem de exemplo'),
    ],
  );
}

class TravelerPage extends StatelessWidget {
  const TravelerPage(this.store, this.trip, this.query, {super.key});
  final Workspace store;
  final Trip trip;
  final RouteQuery query;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalhes da viagem')),
    body: AppPage(
      children: [
        Panel(
          children: [
            TripSummary(store, trip),
            Text('Aceita: ${trip.categories.join(', ')}'),
            if (trip.notes.isNotEmpty) Text(trip.notes),
            FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RequestPage(store, trip, query),
                ),
              ),
              child: const Text('Solicitar transporte'),
            ),
          ],
        ),
        const Heading('Avaliações do viajante'),
        if (store.receivedReviews(trip.ownerId).isEmpty)
          const Text('Ainda não há comentários de entregas concluídas.'),
        for (final review in store.receivedReviews(trip.ownerId))
          ReviewTile(review),
      ],
    ),
  );
}

class TripFormPage extends StatefulWidget {
  const TripFormPage(this.store, {super.key, this.trip});
  final Workspace store;
  final Trip? trip;

  @override
  State<TripFormPage> createState() => _TripFormPageState();
}

class _TripFormPageState extends State<TripFormPage> {
  Trip? get trip => widget.trip;
  late final _origin = TextEditingController(text: trip?.origin ?? '');
  late final _destination = TextEditingController(
    text: trip?.destination ?? '',
  );
  late final _capacity = TextEditingController(
    text: trip?.space.toString() ?? '',
  );
  late final _price = TextEditingController(text: trip?.price.toString() ?? '');
  late final _notes = TextEditingController(text: trip?.notes ?? '');
  final _originFocus = FocusNode();
  final _destinationFocus = FocusNode();
  late DateTime _date = trip == null
      ? DateTime.now()
      : DateTime.parse(trip!.date);
  late final _categories = {...?trip?.categories};
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [
      _origin,
      _destination,
      _capacity,
      _price,
      _notes,
    ]) {
      controller.dispose();
    }
    _originFocus.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await perform(context, () async {
      final route = RouteQuery(
        _origin.text,
        _destination.text,
        day(_date),
        decimal(_capacity.text) ?? 0,
        '',
      );
      await widget.store.saveTrip(
        route,
        decimal(_price.text) ?? 0,
        _categories.toList(),
        _notes.text,
        id: trip?.id,
      );
      if (mounted) Navigator.pop(context);
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(trip == null ? 'Publicar viagem' : 'Editar viagem'),
    ),
    body: AppPage(
      children: [
        Panel(
          children: [
            if (trip == null) ...[
              CityEntry('Origem', controller: _origin, focus: _originFocus),
              CityEntry(
                'Destino',
                controller: _destination,
                focus: _destinationFocus,
              ),
              DateEntry(
                date: _date,
                onChanged: (date) => setState(() => _date = date),
              ),
            ] else
              TripSummary(widget.store, trip!),
            Entry(
              'Capacidade total (kg)',
              controller: _capacity,
              numeric: true,
            ),
            Entry('Preço por kg (R\$)', controller: _price, numeric: true),
            const Text('Categorias aceitas'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final category in itemTypes)
                  FilterChip(
                    label: Text(category),
                    selected: _categories.contains(category),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _categories.add(category);
                      } else {
                        _categories.remove(category);
                      }
                    }),
                  ),
              ],
            ),
            Entry('Observações', controller: _notes, lines: 3),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(trip == null ? 'Publicar' : 'Salvar alterações'),
            ),
          ],
        ),
      ],
    ),
  );
}

class RequestPage extends StatefulWidget {
  const RequestPage(this.store, this.trip, this.query, {super.key});
  final Workspace store;
  final Trip trip;
  final RouteQuery query;

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  late final _weight = TextEditingController(
    text: widget.query.weight.toString(),
  );
  final _description = TextEditingController();
  final _value = TextEditingController(text: '0');
  late String _category = widget.query.category;
  bool _busy = false;

  @override
  void dispose() {
    _weight.dispose();
    _description.dispose();
    _value.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    await perform(context, () async {
      final id = await widget.store.request(
        widget.trip.id,
        _category,
        decimal(_weight.text) ?? 0,
        _description.text,
        decimal(_value.text) ?? -1,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => TrackingPage(widget.store, id)),
        (route) => route.isFirst,
      );
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar transporte')),
      body: AppPage(
        children: [
          Panel(
            children: [
              TripSummary(widget.store, trip),
              Choice(
                'Categoria',
                value: _category,
                options: trip.categories,
                onChanged: (value) => setState(() => _category = value),
              ),
              Entry('Peso (kg)', controller: _weight, numeric: true),
              Entry(
                'Descrição da encomenda',
                controller: _description,
                lines: 3,
              ),
              Entry('Valor declarado (R\$)', controller: _value, numeric: true),
              ValueListenableBuilder(
                valueListenable: _weight,
                builder: (context, value, _) => Text(
                  'Total estimado: ${money((decimal(value.text) ?? 0) * trip.price)}',
                ),
              ),
              FilledButton(
                onPressed: _busy ? null : _request,
                child: const Text('Enviar solicitação'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
