class ViajeEnCursoArgs {
  const ViajeEnCursoArgs({
    required this.solicitudId,
    required this.pasajeroNombre,
    required this.origenDireccion,
    required this.destinoDireccion,
    required this.tarifa,
    required this.horaInicio,
    this.origenLat,
    this.origenLng,
    this.destinoLat,
    this.destinoLng,
    this.estado = 'aceptado',
  });

  final int solicitudId;
  final String pasajeroNombre;
  final String origenDireccion;
  final String destinoDireccion;
  final String tarifa;
  final DateTime horaInicio;

  // Nulos si el backend no trajo coordenadas — en ese caso el botón de
  // navegación externa simplemente no se muestra.
  final double? origenLat;
  final double? origenLng;
  final double? destinoLat;
  final double? destinoLng;

  // 'aceptado' (recién aceptada, yendo al pasajero), 'en_espera' (ya llegó,
  // esperando al pasajero) o 'en_curso' (viaje iniciado) — determina con qué
  // paso arranca ViajeEnCursoScreen. Por defecto 'aceptado', que es el
  // estado real justo al aceptar una solicitud nueva.
  final String estado;
}
