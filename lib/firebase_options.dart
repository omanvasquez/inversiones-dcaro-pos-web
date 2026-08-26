import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
    apiKey: 'AIzaSyDummyKeyForBuildOnly',
    appId: '1:160194275408:web:dummy',
    messagingSenderId: '160194275408',
    projectId: 'inversiones-dcaro',
    authDomain: 'inversiones-dcaro.firebaseapp.com',
    storageBucket: 'inversiones-dcaro.appspot.com',
  );
}
