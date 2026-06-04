import 'package:firebase_database/firebase_database.dart';

class MonitoringService {
  MonitoringService(this.walkerId);

  final String walkerId;

  Stream<DatabaseEvent> getData() {
    return FirebaseDatabase.instance.ref('Walkers/$walkerId').onValue;
  }
}
