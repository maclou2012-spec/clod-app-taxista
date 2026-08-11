class ViajeEnCursoArgs {
  const ViajeEnCursoArgs({
    required this.solicitudId,
    required this.pasajeroNombre,
    required this.origenDireccion,
    required this.destinoDireccion,
    required this.tarifa,
    required this.horaInicio,
  });

  final int solicitudId;
  final String pasajeroNombre;
  final String origenDireccion;
  final String destinoDireccion;
  final String tarifa;
  final DateTime horaInicio;
}
