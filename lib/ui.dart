import 'package:flutter/material.dart';

import 'domain.dart';

const ink = Color(0xff171916);
const muted = Color(0xff73766f);
const line = Color(0xffdedfd9);
const paper = Color(0xfffbfbf9);
const canvas = Color(0xfff3f3f0);
const accent = Color(0xffc8ff46);

ThemeData levaTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'DM Sans',
    scaffoldBackgroundColor: canvas,
    colorScheme: const ColorScheme.light(
      primary: ink,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: ink,
      surface: paper,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: line,
    ),
  );
  final heading = const TextStyle(
    fontFamily: 'Manrope',
    fontWeight: FontWeight.w700,
    letterSpacing: -.7,
    color: ink,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(7));
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineLarge: heading.copyWith(fontSize: 34),
      headlineMedium: heading.copyWith(fontSize: 28),
      headlineSmall: heading.copyWith(fontSize: 24),
      titleLarge: heading.copyWith(fontSize: 20),
      titleMedium: heading.copyWith(fontSize: 16, letterSpacing: -.3),
      bodyMedium: const TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 13,
        color: ink,
        height: 1.5,
      ),
      bodySmall: const TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 11,
        color: muted,
        height: 1.5,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: paper,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: const BorderSide(color: line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 28),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Color(0xffd6d8d1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: muted, width: 1.5),
      ),
      hintStyle: const TextStyle(fontSize: 12, color: muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: shape,
        textStyle: const TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: .7,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size(0, 46),
        side: const BorderSide(color: ink),
        shape: shape,
        textStyle: const TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: .5,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ink,
        textStyle: const TextStyle(
          fontFamily: 'DM Sans',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: paper,
      selectedColor: accent,
      side: const BorderSide(color: line),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 11,
        color: ink,
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: paper,
      indicatorColor: accent,
      height: 68,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: ink,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
  );
}

class AppBrand extends StatelessWidget {
  const AppBrand({super.key, this.compact = false, this.dark = false});
  final bool compact;
  final bool dark;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Icon(Icons.route_outlined, color: ink, size: 22),
      ),
      if (!compact) ...[
        const SizedBox(width: 11),
        Text.rich(
          TextSpan(
            text: 'LEVA',
            children: const [
              TextSpan(
                text: 'Comigo',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            color: dark ? Colors.white : ink,
            letterSpacing: -.5,
          ),
        ),
      ],
    ],
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.7,
      color: color,
    ),
  );
}

class IdentityAvatar extends StatelessWidget {
  const IdentityAvatar(this.name, {super.key, this.size = 38});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    final initials = parts.isEmpty
        ? '?'
        : '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'
              .toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: line,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xffc7c9c2)),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: ink,
          fontSize: size * .3,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ResponsiveRow extends StatelessWidget {
  const ResponsiveRow({
    super.key,
    required this.children,
    this.breakpoint = 720,
    this.gap = 18,
    this.flexes,
  });
  final List<Widget> children;
  final double breakpoint;
  final double gap;
  final List<int>? flexes;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < breakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0) SizedBox(height: gap),
              child,
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) SizedBox(width: gap),
            Expanded(flex: flexes?[index] ?? 1, child: child),
          ],
        ],
      );
    },
  );
}

class FormIntro extends StatelessWidget {
  const FormIntro(this.title, this.subtitle, {super.key, this.number = '01'});
  final String title;
  final String subtitle;
  final String number;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: ink,
            foregroundColor: Colors.white,
            child: Text(number, style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 17),
          Expanded(child: Heading(title, subtitle: subtitle)),
        ],
      ),
      const Divider(),
    ],
  );
}

class SideHelp extends StatelessWidget {
  const SideHelp({super.key, required this.title, required this.steps});
  final String title;
  final List<String> steps;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: const Color(0xff20221f),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Simples assim', color: Color(0xffaeb1aa)),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Manrope',
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 24),
        for (final (index, step) in steps.indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xff3a3c38))),
            ),
            child: Row(
              children: [
                Text(
                  '0${index + 1}',
                  style: const TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    step,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 22),
        const Row(
          children: [
            Icon(Icons.verified_user_outlined, color: accent, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Confiança em cada etapa.',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

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
    padding: EdgeInsets.fromLTRB(
      MediaQuery.sizeOf(context).width > 720 ? 40 : 16,
      MediaQuery.sizeOf(context).width > 720 ? 38 : 24,
      MediaQuery.sizeOf(context).width > 720 ? 40 : 16,
      40,
    ),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
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
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (subtitle != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            subtitle!,
            style: const TextStyle(color: muted, fontSize: 12, height: 1.5),
          ),
        ),
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
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width > 720 ? 28 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index != 0) const SizedBox(height: 16),
            child,
          ],
        ],
      ),
    ),
  );
}

class LabeledField extends StatelessWidget {
  const LabeledField(this.label, {super.key, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xff50534d),
        ),
      ),
      const SizedBox(height: 8),
      child,
    ],
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
  Widget build(BuildContext context) => LabeledField(
    label,
    child: TextField(
      style: const TextStyle(fontSize: 13, color: ink),
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
      decoration: InputDecoration(hintText: secret ? '••••••••' : label),
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
    ),
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
  Widget build(BuildContext context) => LabeledField(
    label,
    child: DropdownButtonFormField<String>(
      style: const TextStyle(fontFamily: 'DM Sans', fontSize: 13, color: ink),
      initialValue: value,
      decoration: const InputDecoration(),
      isExpanded: true,
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    ),
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
    fieldViewBuilder: (context, controller, focus, submit) => LabeledField(
      label,
      child: TextField(
        style: const TextStyle(fontSize: 13, color: ink),
        controller: controller,
        focusNode: focus,
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
        ),
        onSubmitted: (_) => submit(),
      ),
    ),
  );
}
