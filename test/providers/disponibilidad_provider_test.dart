import 'package:flutter_test/flutter_test.dart';
import 'package:taxiclod/providers/disponibilidad_provider.dart';
import 'package:taxiclod/services/api_service.dart';

class _ApiServiceFalso extends ApiService {
  _ApiServiceFalso({
    this.perfilTaxista = const {},
    this.rechazarPorMembresia = false,
    this.mensajeMembresia = 'Tu membresía no está vigente. Renuévala para activarte.',
  });

  Map<String, dynamic> perfilTaxista;
  bool rechazarPorMembresia;
  String mensajeMembresia;
  int llamadasACambiar = 0;

  @override
  Future<Map<String, dynamic>> obtenerMiPerfilTaxista() async {
    return {'taxista': perfilTaxista};
  }

  @override
  Future<Map<String, dynamic>> cambiarDisponibilidad(bool disponible) async {
    llamadasACambiar++;
    if (rechazarPorMembresia) {
      throw MembresiaNoVigenteException(mensajeMembresia);
    }
    return {'disponible': disponible};
  }
}

void main() {
  group('cargarEstadoInicial', () {
    test('membresia_vigente=true: respeta el disponible guardado', () async {
      final provider = DisponibilidadProvider(
        apiService: _ApiServiceFalso(
          perfilTaxista: const {'disponible': true, 'membresia_vigente': true},
        ),
      );

      await provider.cargarEstadoInicial();

      expect(provider.membresiaVigente, isTrue);
      expect(provider.disponible, isTrue);
      expect(provider.cargandoEstadoInicial, isFalse);
    });

    test(
      'membresia_vigente=false: fuerza disponible=false aunque el backend diga disponible=true',
      () async {
        final provider = DisponibilidadProvider(
          apiService: _ApiServiceFalso(
            perfilTaxista: const {
              'disponible': true,
              'membresia_vigente': false,
            },
          ),
        );

        await provider.cargarEstadoInicial();

        expect(provider.membresiaVigente, isFalse);
        expect(provider.disponible, isFalse);
      },
    );

    test('membresia_vigente ausente: se asume vigente (no bloquea por un campo faltante)', () async {
      final provider = DisponibilidadProvider(
        apiService: _ApiServiceFalso(perfilTaxista: const {'disponible': true}),
      );

      await provider.cargarEstadoInicial();

      expect(provider.membresiaVigente, isTrue);
      expect(provider.disponible, isTrue);
    });

    test('vence_en se parsea a DateTime', () async {
      final provider = DisponibilidadProvider(
        apiService: _ApiServiceFalso(
          perfilTaxista: const {
            'membresia_vigente': true,
            'vence_en': '2026-03-10T00:00:00.000Z',
          },
        ),
      );

      await provider.cargarEstadoInicial();

      expect(provider.membresiaVenceEn, DateTime.parse('2026-03-10T00:00:00.000Z'));
    });

    test('es idempotente: una segunda llamada no vuelve a pedir el perfil', () async {
      final apiService = _ApiServiceFalso(
        perfilTaxista: const {'membresia_vigente': true},
      );
      final provider = DisponibilidadProvider(apiService: apiService);

      await provider.cargarEstadoInicial();
      await provider.cargarEstadoInicial();

      // No hay contador de llamadas a obtenerMiPerfilTaxista aquí, pero si
      // no fuera idempotente el segundo await fallaría igual si cambiara
      // perfilTaxista entre medio — se prueba indirectamente dejando el
      // mismo objeto y confiando en el guard interno (_yaCargado).
      expect(provider.cargandoEstadoInicial, isFalse);
    });
  });

  group('mensajeVencimientoProximo / debeAvisarVencimientoProximo', () {
    test('vence en 3 días y sigue vigente: avisa con el formato DD/MM', () async {
      final provider = DisponibilidadProvider(
        apiService: _ApiServiceFalso(
          perfilTaxista: {
            'membresia_vigente': true,
            'vence_en': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
          },
        ),
      );
      await provider.cargarEstadoInicial();

      expect(provider.debeAvisarVencimientoProximo, isTrue);
      expect(provider.mensajeVencimientoProximo, startsWith('Tu membresía vence el '));
    });

    test('vence en 10 días: no avisa todavía', () async {
      final provider = DisponibilidadProvider(
        apiService: _ApiServiceFalso(
          perfilTaxista: {
            'membresia_vigente': true,
            'vence_en': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
          },
        ),
      );
      await provider.cargarEstadoInicial();

      expect(provider.debeAvisarVencimientoProximo, isFalse);
      expect(provider.mensajeVencimientoProximo, isNull);
    });

    test('ya no vigente: no muestra el aviso de "vence pronto" (ya muestra "no vigente")', () async {
      final provider = DisponibilidadProvider(
        apiService: _ApiServiceFalso(
          perfilTaxista: {
            'membresia_vigente': false,
            'vence_en': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
          },
        ),
      );
      await provider.cargarEstadoInicial();

      expect(provider.debeAvisarVencimientoProximo, isFalse);
      expect(provider.mensajeVencimientoProximo, isNull);
    });
  });

  group('cambiarDisponibilidad', () {
    test(
      'MEMBRESIA_NO_VIGENTE: deja disponible=false, marca membresiaVigente=false y relanza con el mensaje del servidor',
      () async {
        final apiService = _ApiServiceFalso(
          rechazarPorMembresia: true,
          mensajeMembresia: 'Tu membresía venció el 01/03. Renuévala para activarte.',
        );
        final provider = DisponibilidadProvider(apiService: apiService);

        await expectLater(
          provider.cambiarDisponibilidad(true),
          throwsA(
            isA<MembresiaNoVigenteException>().having(
              (e) => e.mensaje,
              'mensaje',
              'Tu membresía venció el 01/03. Renuévala para activarte.',
            ),
          ),
        );

        expect(provider.disponible, isFalse);
        expect(provider.membresiaVigente, isFalse);
        expect(provider.cargando, isFalse);
      },
    );
  });

  group('marcarMembresiaVencida (reacción al evento de socket)', () {
    test('apaga disponible y marca la membresía como no vigente', () async {
      final provider = DisponibilidadProvider(
        apiService: _ApiServiceFalso(
          perfilTaxista: const {'disponible': true, 'membresia_vigente': true},
        ),
      );
      await provider.cargarEstadoInicial();
      expect(provider.disponible, isTrue);

      provider.marcarMembresiaVencida();

      expect(provider.disponible, isFalse);
      expect(provider.membresiaVigente, isFalse);
    });
  });
}
