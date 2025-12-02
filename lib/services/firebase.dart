// lib/services/firebase.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Initialize Firebase using environment variables from .env
Future<void> initializeFirebase() async {
  final apiKey = dotenv.env['VITE_FIREBASE_API_KEY'];
  final authDomain = dotenv.env['VITE_FIREBASE_AUTH_DOMAIN'];
  final projectId = dotenv.env['VITE_FIREBASE_PROJECT_ID'];
  final storageBucket = dotenv.env['VITE_FIREBASE_STORAGE_BUCKET'];
  final messagingSenderId = dotenv.env['VITE_FIREBASE_MESSAGING_SENDER_ID'];
  final appId = dotenv.env['VITE_FIREBASE_APP_ID'];

  // Required fields check
  if (apiKey == null || projectId == null || appId == null) {
    throw Exception(
      'Firebase .env variables missing. Required: '
          'VITE_FIREBASE_API_KEY, VITE_FIREBASE_PROJECT_ID, VITE_FIREBASE_APP_ID',
    );
  }

  final options = FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    projectId: projectId,
    // These 3 can be empty but MUST NOT be null
    messagingSenderId: messagingSenderId ?? "",
    authDomain: authDomain ?? "",
    storageBucket: storageBucket ?? "",
  );

  await Firebase.initializeApp();
}

/// Firebase Auth instance
FirebaseAuth get auth => FirebaseAuth.instance;

/// Firestore instance
FirebaseFirestore get db => FirebaseFirestore.instance;
