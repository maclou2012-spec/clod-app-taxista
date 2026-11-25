import '../utils/json.dart';

DateTime? _fecha(Object? valor) =>
    DateTime.tryParse(aTexto(valor) ?? '')?.toLocal();

/// GET /api/conductor-foraneo/perfil.
class PerfilForaneo {
  PerfilForaneo({
    required this.servicio,
    required this.saldo,
    required this.membresiaVigente,
    this.asientosVehiculo,
    this.vehiculo,
    this.calificacion,
    this.resenas = 0,
    this.precioMaxKm,
  });

  factory PerfilForaneo.desdeJson(Map<String, dynamic> j) {
    final v = aMapa(j['vehiculo']);
    final nombre = [
      aTexto(v['marca']),
      aTexto(v['modelo']),
      aTexto(v['placas']),
    ].whereType<String>().join(' · ');
    return PerfilForaneo(
      servicio: aTexto(j['viajes_foraneos']) ?? 'sin_solicitar',
      saldo: aDecimal(j['saldo']) ?? 0,
      membresiaVigente:
          aBooleano(aMapa(j['membresia'])['membresia_vigente']) ?? false,
      asientosVehiculo: aEntero(v['num_asientos']),
      vehiculo: nombre.isEmpty ? null : nombre,
      calificacion: aDecimal(j['calificacion_foraneos']),
      resenas: aEntero(j['resenas_foraneos']) ?? 0,
      precioMaxKm: aDecimal(j['precio_max_km']),
    );
  }

  /// `sin_solicitar`, `pendiente`, `habilitado` o `suspendido`.
  final String servicio;
  final double saldo;
  final bool membresiaVigente;
  final int? asientosVehiculo;
  final String? vehiculo;
  final double? calificacion;
  final int resenas;
  final double? precioMaxKm;

  bool get habilitado => servicio == 'habilitado';

  /// Asientos que puede ofrecer: los del vehículo menos el suyo.
  int get asientosMaximos {
    final n = (asientosVehiculo ?? 5) - 1;
    return n < 1 ? 1 : n;
  }
}

/// POST /api/conductor-foraneo/cotizar. El tope por asiento es un límite de
/// CLOD; el precio lo decide el taxista (no se muestra ningún precio sugerido).
class CotizacionForanea {
  const CotizacionForanea({
    required this.distanciaKm,
    required this.duracionMin,
    required this.precioMaxAsiento,
    required this.tarifaServicioCliente,
  });

  factory CotizacionForanea.desdeJson(Map<String, dynamic> j) =>
      CotizacionForanea(
        distanciaKm: aDecimal(j['distancia_km']) ?? 0,
        duracionMin: aEntero(j['duracion_min']) ?? 0,
        precioMaxAsiento: aDecimal(j['precio_max_asiento']) ?? 0,
        tarifaServicioCliente: aDecimal(j['tarifa_servicio_cliente']) ?? 0,
      );

  final double distanciaKm;
  final int duracionMin;
  final double precioMaxAsiento;

  /// Cargo de servicio CLOD que paga el pasajero (no sale del precio del asiento).
  final double tarifaServicioCliente;
}

/// Lugar elegido con el buscador (GET /api/geocoding/buscar).
class LugarForaneo {
  const LugarForaneo({
    required this.direccion,
    required this.lat,
    required this.lng,
  });

  final String direccion;
  final double lat;
  final double lng;
}

/// Parada que el taxista agrega al publicar.
class ParadaNueva {
  ParadaNueva({
    required this.ciudad,
    required this.lugar,
    this.precioDesdeOrigen,
  });

  String ciudad;
  LugarForaneo lugar;

  /// Precio del asiento desde el origen hasta esta parada; sin él, el backend
  /// lo calcula proporcional a la distancia.
  double? precioDesdeOrigen;

  Map<String, dynamic> aJson() => {
    'ciudad': ciudad,
    'punto': lugar.direccion,
    'lat': lugar.lat,
    'lng': lugar.lng,
    'precio_desde_origen': ?precioDesdeOrigen,
  };
}

const Map<String, String> opcionesEquipaje = {
  'sin_equipaje': 'Sin equipaje',
  'pequeno': 'Equipaje pequeño',
  'mediano': 'Equipaje mediano',
  'grande': 'Equipaje grande',
};

