import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';
import 'database_factory.dart';

class DatabaseService {
  static DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  void setDatabaseForTesting(Database db) {
    _db = db;
  }

  @visibleForTesting
  Future<void> closeAndResetForTesting() async {
    await _db?.close();
    _db = null;
    _instance = DatabaseService._internal();
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await getDatabase();
    return _db!;
  }
}
