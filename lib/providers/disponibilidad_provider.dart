import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/location_tracking_service.dart';
import '../services/socket_service.dart';

/// Disponibilidad voluntaria del taxista — antes vivía solo dentro de
/// DashboardScreen; ahora el switch real está en el menú deslizable
/// (ClodDrawer) pero el panel también necesita mostrar un indicador del
/// mismo estado, así que ambos comparten esta única fuente de verdad (mismo
/// patrón que ThemeProvider). Conserva exactamente la misma lógica que
/// tenía el Dashboard: gate de verificación facial al activar, inicio/
/// detención del seguimiento de ubicación, y aviso por socket.
class DisponibilidadProvider extends ChangeNotifier {
  DisponibilidadProvider({
    ApiService? apiService,
    SocketService? socketService,
    LocationTrackingService? locationService,
  }) : _apiService = apiService ?? ApiService(),
       _socketService = socketService ?? SocketService(),
       _locationService = locationService ?? LocationTrackingService();

  final ApiService _apiService;
  final SocketService _socketService;
  final LocationTrackingService _locationService;

  bool disponible = false;
  bool cargando = false;
  bool cargandoEstadoInicial = true;
  bool _yaCargado = false;

  // Idempotente a propósito: DashboardScreen la llama en cada initState
  // (puede volver a montarse varias veces en la sesión), pero el estado
  // real solo hace falta pedirlo una vez — los cambios posteriores ya
  // quedan reflejados en memoria por cambiarDisponibilidad.
  Future<void> cargarEstadoInicial() async {
    if (_yaCargado) return;
    _yaCargado = true;
    try {
      final resultado = await _apiService.obtenerMiPerfilTaxista();
      final taxista = resultado['taxista'] as Map<String, dynamic>?;
      final disponibleRaw = taxista?['disponible'];
      disponible = disponibleRaw == true || disponibleRaw == 1;
    } catch (e) {
      // Se queda en "no disponible" por defecto si no se pudo consultar.
    } finally {
      cargandoEstadoInicial = false;
      notifyListeners();
    }
  }

  // El gate de verificación facial vive en la pantalla que abre el switch
  // (necesita hacer context.push), así que esta clase solo expone el
  // cambio de disponibilidad en sí — ver ClodDrawer._onToggleDisponibilidad
  // para el flujo completo con verificación incluida.
  Future<void> cambiarDisponibilidad(bool nuevoValor) async {
    final valorAnterior = disponible;
    disponible = nuevoValor;
    cargando = true;
    notifyListeners();

    try {
      await _apiService.cambiarDisponibilidad(nuevoValor);
      if (nuevoValor) {
        _socketService.emitirDisponible();
        _locationService.iniciar();
      } else {
        _socketService.emitirNoDisponible();
        _locationService.detener();
      }
    } catch (e) {
      disponible = valorAnterior;
      rethrow;
    } finally {
      cargando = false;
      notifyListeners();
    }
  }

  // Para cuando la pantalla necesita revertir visualmente el switch antes
  // de siquiera intentar la llamada (ej. el gate de verificación facial se
  // canceló).
  void establecerSinGuardar(bool valor) {
    disponible = valor;
    notifyListeners();
  }
}
