/// Formate un montant en FCFA avec séparateur d'espace : 150000 -> "150 000 FCFA"
String fmtMoney(num value) {
  final negative = value < 0;
  final n = value.abs().round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < n.length; i++) {
    if (i > 0 && (n.length - i) % 3 == 0) buf.write(' ');
    buf.write(n[i]);
  }
  return '${negative ? '-' : ''}$buf FCFA';
}

String _two(int v) => v.toString().padLeft(2, '0');

String fmtDate(DateTime? d) {
  if (d == null) return '—';
  return '${_two(d.day)}/${_two(d.month)}/${d.year}';
}

String fmtDateTime(DateTime? d) {
  if (d == null) return '—';
  return '${fmtDate(d)} ${_two(d.hour)}:${_two(d.minute)}';
}

/// "2026-10-15" (format ISO attendu par l'API) pour le champ `delai`
String toIsoDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