String textoEstadoViaje(String estado) => switch (estado) {
  'publicado' => 'Publicado',
  'completo' => 'Lleno',
  'en_curso' => 'En curso',
  'finalizado' => 'Terminado',
  'cancelado' => 'Cancelado',
  _ => estado,
};

String textoEstadoReserva(String estado) => switch (estado) {
  'solicitada' => 'Por aprobar',
  'confirmada' => 'Confirmada',
  'abordo' => 'A bordo',
  'completada' => 'Completada',
  'rechazada' => 'No aprobada',
  'cancelada_pasajero' => 'Cancelada por el pasajero',
  'cancelada_conductor' => 'Cancelada por ti',
  'no_se_presento' => 'No se presentó',
  _ => estado,
};

/// Renglón de GET /api/conductor-foraneo/viajes.
class ViajeConductor {
  ViajeConductor({
    required this.id,
    required this.estado,
    required this.origenCiudad,
    required this.destinoCiudad,
    this.folio,
    this.salida,
    this.precioAsiento,
    this.asientosTotales = 0,
    this.asientosDisponibles = 0,
    this.porAprobar = 0,
    this.asientosReservados = 0,
  });

  factory ViajeConductor.desdeJson(Map<String, dynamic> j) => ViajeConductor(
    id: aEntero(j['id']) ?? 0,
    folio: aTexto(j['folio']),
    estado: aTexto(j['estado']) ?? 'publicado',
    origenCiudad: aTexto(j['origen_ciudad']) ?? '',
    destinoCiudad: aTexto(j['destino_ciudad']) ?? '',
    salida: _fecha(j['salida_en']),
    precioAsiento: aDecimal(j['precio_asiento']),
    asientosTotales: aEntero(j['asientos_totales']) ?? 0,
    asientosDisponibles: aEntero(j['asientos_disponibles']) ?? 0,
    porAprobar: aEntero(j['por_aprobar']) ?? 0,
    asientosReservados: aEntero(j['asientos_reservados']) ?? 0,
  );

  final int id;
  final String? folio;
  final String estado;
  final String origenCiudad;
  final String destinoCiudad;
  final DateTime? salida;
  final double? precioAsiento;
  final int asientosTotales;
  final int asientosDisponibles;
  final int porAprobar;
  final int asientosReservados;

  bool get vigente =>
      estado == 'publicado' || estado == 'completo' || estado == 'en_curso';
}

class ParadaViaje {
  ParadaViaje({
    required this.id,
    required this.ciudad,
    this.punto,
    this.precioDesdeOrigen,
  });

  factory ParadaViaje.desdeJson(Map<String, dynamic> j) => ParadaViaje(
    id: aEntero(j['id']) ?? 0,
    ciudad: aTexto(j['ciudad']) ?? '',
    punto: aTexto(j['punto']),
    precioDesdeOrigen: aDecimal(j['precio_desde_origen']),
  );

  final int id;
  final String ciudad;
  final String? punto;
  final double? precioDesdeOrigen;
}

/// Reserva vista por el taxista (detalle del viaje).
class ReservaConductor {
  ReservaConductor({
    required this.id,
    required this.estado,
    required this.asientos,
    this.folio,
    this.pasajero,
    this.telefono,
    this.calificacionPasajero,
    this.subeParadaId,
    this.bajaParadaId,
    this.montoAsientos,
    this.metodoPago = 'tarjeta',
    this.pagado = false,
    this.mensaje,
    this.responderAntes,
  });

  factory ReservaConductor.desdeJson(Map<String, dynamic> j) =>
      ReservaConductor(
        id: aEntero(j['id']) ?? 0,
        folio: aTexto(j['folio']),
        estado: aTexto(j['estado']) ?? 'solicitada',
        asientos: aEntero(j['asientos']) ?? 1,
        pasajero: aTexto(j['pasajero']),
        telefono: aTexto(j['pasajero_telefono']),
        calificacionPasajero: aDecimal(j['pasajero_calificacion']),
        subeParadaId: aEntero(j['sube_parada_id']),
        bajaParadaId: aEntero(j['baja_parada_id']),
        montoAsientos: aDecimal(j['monto_asientos']),
        metodoPago: aTexto(j['metodo_pago']) ?? 'tarjeta',
        pagado: aBooleano(j['pagado']) ?? false,
        mensaje: aTexto(j['mensaje_conductor']),
        responderAntes: _fecha(j['responder_antes']),
      );

