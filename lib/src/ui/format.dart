/// Date compacte pour les listes : « 30/08 14:52 » cette année,
/// « 30/08/2025 » sinon. Sans dépendance intl : gabarit fixe, pas de locale.
String formatNoteDate(DateTime d, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  if (d.year == ref.year) {
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}
