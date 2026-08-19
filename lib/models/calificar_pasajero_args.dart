import 'viaje_en_curso_args.dart';

class CalificarPasajeroArgs {
  const CalificarPasajeroArgs({required this.viajeId, required this.viajeArgs});

  final int viajeId;

  // Reutilizado para pasar pasajeroNombre/tarifa/etc. a ResumenViajeScreen
  // una vez que el taxista termina de calificar (u omite).
  final ViajeEnCursoArgs viajeArgs;
}
