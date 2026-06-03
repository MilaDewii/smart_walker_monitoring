import 'package:firebase_database/firebase_database.dart';

class HistoryService {
  final DatabaseReference _ref =
      FirebaseDatabase.instance.ref('history');

  Stream<DatabaseEvent> getHistory() {
    return _ref.onValue;
  }
}