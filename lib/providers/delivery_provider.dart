import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/delivery.dart';
import '../models/status_entry.dart';
import '../services/database_helper.dart';
import '../services/firebase_service.dart';

class DeliveryProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  final _firebase = FirebaseService();

  List<Delivery> deliveries = [];
  bool usingLocalData = false;
  bool isSyncing = false;
  String? syncError;
  List<Delivery> newDeliveriesFromSync = [];
  Set<int> _knownIds = {};
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    deliveries = await _db.fetchAll();
    _knownIds = deliveries.map((d) => d.id).whereType<int>().toSet();
    notifyListeners();
    await _syncFromFirebase();
    _startPolling();
  }

  Future<void> _syncFromFirebase() async {
    isSyncing = true;
    notifyListeners();
    try {
      // ── Leitura do Firebase ──────────────────────────────────────────────
      final fbDeliveries = await _firebase.fetchAll();

      // Detecta novas entregas vindas de outros dispositivos
      if (_knownIds.isNotEmpty) {
        final brandNew = fbDeliveries
            .where((d) => d.id != null && !_knownIds.contains(d.id))
            .toList();
        if (brandNew.isNotEmpty) newDeliveriesFromSync = brandNew;
      }
      _knownIds = fbDeliveries.map((d) => d.id).whereType<int>().toSet();

      // Firebase respondeu com sucesso — conexão está ativa
      usingLocalData = false;
      deliveries = fbDeliveries;

      // ── Atualiza SQLite em paralelo (erro aqui não afeta o status de conexão) ──
      if (fbDeliveries.isNotEmpty) {
        _db.replaceAll(fbDeliveries).catchError((e) {
          debugPrint('[SQLite] replaceAll: $e');
        });
      }
    } catch (e) {
      debugPrint('[Firebase] sync: $e');
      syncError = e.toString();
      usingLocalData = true;
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  void clearNewDeliveries() => newDeliveriesFromSync = [];

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _syncFromFirebase());
  }

  Future<void> add(Delivery d) async {
    final id = await _db.insert(d);
    final withId = d.copyWith(id: id);
    await _db.insertHistory(StatusEntry(
      deliveryId: id,
      status: d.status,
      dataHora: d.dataHoraAtualizacao,
    ));
    try {
      await _firebase.upsert(withId);
    } catch (e) {
      debugPrint('[Firebase] add: $e');
    }
    deliveries = await _db.fetchAll();
    notifyListeners();
  }

  Future<void> update(Delivery d) async {
    final old = deliveries.firstWhere((x) => x.id == d.id, orElse: () => d);
    if (old.status != d.status) {
      await _db.insertHistory(StatusEntry(
        deliveryId: d.id!,
        status: d.status,
        dataHora: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
      ));
    }
    await _db.update(d);
    try {
      await _firebase.upsert(d);
    } catch (e) {
      debugPrint('[Firebase] update: $e');
    }
    deliveries = await _db.fetchAll();
    notifyListeners();
  }

  Future<void> remove(int id) async {
    await _db.delete(id);
    try {
      await _firebase.delete(id);
    } catch (e) {
      debugPrint('[Firebase] remove: $e');
    }
    deliveries = await _db.fetchAll();
    notifyListeners();
  }
}
