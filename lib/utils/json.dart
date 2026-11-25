// Lectura tolerante de JSON del backend: MySQL manda los DECIMAL como texto
// ("45.50"), los booleanos como 0/1 y a veces null. Estas funciones evitan
// repetir esa conversión en cada modelo.

double? aDecimal(Object? valor) {
  if (valor is num) return valor.toDouble();
  if (valor is String) return double.tryParse(valor);
  return null;
}

int? aEntero(Object? valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  if (valor is String) return int.tryParse(valor);
  return null;
}

bool? aBooleano(Object? valor) {
  if (valor is bool) return valor;
  if (valor is num) return valor != 0;
  if (valor is String) {
    if (valor == '1' || valor.toLowerCase() == 'true') return true;
    if (valor == '0' || valor.toLowerCase() == 'false') return false;
  }
  return null;
}

String? aTexto(Object? valor) {
  if (valor == null) return null;
  final texto = valor.toString().trim();
  return texto.isEmpty ? null : texto;
}

Map<String, dynamic> aMapa(Object? valor) =>
    valor is Map<String, dynamic> ? valor : const {};

List<Map<String, dynamic>> aListaMapas(Object? valor) =>
    valor is List ? valor.whereType<Map<String, dynamic>>().toList() : const [];

/// "$1,234.50" — sin decimales si es entero ("$85").
String formatoPesos(double monto) {
  final entero = monto == monto.roundToDouble();
  final texto = monto.toStringAsFixed(entero ? 0 : 2);
  final partes = texto.split('.');
  final miles = partes[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return partes.length > 1 ? '\$$miles.${partes[1]}' : '\$$miles';
}
