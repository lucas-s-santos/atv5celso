import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/delivery.dart';
import '../models/status_entry.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;
  DatabaseHelper._();

  Future<Database> get database async => _db ??= await _initDb();

  Future<Database> _initDb() async {
    final path = p.join(await getDatabasesPath(), 'entregas.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE deliveries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            codigo TEXT NOT NULL,
            nomeDestinatario TEXT NOT NULL,
            endereco TEXT NOT NULL,
            status TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            dataHoraAtualizacao TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE status_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            deliveryId INTEGER NOT NULL,
            status TEXT NOT NULL,
            dataHora TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS status_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              deliveryId INTEGER NOT NULL,
              status TEXT NOT NULL,
              dataHora TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  Future<int> insert(Delivery d) async {
    final db = await database;
    return db.insert('deliveries', d.toMap()..remove('id'));
  }

  Future<int> update(Delivery d) async {
    final db = await database;
    return db.update('deliveries', d.toMap(), where: 'id = ?', whereArgs: [d.id]);
  }

  Future<List<Delivery>> fetchAll() async {
    final db = await database;
    return (await db.query('deliveries', orderBy: 'id DESC')).map(Delivery.fromMap).toList();
  }

  Future<int> delete(int id) async {
    final db = await database;
    await db.delete('status_history', where: 'deliveryId = ?', whereArgs: [id]);
    return db.delete('deliveries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceAll(List<Delivery> deliveries) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('deliveries');
      for (final d in deliveries) {
        await txn.insert('deliveries', d.toMap());
      }
    });
  }

  Future<void> insertHistory(StatusEntry entry) async {
    final db = await database;
    await db.insert('status_history', entry.toMap()..remove('id'));
  }

  Future<List<StatusEntry>> fetchHistory(int deliveryId) async {
    final db = await database;
    return (await db.query(
      'status_history',
      where: 'deliveryId = ?',
      whereArgs: [deliveryId],
      orderBy: 'id DESC',
    )).map(StatusEntry.fromMap).toList();
  }
}
