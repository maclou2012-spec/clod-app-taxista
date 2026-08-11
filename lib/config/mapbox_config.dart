// El valor real se inyecta en tiempo de compilación con
// --dart-define-from-file=android/secrets.properties (ese archivo está
// gitignored — el token nunca queda hardcodeado aquí ni en ningún archivo
// versionado).
const String mapboxPublicToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');
