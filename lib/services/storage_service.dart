import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService({FirebaseStorage? storage, FirebaseAuth? firebaseAuth})
      : _storage = storage ?? FirebaseStorage.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseStorage _storage;
  final FirebaseAuth _firebaseAuth;

  Future<String> subirDocumento(File archivo, String tipoDocumento) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) {
      throw StateError('No hay un usuario autenticado.');
    }

    // Misma ruta siempre para el mismo tipo de documento: al subir de nuevo
    // se sobrescribe el archivo anterior, no se acumulan versiones.
    final referencia = _storage.ref('documentos/$uid/$tipoDocumento.jpg');
    await referencia.putFile(archivo);
    return referencia.getDownloadURL();
  }
}
