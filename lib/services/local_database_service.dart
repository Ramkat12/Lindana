import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:is_project_1/models/profile_response.dart';

class LocalDatabaseService {
  // Singleton Pattern
  LocalDatabaseService._privateConstructor();
  static final LocalDatabaseService instance = LocalDatabaseService._privateConstructor();

  static Database? _database;

  static const String dbName = 'lindana_local.db';
  static const int dbVersion = 1;

  static const String tableUser = 'local_user';
  static const String tableEmergencyContacts = 'local_emergency_contacts';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);

    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Create local_user table for login & profile session info
    await db.execute('''
      CREATE TABLE $tableUser (
        id TEXT PRIMARY KEY,
        name TEXT,
        email TEXT,
        phone_number TEXT,
        profile_image TEXT,
        user_type TEXT,
        role_id INTEGER,
        access_token TEXT,
        refresh_token TEXT
      )
    ''');

    // 2. Create local_emergency_contacts table for offline contacts
    await db.execute('''
      CREATE TABLE $tableEmergencyContacts (
        id INTEGER PRIMARY KEY,
        contact_name TEXT,
        contact_number TEXT,
        email_contact TEXT
      )
    ''');
  }

  // ── USER SESSION OPERATIONS ──────────────────────────────────────────────

  /// Stores user details and access/refresh tokens locally
  Future<void> saveSession({
    required String id,
    required String name,
    required String email,
    required String? phoneNumber,
    required String? profileImage,
    required String userType,
    required int roleId,
    required String accessToken,
    required String refreshToken,
  }) async {
    final db = await database;
    
    final userMap = {
      'id': id,
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
      'profile_image': profileImage,
      'user_type': userType,
      'role_id': roleId,
      'access_token': accessToken,
      'refresh_token': refreshToken,
    };

    await db.insert(
      tableUser,
      userMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves the stored local user session if it exists
  Future<Map<String, dynamic>?> getSession() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableUser);

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  /// Updates only the tokens in the existing session
  Future<void> updateTokens(String accessToken, String refreshToken) async {
    final db = await database;
    await db.update(
      tableUser,
      {
        'access_token': accessToken,
        'refresh_token': refreshToken,
      },
    );
  }

  /// Clears user session upon logging out
  Future<void> clearSession() async {
    final db = await database;
    await db.delete(tableUser);
  }

  // ── EMERGENCY CONTACTS OPERATIONS ────────────────────────────────────────

  /// Overwrites current local emergency contacts with the synced list from API
  Future<void> saveEmergencyContacts(List<EmergencyContact> contacts) async {
    final db = await database;

    // Use a transaction to clear existing contacts and insert new ones
    await db.transaction((txn) async {
      await txn.delete(tableEmergencyContacts);
      for (var contact in contacts) {
        await txn.insert(
          tableEmergencyContacts,
          {
            'id': contact.id,
            'contact_name': contact.contactName,
            'contact_number': contact.contactNumber,
            'email_contact': contact.emailContact,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Fetches saved offline emergency contacts from SQLite database
  Future<List<EmergencyContact>> getLocalEmergencyContacts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableEmergencyContacts);

    return List.generate(maps.length, (i) {
      return EmergencyContact(
        id: maps[i]['id'] as int,
        contactName: maps[i]['contact_name'] as String,
        contactNumber: maps[i]['contact_number'] as String,
        emailContact: maps[i]['email_contact'] as String?,
      );
    });
  }

  /// Clears local emergency contacts database cache
  Future<void> clearLocalEmergencyContacts() async {
    final db = await database;
    await db.delete(tableEmergencyContacts);
  }
}
