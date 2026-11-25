const List<String> _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

const List<String> _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

String textoHora(DateTime f) =>
    '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

/// «25 nov · 14:30» (hora local del teléfono).
String textoFechaCorta(DateTime f) =>
    '${f.day} ${_meses[f.month - 1]} · ${textoHora(f)}';

/// «mié 25 nov, 14:30».
String textoDiaHora(DateTime f) =>
    '${_dias[f.weekday - 1]} ${f.day} ${_meses[f.month - 1]}, ${textoHora(f)}';
