import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static final FirebaseService _instance =
      FirebaseService._internal();

  factory FirebaseService() => _instance;

  FirebaseService._internal();

  final DatabaseReference db = FirebaseDatabase.instance.ref();
}