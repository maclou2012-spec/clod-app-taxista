import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taxiclod/screens/registro/datos_personales_screen.dart';
import 'package:taxiclod/services/api_service.dart';

class _ApiServiceFalso extends ApiService {
  _ApiServiceFalso({this.rechazarCodigoVendedor = false});

  bool rechazarCodigoVendedor;
  int llamadasAGuardar = 0;
  final List<String?> codigosVendedorRecibidos = [];

  @override
  Future<Map<String, dynamic>> obtenerUsuarioActual() async => {};

  @override
  Future<Map<String, dynamic>> obtenerMiPerfilTaxista() async => {};

  @override
  Future<Map<String, dynamic>> actualizarDatosPersonales({
    required String nombre,
    String? fechaNacimiento,
    String? curp,
    String? rfc,
    String? direccionCalle,
    String? direccionNumero,
    String? direccionColonia,
    String? direccionCp,
    String? direccionCiudad,
    String? contactoEmergenciaNombre,
    String? contactoEmergenciaTelefono,
    int? localidadId,
    String? codigoVendedor,
  }) async {
    llamadasAGuardar++;
    codigosVendedorRecibidos.add(codigoVendedor);
    if (rechazarCodigoVendedor && codigoVendedor != null) {
      throw CodigoVendedorInvalidoException('Ese código de vendedor no existe.');
    }
    return {};
  }
}

Future<void> pumpPantalla(WidgetTester tester, ApiService apiService) async {
  final router = GoRouter(
    initialLocation: '/registro-basico-taxista',
    routes: [
      GoRoute(
        path: '/registro-basico-taxista',
        builder: (context, state) => DatosPersonalesScreen(apiService: apiService),
      ),
      GoRoute(
        path: '/identificacion-oficial',
        builder: (context, state) =>
            const Scaffold(body: Text('Identificación oficial')),
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
}

Finder campoCodigoVendedor() => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.hintText == 'Código del vendedor',
);

void main() {
  testWidgets(
    'muestra la ayuda "¿Te invitó un vendedor de CLOD? Escribe su código"',
    (tester) async {
      await pumpPantalla(tester, _ApiServiceFalso());
      expect(
        find.text('¿Te invitó un vendedor de CLOD? Escribe su código'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'el campo de código de vendedor convierte a mayúsculas mientras se escribe',
    (tester) async {
      await pumpPantalla(tester, _ApiServiceFalso());

      await tester.enterText(campoCodigoVendedor(), 'abc-12');
      await tester.pump();

      final textField = tester.widget<TextField>(campoCodigoVendedor());
      expect(textField.controller?.text, 'ABC-12');
    },
  );

  testWidgets(
    'un código demasiado largo muestra el aviso de formato',
    (tester) async {
      await pumpPantalla(tester, _ApiServiceFalso());

      expect(find.textContaining('Solo letras, números y guiones'), findsNothing);

      await tester.enterText(campoCodigoVendedor(), 'A' * 21);
      await tester.pump();
      expect(find.textContaining('Solo letras, números y guiones'), findsOneWidget);
    },
  );

  testWidgets(
    'si el servidor rechaza el código de vendedor, reintenta sin él y '
    'continúa de todas formas (nunca se queda atorado aquí)',
    (tester) async {
      final apiFalso = _ApiServiceFalso(rechazarCodigoVendedor: true);
      await pumpPantalla(tester, apiFalso);

      await tester.enterText(find.byType(TextField).first, 'Juan Pérez');
      await tester.enterText(campoCodigoVendedor(), 'NOEXISTE');
      final contactoTelefono = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == '10 dígitos',
      );
      await tester.enterText(contactoTelefono, '2281234567');
      await tester.pump();

      await tester.ensureVisible(find.text('Continuar'));
      await tester.pump();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Identificación oficial'), findsOneWidget);
      expect(apiFalso.llamadasAGuardar, 2);
      expect(apiFalso.codigosVendedorRecibidos, ['NOEXISTE', null]);
    },
  );
}
