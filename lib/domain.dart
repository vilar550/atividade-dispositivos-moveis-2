import 'dart:math';

import 'package:intl/intl.dart';

typedef Json = Map<String, dynamic>;

const demoEmail = 'teste@exemplo.com';
const sampleSender = 'sample-sender';
const cities = [
  'Recife, Brasil',
  'Lisboa, Portugal',
  'São Paulo, Brasil',
  'Porto, Portugal',
  'Rio de Janeiro, Brasil',
  'Brasília, Brasil',
  'Salvador, Brasil',
  'Fortaleza, Brasil',
  'Belo Horizonte, Brasil',
  'Curitiba, Brasil',
  'Madrid, Espanha',
  'Paris, França',
  'Londres, Reino Unido',
];
const itemTypes = [
  'Eletrônico',
  'Documentos',
  'Roupas e acessórios',
  'Livros',
  'Presentes',
  'Outros',
];
const reviewCriteria = [
  'Comunicação',
  'Cuidado com a encomenda',
  'Pontualidade',
  'Confiabilidade',
];

enum Status {
  pending('Aguardando aceite'),
  accepted('Solicitação aceita'),
  received('Mercadoria coletada'),
  inTransit('Em viagem', 'in_transit'),
  arrived('Aguardando confirmação'),
  completed('Concluída'),
  refused('Recusada'),
  cancelled('Cancelada');

  const Status(this.label, [this.legacyKey]);
  final String label;
  final String? legacyKey;
  String get key => legacyKey ?? name;
  bool get terminal => [completed, refused, cancelled].contains(this);
  bool get reservesSpace => this != refused && this != cancelled;

  static Status parse(String key) =>
      values.firstWhere((status) => status.key == key);
}

const transitions = {
  Status.pending: [Status.accepted, Status.refused, Status.cancelled],
  Status.accepted: [Status.received, Status.cancelled],
  Status.received: [Status.inTransit],
  Status.inTransit: [Status.arrived],
  Status.arrived: [Status.completed],
};

const actionLabels = {
  Status.accepted: 'Aceitar solicitação',
  Status.refused: 'Recusar solicitação',
  Status.cancelled: 'Cancelar encomenda',
  Status.received: 'Registrar coleta',
  Status.inTransit: 'Iniciar viagem',
  Status.arrived: 'Registrar chegada',
  Status.completed: 'Confirmar recebimento',
};

String day(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
String today() => day(DateTime.now());
String dateLabel(String date) =>
    DateFormat('dd/MM/yyyy').format(DateTime.parse(date));
String timeLabel(String time) =>
    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(time).toLocal());
String money(num value) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
String kg(num value) => NumberFormat('0.###', 'pt_BR').format(value);
String now() => DateTime.now().toUtc().toIso8601String();
String city(String value) => value.split(',').first.trim();
String normalizedCity(String value) {
  final text = city(value).toLowerCase();
  return text
      .replaceAll(RegExp('[áàãâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòõôö]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ç', 'c');
}

num? decimal(String text) {
  final value = num.tryParse(text.trim().replaceAll(',', '.'));
  return value != null && value.isFinite ? value : null;
}

bool validWeight(num? weight) =>
    weight != null &&
    weight.isFinite &&
    weight >= 0.1 &&
    weight <= 30 &&
    ((weight * 1000).round() - weight * 1000).abs() < 0.000001;

String randomCode(int bytes) {
  final random = Random.secure();
  return List.generate(
    bytes,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join().toUpperCase();
}

class RouteQuery {
  const RouteQuery(
    this.origin,
    this.destination,
    this.date,
    this.weight,
    this.category,
  );

  final String origin;
  final String destination;
  final String date;
  final num weight;
  final String category;

  void validate() {
    final parsedDate = DateTime.tryParse(date);
    if (city(origin).isEmpty || city(destination).isEmpty) {
      throw const RuleError('Informe a origem e o destino.');
    }
    if (normalizedCity(origin) == normalizedCity(destination)) {
      throw const RuleError('Escolha cidades diferentes.');
    }
    if (parsedDate == null ||
        day(parsedDate) != date ||
        date.compareTo(today()) < 0) {
      throw const RuleError('Escolha uma data de hoje em diante.');
    }
    if (!validWeight(weight)) {
      throw const RuleError(
        'Informe um peso entre 0,1 e 30 kg, com até três casas decimais.',
      );
    }
  }
}

class RuleError implements Exception {
  const RuleError(this.message);
  final String message;
}

class Trip {
  Trip(this.data);
  final Json data;
  String get id => data['id'];
  String get ownerId => data['ownerId'];
  String get name => data['name'];
  String get origin => data['origin'];
  String get destination => data['destination'];
  String get date => data['date'];
  num get space => data['space'];
  num get price => data['price'];
  String get notes => data['notes'];
  num get rating => data['rating'];
  bool get active => data['active'];
  List<String> get categories =>
      (data['acceptedTypes'] as List?)?.cast<String>() ?? itemTypes;
  bool get example => ownerId == 'sample-maria' || ownerId == 'sample-rafael';
}

class Shipment {
  Shipment(this.data);
  final Json data;
  String get id => data['id'];
  String get tripId => data['tripId'];
  String get senderId => data['senderId'];
  String get sender => data['sender'];
  String get category => data['itemType'];
  num get weight => data['weight'];
  String get description => data['description'];
  num get declaredValue => data['declaredValue'];
  num get price => data['price'];
  Status get status => Status.parse(data['status']);
  Map<String, String> get events =>
      (data['events'] as Map).cast<String, String>();
  bool get example => senderId == sampleSender;
}

int reservedGrams(Trip trip, Iterable<Shipment> shipments) => shipments
    .where((s) => s.tripId == trip.id && s.status.reservesSpace)
    .fold(0, (sum, s) => sum + (s.weight * 1000).round());

num remaining(Trip trip, Iterable<Shipment> shipments) =>
    max(0, (trip.space * 1000).round() - reservedGrams(trip, shipments)) / 1000;

List<Status> allowedActions(Trip trip, Shipment shipment, String user) {
  final sender = shipment.senderId == user;
  final traveler = trip.ownerId == user;
  if (!sender && !traveler) return [];
  return (transitions[shipment.status] ?? []).where((next) {
    if (next == Status.cancelled) return true;
    if (next == Status.completed) {
      return sender || (traveler && shipment.example);
    }
    return traveler || (sender && trip.example);
  }).toList();
}
