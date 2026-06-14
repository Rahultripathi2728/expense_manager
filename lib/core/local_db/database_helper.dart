import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/constants/app_constants.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper.instance);

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expense_manager.db');
    await _cleanupOldData(_database!);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await databaseFactory.openDatabase(
        filePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _createDB,
        ),
      );
    } else {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);

      return await openDatabase(
        path,
        version: 1,
        onCreate: _createDB,
      );
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const boolType = 'BOOLEAN NOT NULL';
    const textNullable = 'TEXT';

    await db.execute('''
CREATE TABLE expenses (
  id $idType,
  userId $textType,
  groupId $textNullable,
  description $textType,
  amount $realType,
  category $textType,
  expenseType $textType,
  splitType $textNullable,
  expenseDate $textType,
  isSettled $boolType,
  settledAt $textNullable,
  createdAt $textType
)
''');

    await db.execute('''
CREATE TABLE groups (
  id $idType,
  name $textType,
  joinCode $textType,
  createdBy $textType,
  createdAt $textType
)
''');

    await db.execute('''
CREATE TABLE group_members (
  id $idType,
  groupId $textType,
  userId $textType,
  joinedAt $textType,
  role $textType
)
''');

    await db.execute('''
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  collectionName $textType,
  documentId $textNullable,
  action $textType,
  payload $textType,
  createdAt $textType
)
''');
  }

  Future<void> clearAll() async {
    final db = await instance.database;
    await db.delete('expenses');
    await db.delete('groups');
    await db.delete('group_members');
    await db.delete('sync_queue');
  }

  Future<void> _cleanupOldData(Database db) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: AppConstants.cacheExpenseDays)).toIso8601String();
      await db.delete(
        'expenses',
        where: 'expenseDate < ?',
        whereArgs: [cutoff],
      );
    } catch (_) {}
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
