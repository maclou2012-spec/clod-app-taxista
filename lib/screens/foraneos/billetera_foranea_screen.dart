import 'package:flutter/material.dart';

import '../../models/foraneo_conductor.dart';
import '../../services/foraneo_conductor_service.dart';
import '../../theme/clod_theme.dart';
import '../../utils/errores_api.dart';
import '../../utils/fechas.dart';
import '../../utils/json.dart';
import '../../widgets/clod_app_bar.dart';

/// Billetera de viajes foráneos (GET /api/conductor-foraneo/billetera).
/// Positivo: CLOD te debe lo pagado con tarjeta. Negativo: el cargo de
/// servicio que cobraste en efectivo y debes depositar.
class BilleteraForaneaScreen extends StatefulWidget {
  const BilleteraForaneaScreen({super.key});

  @override
  State<BilleteraForaneaScreen> createState() => _BilleteraForaneaScreenState();
}

class _BilleteraForaneaScreenState extends State<BilleteraForaneaScreen> {
  BilleteraForanea? _billetera;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final b = await ForaneoConductorService().billetera();
      if (mounted) {
        setState(() {
          _billetera = b;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = ErrorApi.desde(e).mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = CLODColors.texto(context);
    final tenue = texto.withValues(alpha: 0.6);
    final b = _billetera;
    return Scaffold(
      appBar: const ClodAppBar(titulo: 'Ganancias foráneas'),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (b == null)
                    Text(_error ?? '', style: TextStyle(color: tenue))
                  else ...[
                    Card(
                      color: b.saldo < 0
                          ? CLODColors.azulMarino
                          : CLODColors.azulCLOD,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.saldo < 0
                                  ? 'Por depositar a CLOD'
                                  : 'Saldo a tu favor',
                              style: CLODTextStyles.bodyMedium.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              formatoPesos(b.saldo.abs()),
                              style: CLODTextStyles.headingLarge.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              b.saldo < 0
                                  ? 'Es el cargo de servicio CLOD que cobraste en efectivo. Soporte te dirá cómo depositarlo.'
                                  : 'Lo que pagaron con tarjeta por tus asientos; CLOD te lo transfiere en cada liquidación.',
                              style: CLODTextStyles.bodySmall.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Movimientos',
                      style: CLODTextStyles.headingSmall.copyWith(color: texto),
                    ),
                    if (b.movimientos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Aún no tienes movimientos.',
                          style: TextStyle(color: tenue),
                        ),
                      ),
                    for (final m in b.movimientos)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(m.titulo),
                        subtitle: Text(
                          [
                            if (m.descripcion != null) m.descripcion!,
                            if (m.fecha != null) textoFechaCorta(m.fecha!),
                          ].join(' · '),
                          style: CLODTextStyles.bodySmall.copyWith(
                            color: tenue,
                          ),
                        ),
                        trailing: Text(
                          '${m.monto < 0 ? '−' : '+'}${formatoPesos(m.monto.abs())}',
                          style: CLODTextStyles.bodyLarge.copyWith(
                            color: m.monto < 0 ? texto : CLODColors.azulCLOD,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
