import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAgLqK3_YPzgzc6BMoWyoW2wKvOX0Hp6mI',
    appId: '1:289853352690:web:1387c8dc6e3b25717cbe6b',
    messagingSenderId: '289853352690',
    projectId: 'eventflow-3541b',
    authDomain: 'eventflow-3541b.firebaseapp.com',
    storageBucket: 'eventflow-3541b.firebasestorage.app',
    measurementId: 'G-JS3J7696GM',
  );


  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAfrHY96J60TcNZYwptK1s3OgcX_sADTnw',
    appId: '1:289853352690:android:d107e71b9b53e0b87cbe6b',
    messagingSenderId: '289853352690',
    projectId: 'eventflow-3541b',
    storageBucket: 'eventflow-3541b.firebasestorage.app',
  );


  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDMxTm7VTMaro5o9MUA6nLag-vSrR-qHpk',
    appId: '1:289853352690:ios:2b9e84f81a1d40c27cbe6b',
    messagingSenderId: '289853352690',
    projectId: 'eventflow-3541b',
    storageBucket: 'eventflow-3541b.firebasestorage.app',
    iosBundleId: 'com.eventflow.eventflow',
  );

}