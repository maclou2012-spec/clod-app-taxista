double? _comoDecimalParada(dynamic valor) {
  if (valor is num) return valor.toDouble();
  if (valor is String) return double.tryParse(valor);
  return null;
}

int? _comoEnteroParada(dynamic valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  if (valor is String) return int.tryParse(valor);
  return null;
}

/// Una parada de un viaje con paradas de servicio o colectivo.
/// `tipo`: 'servicio' (recoger/dejar un paquete u objeto, o dejar a un
/// pasajero que ya viaja) o 'recogida' (subir a otra persona, viaje
/// colectivo). `estado`: lo que mande el backend ('pendiente', 'llegada',
/// 'completada', 'omitida' son los valores esperados, pero no se asume más
/// que su presencia — ver los getters de abajo).
class ParadaViaje {
  const ParadaViaje({
    required this.id,
    required this.orden,
    required this.tipo,
    required this.direccion,
    this.lat,
    this.lng,
    this.nombreContacto,
    this.descripcion,
    required this.estado,
  });

  final int id;
  final int orden;
  final String tipo;
  final String direccion;
  final double? lat;
  final double? lng;
  final String? nombreContacto;
  final String? descripcion;
  final String estado;

  bool get esServicio => tipo == 'servicio';

  bool get completadaUOmitida => estado == 'completada' || estado == 'omitida';

  bool get llegada => estado == 'llegada';

  bool get pendiente => estado == 'pendiente';

  factory ParadaViaje.desdeJson(Map<String, dynamic> json) {
    return ParadaViaje(
      id: _comoEnteroParada(json['id']) ?? 0,
      orden: _comoEnteroParada(json['orden']) ?? 0,
      tipo: json['tipo']?.toString() ?? 'servicio',
      direccion: json['direccion']?.toString() ?? '—',
      lat: _comoDecimalParada(json['lat']),
      lng: _comoDecimalParada(json['lng']),
      nombreContacto: json['nombre_contacto']?.toString(),
      descripcion: json['descripcion']?.toString(),
      estado: json['estado']?.toString() ?? 'pendiente',
    );
  }
}

// La lista de paradas puede venir plana (data['paradas']) o anidada bajo
// 'viaje'/'solicitud' según de dónde llegue (aceptar, /detalle, sondeo) —
// mismo patrón defensivo que el resto del parseo en esta app.
List<ParadaViaje> paradasDesdeMapa(Map<String, dynamic> mapa) {
  final crudo = mapa['paradas'];
  if (crudo is! List) return const [];
  return crudo
      .whereType<Map<String, dynamic>>()
      .map(ParadaViaje.desdeJson)
      .toList()
    ..sort((a, b) => a.orden.compareTo(b.orden));
}

String tipoViajeDesdeMapa(Map<String, dynamic> mapa) {
  return mapa['tipo_viaje']?.toString() ?? 'normal';
}

// 'parada' | 'destino' | 'completar' — el backend decide cuál es el
// siguiente paso del taxista (prompt 21); null si /detalle todavía no lo
// manda (versión del backend sin desplegar), en cuyo caso
// pasoViajeEnCursoDesde cae a derivarlo localmente de las paradas.
String? siguientePasoDesdeMapa(Map<String, dynamic> mapa) {
  return mapa['siguiente_paso']?.toString();
}

// parada_actual puede llegar como el id plano o como el objeto completo de
// la parada — se acepta cualquiera de las dos formas (misma incertidumbre
// que paradaActualId en la app de pasajero, donde tampoco se confirmó la
// forma exacta contra un backend real).
int? paradaActualIdDesdeMapa(Map<String, dynamic> mapa) {
  final valor = mapa['parada_actual'];
  if (valor is Map<String, dynamic>) {
    final id = valor['id'];
    return id is num ? id.toInt() : null;
  }
  if (valor is num) return valor.toInt();
  if (valor is String) return int.tryParse(valor);
  return null;
}

// Qué debe mostrarle la pantalla de viaje en curso al taxista en este
// momento. Pura y separada de ViajeEnCursoScreen para poder probarla por
// unidad con 0/1/2/3 paradas, paradas omitidas, y siguiente_paso ausente o
// con un valor no reconocido — ver test/screens/viaje_en_curso_screen_test.dart.
//
// Si el backend manda siguiente_paso, es SIEMPRE la fuente de verdad (nunca
// se contradice con una derivación local). Si no lo manda (backend viejo),
// se deriva de las paradas: alguna sin resolver -> 'parada', todas
// resueltas (o sin paradas) -> 'destino'. Un valor de siguiente_paso que no
// es ninguno de los tres esperados es un estado inconsistente real (ej. un
// typo del backend o un valor nuevo que esta versión no conoce todavía) —
// nunca se asume cuál de los tres fue, se pide resincronizar.
enum PasoViajeEnCurso { parada, destino, completar, inconsistente }

PasoViajeEnCurso pasoViajeEnCursoDesde({
  required String? siguientePaso,
  required List<ParadaViaje> paradas,
  required String tipoViaje,
}) {
  switch (siguientePaso) {
    case 'parada':
      return PasoViajeEnCurso.parada;
    case 'destino':
      return PasoViajeEnCurso.destino;
    case 'completar':
      return PasoViajeEnCurso.completar;
    case null:
      if (tipoViaje == 'normal' || paradas.isEmpty) {
        return PasoViajeEnCurso.destino;
      }
      return paradas.every((parada) => parada.completadaUOmitida)
          ? PasoViajeEnCurso.destino
          : PasoViajeEnCurso.parada;
    default:
      return PasoViajeEnCurso.inconsistente;
  }
}

// El sistema NO sugiere montos: un campo vacío se guarda como 0, nunca con
// un valor "recomendado" propio. null si el texto no es un número válido
// (ej. coma suelta) o es negativo — eso sí se rechaza antes de guardar.
double? parsearMontoParada(String texto) {
  final limpio = texto.trim();
  if (limpio.isEmpty) return 0;
  final valor = double.tryParse(limpio.replaceAll(',', ''));
  if (valor == null || valor < 0) return null;
  return valor;
}

String montoParadaComoTexto(dynamic valor) {
  final decimal = valor is num
      ? valor.toDouble()
      : double.tryParse(valor?.toString() ?? '');
  if (decimal == null || decimal == 0) return '';
  return decimal.toStringAsFixed(2);
}

// 409 de POST /completar con codigo 'PARADAS_PENDIENTES' — la forma exacta
// del cuerpo no está confirmada, así que se prueban los nombres de llave
// más probables (mismo patrón defensivo que el resto del parseo).
List<String> direccionesParadasPendientesDesde(dynamic data) {
  if (data is! Map<String, dynamic>) return const [];
  final crudo = data['paradas_pendientes'] ?? data['paradasPendientes'];
  if (crudo is! List) return const [];
  return crudo
      .map((p) {
        if (p is Map<String, dynamic>) return p['direccion']?.toString();
        return p?.toString();
      })
      .whereType<String>()
      .toList();
}
