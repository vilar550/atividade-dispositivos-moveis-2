import 'package:flutter/material.dart';

import 'domain.dart';

void notice(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<void> perform(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on RuleError catch (error) {
    if (context.mounted) notice(context, error.message);
  }
}

class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.children, this.controller});
  final List<Widget> children;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => ListView(
    controller: controller,
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: child,
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

class Heading extends StatelessWidget {
  const Heading(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      if (subtitle != null)
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle!)),
    ],
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index != 0) const SizedBox(height: 10),
            child,
          ],
        ],
      ),
    ),
  );
}

class Entry extends StatelessWidget {
  const Entry(
    this.label, {
    super.key,
    required this.controller,
    this.numeric = false,
    this.secret = false,
    this.lines = 1,
    this.email = false,
    this.onSubmitted,
  });
  final String label;
  final TextEditingController controller;
  final bool numeric;
  final bool secret;
  final bool email;
  final int lines;
  final VoidCallback? onSubmitted;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: secret,
    maxLines: lines,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : email
        ? TextInputType.emailAddress
        : lines > 1
        ? TextInputType.multiline
        : TextInputType.text,
    decoration: InputDecoration(labelText: label),
    onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
  );
}

class Choice extends StatelessWidget {
  const Choice(
    this.label, {
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    isExpanded: true,
    items: [
      for (final option in options)
        DropdownMenuItem(value: option, child: Text(option)),
    ],
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
  );
}

Future<bool> confirm(BuildContext context, String title, String text) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;

class DateEntry extends StatelessWidget {
  const DateEntry({super.key, required this.date, required this.onChanged});
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.calendar_today_outlined),
    label: Text('Data: ${dateLabel(day(date))}'),
    onPressed: () async {
      final current = DateUtils.dateOnly(DateTime.now());
      final last = DateTime(current.year + 5, current.month, current.day);
      final result = await showDatePicker(
        context: context,
        initialDate: date.isBefore(current)
            ? current
            : date.isAfter(last)
            ? last
            : date,
        firstDate: current,
        lastDate: last,
      );
      if (result != null && context.mounted) onChanged(result);
    },
  );
}

class CityEntry extends StatelessWidget {
  const CityEntry(
    this.label, {
    super.key,
    required this.controller,
    required this.focus,
  });
  final String label;
  final TextEditingController controller;
  final FocusNode focus;
  @override
  Widget build(BuildContext context) => Autocomplete<String>(
    textEditingController: controller,
    focusNode: focus,
    optionsBuilder: (value) => cities.where(
      (city) =>
          value.text.trim().isNotEmpty &&
          normalizedCity(city).contains(normalizedCity(value.text)),
    ),
    fieldViewBuilder: (context, controller, focus, submit) => TextField(
      controller: controller,
      focusNode: focus,
      decoration: InputDecoration(labelText: label),
      onSubmitted: (_) => submit(),
    ),
  );
}
