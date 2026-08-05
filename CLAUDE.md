# TaxiCLOD — Contexto del proyecto

App Flutter para taxistas independientes (licenciatarios) del sistema CLOD, en Veracruz, México.
Este es el proyecto `taxiclod_app` — la app del TAXISTA (no la de pasajeros, que se construye después).

## ⚖️ Reglas legales NO NEGOCIABLES

CLOD es un **directorio digital y servicio de licencia de marca**, NUNCA una "plataforma digital de
transporte" — esto evita la Reforma Laboral de Plataformas Digitales de México (junio 2025).

**Terminología obligatoria en TODO el código, textos, nombres de variables/funciones visibles al
usuario, y comentarios de UX:**
- Usar: "taxista", "licenciatario", "empresario independiente", "difusión de solicitudes",
  "disponibilidad voluntaria"
- NUNCA usar: "trabajador", "empleado", "asignación de viajes", "jornada laboral", "conductor
  asignado", "turno obligatorio"

**Reglas de UX obligatorias (aplican con más cuidado en la app nativa que en una app de chat, porque
una app da más sensación de control del sistema sobre el taxista):**
- El taxista SIEMPRE decide libremente cuándo conectarse/desconectarse (disponibilidad voluntaria) —
  nunca un horario impuesto por el sistema.
- El taxista SIEMPRE puede ignorar una solicitud de viaje sin ninguna consecuencia, penalización o
  registro negativo visible.
- La tarifa la define el propio taxista. Si se muestra un rango de referencia de zona, debe quedar
  claro que es solo informativo, NUNCA un precio sugerido o fijado por el sistema.
- El pago del viaje es directo entre pasajero y taxista — CLOD solo cobra la membresía fija (nunca
  comisión por viaje). Los textos de resumen de viaje deben reflejar esto ("cobro directo con el
  pasajero").
- Nunca implementar features de calificación que penalicen automáticamente (suspensión, bloqueo) —
  cualquier problema de seguridad de cuenta pasa a revisión manual de un admin, nunca acción
  automática punitiva.

## 🎨 Identidad visual (usar SIEMPRE estos valores exactos, no inventar variantes)

```dart
// Paleta de marca
const azulCLOD    = Color(0xFF1CA3E3); // primario — acciones, elementos activos
const azulMarino  = Color(0xFF1B3B7A); // secundario — acentos, texto sobre fondo claro-azul
const rojoUbicacion = Color(0xFFE63946); // SOLO para pines de mapa/ubicación, nunca UI general
const carbon      = Color(0xFF2B2B2E); // "negro" de la marca — texto principal, fondos oscuros
const grisClaro   = Color(0xFFF4F6F8); // fondos claros
```

- Tipografía de títulos/encabezados: **Poppins**, peso 600 (semibold)
- Tipografía de cuerpo/componentes: **Inter**, pesos 400/500
- TaxiCLOD (esta app) usa **carbón como base** con azul como acento — estética de "panel de control
  profesional" (fondos oscuros en pantallas de operación diaria). La app de pasajeros (CLOD, otro
  proyecto) es azul-sobre-claro, más cálida — no mezclar estilos entre ambas apps.

## 🏗️ Stack técnico de esta app

- Flutter + Dart, gestión de estado con `provider` o `riverpod`
- `dio` para llamadas HTTP al backend
- `socket_io_client` para tiempo real (disponibilidad, solicitudes de viaje, ubicación)
- `google_maps_flutter` + `geolocator` para mapas/ubicación
- `firebase_messaging` para notificaciones push (respaldo de Socket.io)
- `flutter_secure_storage` para guardar JWT/refresh token de forma segura
- Autenticación: Firebase Auth (teléfono+OTP, Google, Facebook, Apple) → el idToken de Firebase se
  manda al backend, que devuelve su propio JWT (15 min) + refresh token (30 días)

## 🔌 Backend (ya construido y en producción)

Base URL: `https://api.clod.info`

Endpoints relevantes para esta app (todos requieren `Authorization: Bearer <JWT>` salvo login):
- `POST /api/auth/login` — recibe `idToken` de Firebase (+ `nombre`, `rol`, `codigoReferido` si es
  registro nuevo)
- `POST /api/auth/refresh`, `POST /api/auth/logout`, `GET /api/auth/me`
- `GET/PUT /api/taxistas/perfil`, `PATCH /api/taxistas/disponibilidad`,
  `PATCH /api/taxistas/ubicacion`
- `POST/GET /api/taxistas/vehiculo`, `POST/GET /api/taxistas/documentos`
- `POST/DELETE /api/taxistas/caracteristicas`
- `GET /api/membresias/estado`, `GET /api/membresias/historial`, `POST /api/membresias/activar`
- `GET /api/referidos/mi-codigo`, `GET /api/referidos`, `GET /api/referidos/progreso`
- `POST /api/solicitudes`, `GET /api/solicitudes/:id`, `POST /api/solicitudes/:id/aceptar`,
  `POST /api/solicitudes/:id/completar`, `POST /api/solicitudes/:id/cancelar`,
  `GET /api/solicitudes/historial`

Socket.io (mismo dominio, mismo JWT en el handshake `auth.token`): salas `taxistas_disponibles` y
`solicitud_<id>`; eventos `taxista_disponible`, `taxista_no_disponible`, `actualizar_ubicacion`,
`unirse_solicitud`, `nueva_solicitud`, `solicitud_aceptada`, `ubicacion_taxista`,
`viaje_completado`, `viaje_cancelado`.

## 📱 Mapa de pantallas (26 total, 5 bloques — ya prototipadas visualmente, construir en este orden)

1. **Onboarding**: splash → ingreso teléfono → verificación OTP → registro datos básicos (o login
   social directo)
2. **Registro del licenciatario**: contrato → datos del taxista → verificación facial de
   referencia → vehículo → clase/plus → tarifa propia → documentos → pantalla "en revisión"
3. **Membresía**: selección diaria ($39 MXN)/mensual ($499 MXN, con badge "promo") → estado de
   membresía activa
4. **Operación diaria**: home/dashboard oscuro con toggle de disponibilidad voluntaria →
   verificación facial de inicio de turno → pantalla "disponible, esperando solicitudes" →
   tarjeta de nueva solicitud (aceptar/ignorar libres) → viaje en curso con mapa → resumen de
   viaje completado
5. **Soporte y cuenta**: perfil → historial de viajes → referidos (código + barra de progreso) →
   configuración (contacto de emergencia, dispositivos vinculados, contrato) → ayuda

## Estado actual

Proyecto recién creado con `flutter create`, sin funcionalidad aún — es el punto de partida. Repo
git aún no inicializado. Próximo paso: inicializar git, agregar dependencias al `pubspec.yaml`,
crear estructura de carpetas (`lib/screens`, `lib/widgets`, `lib/services`, `lib/models`,
`lib/theme`, `lib/utils`), definir el archivo de tema con la paleta/tipografía, y empezar a
construir el Bloque 1.
