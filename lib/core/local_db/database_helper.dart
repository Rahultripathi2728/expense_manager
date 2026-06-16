import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;
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
          version: 2,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
        ),
      );
    } else {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);

      bool isUnencrypted = false;
      try {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.openRead(0, 16).first;
          final header = String.fromCharCodes(bytes);
          if (header.startsWith('SQLite format 3')) {
            isUnencrypted = true;
          }
        }
      } catch (e) {
        debugPrint('Error checking DB encryption: $e');
      }

      if (isUnencrypted) {
        await _migrateToEncrypted(path);
      }

      return await cipher.openDatabase(
        path,
        password: AppConstants.localDbEncryptionKey,
        version: 2,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    }
  }

  Future<void> _migrateToEncrypted(String path) async {
    debugPrint('Migrating unencrypted database to encrypted...');
    final oldPath = '${path}_old';
    
    final oldFile = File(path);
    await oldFile.rename(oldPath);

    final oldDb = await cipher.openDatabase(oldPath, password: '');
    
    final newDb = await cipher.openDatabase(
      path,
      password: AppConstants.localDbEncryptionKey,
      version: 2,
      onCreate: _createDB,
    );

    final tables = ['expenses', 'groups', 'group_members', 'settlements', 'sync_queue'];
    for (final table in tables) {
      try {
        final rows = await oldDb.query(table);
        if (rows.isNotEmpty) {
          final batch = newDb.batch();
          for (final row in rows) {
            batch.insert(table, row);
          }
          await batch.commit(noResult: true);
        }
      } catch (e) {
        debugPrint('Error migrating table $table: $e');
      }
    }

    await oldDb.close();
    await newDb.close();

    try {
      await File(oldPath).delete();
      final oldJournal = File('$oldPath-journal');
      if (await oldJournal.exists()) await oldJournal.delete();
      final oldWal = File('$oldPath-wal');
      if (await oldWal.exists()) await oldWal.delete();
    } catch (_) {}

    debugPrint('Migration complete.');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Recreate sync_queue with nullable payload to fix NOT NULL constraint bug
      await db.execute('DROP TABLE IF EXISTS sync_queue');
      const textType = 'TEXT NOT NULL';
      const textNullable = 'TEXT';
      await db.execute('''
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  collectionName $textType,
  documentId $textNullable,
  action $textType,
  payload $textNullable,
  createdAt $textType
)
''');
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
CREATE TABLE settlements (
  id $idType,
  groupId $textType,
  fromUserId $textType,
  toUserId $textType,
  amount $realType,
  settledExpenseIds $textType,
  createdAt $textType
)
''');

    await db.execute('''
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  collectionName $textType,
  documentId $textNullable,
  action $textType,
  payload $textNullable,
  createdAt $textType
)
''');
  }

  Future<void> clearAll() async {
    final db = await instance.database;
    await db.delete('expenses');
    await db.delete('groups');
    await db.delete('group_members');
    await db.delete('settlements');
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
