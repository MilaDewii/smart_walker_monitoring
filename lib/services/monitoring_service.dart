import 'package:firebase_database/firebase_database.dart';

class MonitoringService {

  final DatabaseReference ref =
      FirebaseDatabase.instance
          .ref("walkers/walker_001");

  Stream<DatabaseEvent> getData() {
    return ref.onValue;
  }
}