  final int id;
  final String? folio;
  final String estado;
  final int asientos;
  final String? pasajero;

  /// Solo llega cuando la reserva está confirmada.
  final String? telefono;
  final double? calificacionPasajero;
  final int? subeParadaId;
  final int? bajaParadaId;

  /// Lo que es del taxista por los asientos (sin el cargo de servicio).
  final double? montoAsientos;
  final String metodoPago;
  final bool pagado;
  final String? mensaje;
  final DateTime? responderAntes;

  /// Con tarjeta sin pagar no puede abordar (`PAGO_PENDIENTE`).
  bool get esperandoPago => metodoPago == 'tarjeta' && !pagado;
}

/// GET /api/conductor-foraneo/viajes/:id.
class ViajeConductorDetalle {
  ViajeConductorDetalle({
    required this.viaje,
    required this.origenPunto,
    required this.destinoPunto,
    required this.paradas,
    required this.reservas,
    this.notas,
    this.reservaInmediata = true,
  });

  factory ViajeConductorDetalle.desdeJson(Map<String, dynamic> j) =>
      ViajeConductorDetalle(
        viaje: ViajeConductor.desdeJson(j),
        origenPunto: aTexto(j['origen_punto']) ?? '',
        destinoPunto: aTexto(j['destino_punto']) ?? '',
        notas: aTexto(j['notas']),
        reservaInmediata: aBooleano(j['reserva_inmediata']) ?? true,
        paradas: aListaMapas(j['paradas']).map(ParadaViaje.desdeJson).toList(),
        reservas: aListaMapas(
          j['reservas'],
        ).map(ReservaConductor.desdeJson).toList(),
      );

  final ViajeConductor viaje;
  final String origenPunto;
  final String destinoPunto;
  final String? notas;
  final bool reservaInmediata;
  final List<ParadaViaje> paradas;
  final List<ReservaConductor> reservas;

  /// Nombre del punto de subida o bajada de una reserva (null = origen/destino).
  String ciudadDe(int? paradaId, {required bool esSubida}) {
    if (paradaId == null) {
      return esSubida ? viaje.origenCiudad : viaje.destinoCiudad;
    }
    return paradas.where((p) => p.id == paradaId).firstOrNull?.ciudad ??
        (esSubida ? viaje.origenCiudad : viaje.destinoCiudad);
  }

  bool get puedeIniciar =>
      viaje.estado == 'publicado' || viaje.estado == 'completo';
  bool get enCurso => viaje.estado == 'en_curso';
  bool get puedeCancelar => puedeIniciar;
}

class MovimientoForaneo {
  MovimientoForaneo({
    required this.tipo,
    required this.monto,
    this.descripcion,
    this.fecha,
  });

  factory MovimientoForaneo.desdeJson(Map<String, dynamic> j) =>
      MovimientoForaneo(
        tipo: aTexto(j['tipo']) ?? '',
        monto: aDecimal(j['monto']) ?? 0,
        descripcion: aTexto(j['descripcion']),
        fecha: _fecha(j['created_at']),
      );

  final String tipo;
  final double monto;
  final String? descripcion;
  final DateTime? fecha;

  String get titulo => switch (tipo) {
    'ganancia_viaje_foraneo' => 'Asientos de viaje foráneo',
    'efectivo_cobrado' => 'Cobrado en efectivo',
    'liquidacion' => 'Liquidación',
    _ => descripcion ?? tipo,
  };
}

/// GET /api/conductor-foraneo/billetera (positivo = CLOD le debe).
class BilleteraForanea {
  BilleteraForanea({required this.saldo, required this.movimientos});

  factory BilleteraForanea.desdeJson(Map<String, dynamic> j) =>
      BilleteraForanea(
        saldo: aDecimal(aMapa(j['cuenta'])['saldo']) ?? 0,
        movimientos: aListaMapas(
          j['movimientos'],
        ).map(MovimientoForaneo.desdeJson).toList(),
      );

  final double saldo;
  final List<MovimientoForaneo> movimientos;
}
