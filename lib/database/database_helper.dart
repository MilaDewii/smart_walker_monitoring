import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  DatabaseHelper._init();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDB(
      'smartwalker.db',
    );

    return _database!;
  }

  Future<Database> _initDB(
    String filePath,
  ) async {
    final dbPath = await getDatabasesPath();

    final path = join(dbPath, filePath);

    print("Database path: $path");

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(
    Database db,
    int version,
  ) async {
    print("Creating SQLite tables...");

    await db.execute('''
  CREATE TABLE users(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nama TEXT,
    email TEXT UNIQUE,
    password TEXT,
    no_hp TEXT
)
  ''');

    await db.execute('''
  CREATE TABLE login_session(
    user_id TEXT PRIMARY KEY,
    email TEXT,
    is_login INTEGER
  )
  ''');

    await db.execute('''
CREATE TABLE profile_user(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nama TEXT,
  email TEXT,
  no_hp TEXT,
  foto TEXT,
  nama_lansia TEXT,
  umur_lansia INTEGER,
  jenis_kelamin_lansia TEXT
)
''');

    await db.execute('''
CREATE TABLE paired_walker(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  walker_id TEXT,
  paired_date TEXT
)
''');

    await db.execute('''
CREATE TABLE settings(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  geofence_radius INTEGER,

    warning_threshold INTEGER,
    danger_threshold INTEGER,

    mpu6050_calibration INTEGER,
    ultrasonic_calibration INTEGER,
    gps_calibration INTEGER,

    alert_sound INTEGER,
    vibration INTEGER,

    sound_mode TEXT
)
''');

    await db.execute('''
  CREATE TABLE emergency_contacts(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    contact_name TEXT,
    contact_number TEXT,
    relationship TEXT
  )
  ''');

    await db.execute('''
CREATE TABLE cache_history(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT,
  message TEXT,
  timestamp TEXT,
  status TEXT
)
''');
  }

  Future<void> checkTables() async {
    final db = await database;

    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );

    print("Tables:");
    print(result);
  }

  //Profile User CRUD
  Future<int> saveProfile({
    required String nama,
    required String email,
    required String noHp,
    required String foto,
    required String namaLansia,
    required int umurLansia,
    required String jenisKelaminLansia,
  }) async {
    final db = await database;

    return await db.insert(
      'profile_user',
      {
        'nama': nama,
        'email': email,
        'no_hp': noHp,
        'foto': foto,
        'nama_lansia': namaLansia,
        'umur_lansia': umurLansia,
        'jenis_kelamin_lansia': jenisKelaminLansia,
      },
    );
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final db = await database;

    final result = await db.query(
      'profile_user',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }

    return null;
  }

  Future<int> updateProfile({
    required int id,
    required String nama,
    required String email,
    required String noHp,
    required String foto,
    required String namaLansia,
    required int umurLansia,
    required String jenisKelaminLansia,
  }) async {
    final db = await database;

    return await db.update(
      'profile_user',
      {
        'nama': nama,
        'email': email,
        'no_hp': noHp,
        'foto': foto,
        'nama_lansia': namaLansia,
        'umur_lansia': umurLansia,
        'jenis_kelamin_lansia': jenisKelaminLansia,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteProfile(
    int id,
  ) async {
    final db = await database;

    return await db.delete(
      'profile_user',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  //Settings CRUD
  Future<int> saveSettings({
    required int geofenceRadius,
    required int warningThreshold,
    required int dangerThreshold,
    required int mpu6050Calibration,
    required int ultrasonicCalibration,
    required int gpsCalibration,
    required int alertSound,
    required int vibration,
    required String soundMode,
  }) async {
    final db = await database;

    return await db.insert(
      'settings',
      {
        'geofence_radius': geofenceRadius,
        'warning_threshold': warningThreshold,
        'danger_threshold': dangerThreshold,
        'mpu6050_calibration': mpu6050Calibration,
        'ultrasonic_calibration': ultrasonicCalibration,
        'gps_calibration': gpsCalibration,
        'alert_sound': alertSound,
        'vibration': vibration,
        'sound_mode': soundMode,
      },
    );
  }

  Future<Map<String, dynamic>?> getSettings() async {
    final db = await database;

    final result = await db.query(
      'settings',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }

    return null;
  }

  Future<int> updateSettings({
    required int id,
    required int geofenceRadius,
    required int warningThreshold,
    required int dangerThreshold,
    required int mpu6050Calibration,
    required int ultrasonicCalibration,
    required int gpsCalibration,
    required int alertSound,
    required int vibration,
    required String soundMode,
  }) async {
    final db = await database;

    return await db.update(
      'settings',
      {
        'geofence_radius': geofenceRadius,
        'warning_threshold': warningThreshold,
        'danger_threshold': dangerThreshold,
        'mpu6050_calibration': mpu6050Calibration,
        'ultrasonic_calibration': ultrasonicCalibration,
        'gps_calibration': gpsCalibration,
        'alert_sound': alertSound,
        'vibration': vibration,
        'sound_mode': soundMode,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSettings(
    int id,
  ) async {
    final db = await database;

    return await db.delete(
      'settings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  //Emergency Contacts CRUD
  Future<int> saveEmergencyContact({
    required String contactName,
    required String contactNumber,
    required String relationship,
  }) async {
    final db = await database;

    return await db.insert(
      'emergency_contacts',
      {
        'contact_name': contactName,
        'contact_number': contactNumber,
        'relationship': relationship,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    final db = await database;

    return await db.query(
      'emergency_contacts',
      orderBy: 'id DESC',
    );
  }

  Future<int> updateEmergencyContact({
    required int id,
    required String contactName,
    required String contactNumber,
    required String relationship,
  }) async {
    final db = await database;

    return await db.update(
      'emergency_contacts',
      {
        'contact_name': contactName,
        'contact_number': contactNumber,
        'relationship': relationship,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteEmergencyContact(
    int id,
  ) async {
    final db = await database;

    return await db.delete(
      'emergency_contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  //Paired Walker CRUD
  Future<int> savePairedWalker({
    required String walkerId,
    required String pairedDate,
  }) async {
    final db = await database;

    return await db.insert(
      'paired_walker',
      {
        'walker_id': walkerId,
        'paired_date': pairedDate,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getPairedWalkers() async {
    final db = await database;

    return await db.query(
      'paired_walker',
      orderBy: 'id DESC',
    );
  }

  Future<Map<String, dynamic>?> getLastPairedWalker() async {
    final db = await database;

    final result = await db.query(
      'paired_walker',
      orderBy: 'id DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }

    return null;
  }

  Future<int> updatePairedWalker({
    required int id,
    required String walkerId,
    required String pairedDate,
  }) async {
    final db = await database;

    return await db.update(
      'paired_walker',
      {
        'walker_id': walkerId,
        'paired_date': pairedDate,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePairedWalker(
    int id,
  ) async {
    final db = await database;

    return await db.delete(
      'paired_walker',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  //login session CRUD
  Future<int> saveLoginSession({
    required String userId,
    required String email,
    // required int isLogin,
  }) async {
    final db = await database;

    return await db.insert(
      'login_session',
      {
        'user_id': userId,
        'email': email,
        'is_login': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getLoginSession() async {
    final db = await database;

    final result = await db.query(
      'login_session',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }

    return null;
  }

  Future<int> updateLoginSession({
    required String userId,
    required String email,
    required int isLogin,
  }) async {
    final db = await database;

    return await db.update(
      'login_session',
      {
        'email': email,
        'is_login': isLogin,
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> logout() async {
    final db = await database;

    return await db.delete(
      'login_session',
    );
  }

  //Cache History CRUD
  Future<int> saveCacheHistory({
    required String title,
    required String message,
    required String timestamp,
    required String status,
  }) async {
    final db = await database;

    return await db.insert(
      'cache_history',
      {
        'title': title,
        'message': message,
        'timestamp': timestamp,
        'status': status,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getCacheHistory() async {
    final db = await database;

    return await db.query(
      'cache_history',
      orderBy: 'id DESC',
    );
  }

  Future<int> deleteCacheHistory(
    int id,
  ) async {
    final db = await database;

    return await db.delete(
      'cache_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearHistory() async {
    final db = await database;

    return await db.delete(
      'cache_history',
    );
  }

  //register user
  Future<int> registerUser({
    required String nama,
    required String email,
    required String password,
    required String noHp,
  }) async {
    final db = await instance.database;

    return await db.insert(
      'users',
      {
        'nama': nama,
        'email': email,
        'password': password,
        'no_hp': noHp,
      },
    );
  }

  Future<Map<String, dynamic>?> loginUser(
    String email,
    String password,
  ) async {
    final db = await instance.database;

    final result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }

    return null;
  }

  Future<bool> isEmailExist(String email) async {
    final db = await instance.database;

    final result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    return result.isNotEmpty;
  }
}
