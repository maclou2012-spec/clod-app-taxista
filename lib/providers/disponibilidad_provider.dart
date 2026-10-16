import 'dart:async';

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
///
/// También es la única fuente de verdad de la vigencia de la membresía
/// (membresiaVigente/membresiaVenceEn): un taxista sin membresía vigente
/// nunca debe aparecer como disponible, sin importar lo que diga el campo
/// "disponible" del perfil.
class DisponibilidadProvider extends ChangeNotifier {
  DisponibilidadProvider({
    ApiService? apiService,
    SocketService? socketService,
    LocationTrackingService? locationService,
  }) : _apiService = apiService ?? ApiService(),
       _socketService = socketService ?? SocketService(),
       _locationService = locationService ?? LocationTrackingService() {
    _membresiaVencidaSub = _socketService.membresiaVencida.listen(
      (_) => marcarMembresiaVencida(),
    );
  }

  final ApiService _apiService;
  final SocketService _socketService;
  final LocationTrackingService _locationService;
  StreamSubscription<Map<String, dynamic>>? _membresiaVencidaSub;

  bool disponible = false;
  bool cargando = false;
  bool cargandoEstadoInicial = true;
  bool _yaCargado = false;

  // true por defecto (optimista) hasta que cargarEstadoInicial() confirme
  // lo contrario — así un taxista con membresía vigente nunca ve el switch
  // deshabilitado por un instante mientras carga.
  bool membresiaVigente = true;
  DateTime? membresiaVenceEn;

  // Recordatorio de renovación, nunca un aviso de bloqueo — solo aplica si
  // la membresía SIGUE vigente (si ya venció, el switch ya está apagado y
  // muestra "Membresía no vigente", que es aviso suficiente).
  bool get debeAvisarVencimientoProximo {
    final vence = membresiaVenceEn;
    if (!membresiaVigente || vence == null) return false;
    final diasRestantes = vence
        .difference(DateTime.now())
        .inDays;
    return diasRestantes >= 0 && diasRestantes <= 5;
  }

  String? get mensajeVencimientoProximo {
    final vence = membresiaVenceEn;
    if (!debeAvisarVencimientoProximo || vence == null) return null;
    final dia = vence.day.toString().padLeft(2, '0');
    final mes = vence.month.toString().padLeft(2, '0');
    return 'Tu membresía vence el $dia/$mes';
  }

  // Pública (no solo interna) para que un cambio equivalente pueda
  // probarse directamente, sin necesitar un socket real conectado — ver
  // disponibilidad_provider_test.dart.
  void marcarMembresiaVencida() {
    membresiaVigente = false;
    disponible = false;
    notifyListeners();
  }

  // Idempotente a propósito: DashboardScreen la llama en cada initState
  // (puede volver a montarse varias veces en la sesión), pero el estado
  // real solo hace falta pedirlo una vez — los cambios posteriores ya
  // quedan reflejados en memoria por cambiarDisponibilidad. Esto también
  // cubre "al abrir la app, resincroniza y apaga el switch": el Dashboard
  // es la primera pantalla tras el login, así que esta es la resincronía.
  Future<void> cargarEstadoInicial() async {
    if (_yaCargado) return;
    _yaCargado = true;
    try {
      final resultado = await _apiService.obtenerMiPerfilTaxista();
      final taxista = resultado['taxista'] as Map<String, dynamic>?;

      final vigenteRaw = taxista?['membresia_vigente'];
      // Ausente -> se asume vigente (optimista) para no bloquear a nadie
      // por un campo que el backend todavía no manda en algún entorno.
      membresiaVigente =
          vigenteRaw == null || vigenteRaw == true || vigenteRaw == 1;

      final venceEnRaw = taxista?['vence_en'];
      membresiaVenceEn = venceEnRaw is String
          ? DateTime.tryParse(venceEnRaw)
          : null;

      final disponibleRaw = taxista?['disponible'];
      final disponibleGuardado = disponibleRaw == true || disponibleRaw == 1;
      // Nunca se resincroniza como disponible si la membresía no está
      // vigente, aunque el backend todavía tenga guardado "disponible: true"
      // de antes de que venciera.
      disponible = membresiaVigente && disponibleGuardado;
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
    } on MembresiaNoVigenteException {
      // Se queda en no disponible (no se revierte a "valorAnterior") y la
      // membresía queda marcada como no vigente de inmediato — así el
      // switch se deshabilita sin esperar un refresco aparte.
      disponible = false;
      membresiaVigente = false;
      rethrow;
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

  @override
  void dispose() {
    _membresiaVencidaSub?.cancel();
    super.dispose();
  }
}
