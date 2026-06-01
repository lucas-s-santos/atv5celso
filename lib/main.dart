import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as p;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ─── DESIGN TOKENS ───────────────────────────────────────────────────────────

class AppColors {
  static const primary = Color(0xFF1A237E);
  static const primaryLight = Color(0xFF3949AB);
  static const primaryDark = Color(0xFF0D1B6E);
  static const surface = Color(0xFFF5F7FF);
  static const cardBg = Colors.white;

  static const pending = Color(0xFF757575);
  static const inTransit = Color(0xFF1976D2);
  static const outForDelivery = Color(0xFFF57C00);
  static const delivered = Color(0xFF2E7D32);
}

// ─── MODEL ───────────────────────────────────────────────────────────────────

class Delivery {
  final int? id;
  final String codigo;
  final String nomeDestinatario;
  final String endereco;
  final String status;
  final double latitude;
  final double longitude;
  final String dataHoraAtualizacao;

  Delivery({
    this.id,
    required this.codigo,
    required this.nomeDestinatario,
    required this.endereco,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.dataHoraAtualizacao,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'codigo': codigo,
        'nomeDestinatario': nomeDestinatario,
        'endereco': endereco,
        'status': status,
        'latitude': latitude,
        'longitude': longitude,
        'dataHoraAtualizacao': dataHoraAtualizacao,
      };

  factory Delivery.fromMap(Map<String, dynamic> map) => Delivery(
        id: map['id'],
        codigo: map['codigo'],
        nomeDestinatario: map['nomeDestinatario'],
        endereco: map['endereco'],
        status: map['status'],
        latitude: map['latitude'],
        longitude: map['longitude'],
        dataHoraAtualizacao: map['dataHoraAtualizacao'],
      );

  Delivery copyWith({
    int? id,
    String? codigo,
    String? nomeDestinatario,
    String? endereco,
    String? status,
    double? latitude,
    double? longitude,
    String? dataHoraAtualizacao,
  }) =>
      Delivery(
        id: id ?? this.id,
        codigo: codigo ?? this.codigo,
        nomeDestinatario: nomeDestinatario ?? this.nomeDestinatario,
        endereco: endereco ?? this.endereco,
        status: status ?? this.status,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        dataHoraAtualizacao: dataHoraAtualizacao ?? this.dataHoraAtualizacao,
      );
}

// ─── DATABASE ────────────────────────────────────────────────────────────────

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;
  DatabaseHelper._();

  Future<Database> get database async => _db ??= await _initDb();

  Future<Database> _initDb() async {
    final path = p.join(await getDatabasesPath(), 'entregas.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute('''
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
      '''),
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
    return (await db.query('deliveries', orderBy: 'id DESC'))
        .map(Delivery.fromMap)
        .toList();
  }

  Future<int> delete(int id) async {
    final db = await database;
    return db.delete('deliveries', where: 'id = ?', whereArgs: [id]);
  }
}

// ─── LOCATION SERVICE ────────────────────────────────────────────────────────

class LocationService {
  static const _mockLat = -23.5505;
  static const _mockLon = -46.6333;

  Future<({double latitude, double longitude, bool isMock})>
      getCurrentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return (latitude: _mockLat, longitude: _mockLon, isMock: true);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 20), onTimeout: () => throw Exception());
      return (latitude: pos.latitude, longitude: pos.longitude, isMock: false);
    } catch (_) {
      return (latitude: _mockLat, longitude: _mockLon, isMock: true);
    }
  }
}

// ─── GEOCODING SERVICE ───────────────────────────────────────────────────────

class GeocodingService {
  static const _url = 'https://nominatim.openstreetmap.org/search';

  Future<String?> reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse').replace(
        queryParameters: {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'format': 'json',
          'addressdetails': '1',
        },
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'atv5-entregas-flutter/1.0',
        'Accept-Language': 'pt-BR,pt',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final road    = addr['road'] ?? addr['pedestrian'] ?? addr['path'] ?? '';
          final number  = addr['house_number'] ?? '';
          final city    = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? '';
          final state   = addr['state'] ?? '';
          final parts   = [
            if (road.isNotEmpty) road + (number.isNotEmpty ? ', $number' : ''),
            if (city.isNotEmpty) city,
            if (state.isNotEmpty) state,
          ];
          if (parts.isNotEmpty) return parts.join(' — ');
        }
        return data['display_name'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<({double latitude, double longitude})?> geocode(String address) async {
    try {
      final uri = Uri.parse(_url).replace(queryParameters: {
        'q': address,
        'format': 'json',
        'limit': '1',
        'addressdetails': '0',
      });
      final response = await http.get(uri, headers: {
        'User-Agent': 'atv5-entregas-flutter/1.0',
        'Accept-Language': 'pt-BR,pt',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        if (data.isNotEmpty) {
          return (
            latitude: double.parse(data[0]['lat'] as String),
            longitude: double.parse(data[0]['lon'] as String),
          );
        }
      }
    } catch (_) {}
    return null;
  }
}

// ─── PROVIDER ────────────────────────────────────────────────────────────────

class DeliveryProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  List<Delivery> deliveries = [];

  Future<void> load() async {
    deliveries = await _db.fetchAll();
    notifyListeners();
  }

  Future<void> add(Delivery d) async { await _db.insert(d); await load(); }
  Future<void> update(Delivery d) async { await _db.update(d); await load(); }
  Future<void> remove(int id) async { await _db.delete(id); await load(); }
}

// ─── HELPERS ─────────────────────────────────────────────────────────────────

Color statusColor(String status) {
  switch (status) {
    case 'entregue':        return AppColors.delivered;
    case 'saiu para entrega': return AppColors.outForDelivery;
    case 'em transporte':   return AppColors.inTransit;
    default:                return AppColors.pending;
  }
}

IconData statusIcon(String status) {
  switch (status) {
    case 'entregue':          return Icons.check_circle;
    case 'saiu para entrega': return Icons.local_shipping;
    case 'em transporte':     return Icons.airport_shuttle;
    default:                  return Icons.hourglass_empty;
  }
}

// ─── MAIN ────────────────────────────────────────────────────────────────────

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => DeliveryProvider(),
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Entregas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

// ─── HOME SCREEN ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final deliveries = provider.deliveries;

    final pendentes    = deliveries.where((d) => d.status == 'pendente').length;
    final emRota       = deliveries.where((d) => d.status == 'em transporte').length;
    final saiuEntrega  = deliveries.where((d) => d.status == 'saiu para entrega').length;
    final entregues    = deliveries.where((d) => d.status == 'entregue').length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── AppBar com gradiente ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryDark, AppColors.primaryLight],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(Icons.local_shipping,
                          color: Colors.white70, size: 32),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Entregas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '${deliveries.length} registro${deliveries.length != 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.map_outlined),
                tooltip: 'Mapa de Entregas',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DeliveriesMapScreen())),
              ),
              const SizedBox(width: 4),
            ],
          ),

          // ── Stats bar ────────────────────────────────────────────────────
          if (deliveries.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    _StatChip(label: 'Pendente',  value: pendentes,   color: AppColors.pending),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Transporte', value: emRota,     color: AppColors.inTransit),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Saiu',       value: saiuEntrega,color: AppColors.outForDelivery),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Entregue',   value: entregues,  color: AppColors.delivered),
                  ],
                ),
              ),
            ),

          // ── Lista de entregas ─────────────────────────────────────────────
          deliveries.isEmpty
              ? SliverFillRemaining(child: _EmptyState())
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _DeliveryCard(
                        delivery: deliveries[index],
                        provider: provider,
                      ),
                      childCount: deliveries.length,
                    ),
                  ),
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DeliveryFormScreen())),
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: const Text('Nova Entrega',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Stat chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping_outlined,
                size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhuma entrega cadastrada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Toque em + Nova Entrega para começar',
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

// ── Delivery card ────────────────────────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  final Delivery delivery;
  final DeliveryProvider provider;
  const _DeliveryCard({required this.delivery, required this.provider});

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    final color = statusColor(d.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Borda colorida esquerda
              Container(width: 5, color: color),
              // Conteúdo
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ícone de status
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(statusIcon(d.status), color: color, size: 26),
                      ),
                      const SizedBox(width: 12),
                      // Textos
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    d.codigo,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              d.nomeDestinatario,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              d.endereco,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            // Badge de status
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.4),
                                    width: 1),
                              ),
                              child: Text(
                                d.status,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // GPS + Data
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 12, color: Color(0xFF9CA3AF)),
                                const SizedBox(width: 3),
                                Text(
                                  '${d.latitude.toStringAsFixed(5)}, '
                                  '${d.longitude.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF9CA3AF)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.schedule,
                                    size: 12, color: Color(0xFF9CA3AF)),
                                const SizedBox(width: 3),
                                Text(
                                  d.dataHoraAtualizacao,
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF9CA3AF)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Menu
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            color: Color(0xFF9CA3AF), size: 20),
                        onSelected: (value) async {
                          if (value == 'editar') {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeliveryFormScreen(delivery: d),
                              ),
                            );
                          } else if (value == 'mapa') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeliveriesMapScreen(focused: d),
                              ),
                            );
                          } else if (value == 'excluir') {
                            _confirmDelete(context);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'editar',
                            child: Row(children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Editar'),
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'mapa',
                            child: Row(children: [
                              Icon(Icons.map_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Ver no mapa'),
                            ]),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'excluir',
                            child: Row(children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red[400]),
                              const SizedBox(width: 10),
                              Text('Excluir',
                                  style: TextStyle(color: Colors.red[400])),
                            ]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir entrega?'),
        content: Text(
            'A entrega "${delivery.codigo}" será removida permanentemente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.remove(delivery.id!);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

// ─── FORM SCREEN ─────────────────────────────────────────────────────────────

class DeliveryFormScreen extends StatefulWidget {
  final Delivery? delivery;
  const DeliveryFormScreen({super.key, this.delivery});

  @override
  State<DeliveryFormScreen> createState() => _DeliveryFormScreenState();
}

class _DeliveryFormScreenState extends State<DeliveryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codigoCtrl;
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _enderecoCtrl;
  late String _status;
  double? _lat;
  double? _lon;
  bool _isMock = false;
  bool _loadingGps = false;
  bool _loadingGeocode = false;
  bool _saving = false;
  final MapController _mapController = MapController();

  bool get _isEdit => widget.delivery != null;
  bool get _hasGps => _lat != null && _lon != null;

  static const _statusOptions = [
    'pendente',
    'saiu para entrega',
    'em transporte',
    'entregue',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.delivery;
    _codigoCtrl = TextEditingController(text: d?.codigo ?? '');
    _nomeCtrl = TextEditingController(text: d?.nomeDestinatario ?? '');
    _enderecoCtrl = TextEditingController(text: d?.endereco ?? '');
    _status = d?.status ?? 'pendente';
    if (d != null) {
      _lat = d.latitude;
      _lon = d.longitude;
    } else {
      _obterGps();
    }
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nomeCtrl.dispose();
    _enderecoCtrl.dispose();
    super.dispose();
  }

  Future<void> _obterGps() async {
    setState(() => _loadingGps = true);
    final pos = await LocationService().getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _lat = pos.latitude;
      _lon = pos.longitude;
      _isMock = pos.isMock;
      _loadingGps = false;
    });
    _moveMap();
    final address = await GeocodingService().reverseGeocode(pos.latitude, pos.longitude);
    if (mounted && address != null) {
      setState(() => _enderecoCtrl.text = address);
    }
  }

  Future<void> _geocodeAddress() async {
    final address = _enderecoCtrl.text.trim();
    if (address.isEmpty) return;
    setState(() => _loadingGeocode = true);
    final result = await GeocodingService().geocode(address);
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _lat = result.latitude;
        _lon = result.longitude;
        _isMock = false;
        _loadingGeocode = false;
      });
      _moveMap();
    } else {
      setState(() => _loadingGeocode = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Endereço não encontrado. Tente ser mais específico.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _moveMap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _lat != null) {
        try {
          _mapController.move(LatLng(_lat!, _lon!), 15);
        } catch (_) {}
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasGps) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Defina a localização antes de salvar.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      if (_isEdit) {
        await context.read<DeliveryProvider>().update(
              widget.delivery!.copyWith(
                codigo: _codigoCtrl.text.trim(),
                nomeDestinatario: _nomeCtrl.text.trim(),
                endereco: _enderecoCtrl.text.trim(),
                status: _status,
                latitude: _lat,
                longitude: _lon,
                dataHoraAtualizacao: now,
              ),
            );
      } else {
        await context.read<DeliveryProvider>().add(
              Delivery(
                codigo: _codigoCtrl.text.trim(),
                nomeDestinatario: _nomeCtrl.text.trim(),
                endereco: _enderecoCtrl.text.trim(),
                status: _status,
                latitude: _lat!,
                longitude: _lon!,
                dataHoraAtualizacao: now,
              ),
            );
      }

      if (!mounted) return;
      if (_isMock) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS indisponível — localização simulada.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          _isEdit ? 'Editar Entrega' : 'Nova Entrega',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Seção: Dados ────────────────────────────────────────────
              _SectionHeader(label: 'Dados da Entrega', icon: Icons.inventory_2_outlined),
              const SizedBox(height: 12),
              _inputField(
                controller: _codigoCtrl,
                label: 'Código da Entrega',
                icon: Icons.qr_code_2_outlined,
                validator: (v) => v!.trim().isEmpty ? 'Informe o código' : null,
              ),
              const SizedBox(height: 12),
              _inputField(
                controller: _nomeCtrl,
                label: 'Nome do Destinatário',
                icon: Icons.person_outline,
                validator: (v) => v!.trim().isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              // Campo de endereço com botão de busca
              TextFormField(
                controller: _enderecoCtrl,
                decoration: InputDecoration(
                  labelText: 'Endereço',
                  prefixIcon: const Icon(Icons.home_outlined),
                  suffixIcon: _loadingGeocode
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : Tooltip(
                          message: 'Buscar coordenadas pelo endereço',
                          child: IconButton(
                            icon: const Icon(Icons.search,
                                color: AppColors.primaryLight),
                            onPressed: _geocodeAddress,
                          ),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primaryLight, width: 2),
                  ),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Informe o endereço' : null,
              ),
              const SizedBox(height: 12),
              // Dropdown de status
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(statusIcon(_status),
                      color: statusColor(_status), size: 22),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primaryLight, width: 2),
                  ),
                ),
                items: _statusOptions
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Row(children: [
                            Icon(statusIcon(s),
                                size: 16, color: statusColor(s)),
                            const SizedBox(width: 8),
                            Text(s),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),

              const SizedBox(height: 24),
              // ── Seção: Localização ──────────────────────────────────────
              _SectionHeader(label: 'Localização GPS', icon: Icons.my_location),
              const SizedBox(height: 12),

              // Card GPS
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(_hasGps ? 0 : 16),
                    bottomRight: Radius.circular(_hasGps ? 0 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Coordenadas (esquerda)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CoordRow(
                            label: 'LAT',
                            value: _hasGps
                                ? _lat!.toStringAsFixed(6)
                                : '—',
                            loading: _loadingGps,
                          ),
                          const SizedBox(height: 6),
                          _CoordRow(
                            label: 'LNG',
                            value: _hasGps
                                ? _lon!.toStringAsFixed(6)
                                : '—',
                            loading: _loadingGps,
                          ),
                          if (_isMock && _hasGps) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.warning_amber,
                                    size: 13, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  'Localização simulada',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange[700]),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Botão GPS (direita)
                    ElevatedButton.icon(
                      onPressed: _loadingGps ? null : _obterGps,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        elevation: 2,
                      ),
                      icon: _loadingGps
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.gps_fixed, size: 18),
                      label: const Text('Obter GPS',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ],
                ),
              ),

              // Mini-mapa colado abaixo do card GPS
              if (_hasGps)
                SizedBox(
                  height: 220,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: LatLng(_lat!, _lon!),
                            initialZoom: 15,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.atv5',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(_lat!, _lon!),
                                  width: 40,
                                  height: 48,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: statusColor(_status),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: statusColor(_status)
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                            Icons.local_shipping,
                                            color: Colors.white,
                                            size: 14),
                                      ),
                                      CustomPaint(
                                        size: const Size(12, 8),
                                        painter: _TrianglePainter(
                                            statusColor(_status)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Overlay GPS no canto direito do mini-mapa
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _GpsCornerWidget(
                            lat: _lat!,
                            lon: _lon!,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              // ── Botão salvar ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(_isEdit ? Icons.save_outlined : Icons.check_circle_outline),
                  label: Text(
                    _saving
                        ? 'Salvando...'
                        : _isEdit
                            ? 'Salvar Alterações'
                            : 'Cadastrar Entrega',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryLight),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryLight,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
            child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
      ],
    );
  }
}

// ── Coord row ────────────────────────────────────────────────────────────────

class _CoordRow extends StatelessWidget {
  final String label;
  final String value;
  final bool loading;
  const _CoordRow(
      {required this.label, required this.value, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 8),
        loading
            ? const SizedBox(
                width: 60,
                height: 10,
                child: LinearProgressIndicator(minHeight: 2),
              )
            : Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w500,
                ),
              ),
      ],
    );
  }
}

// ── GPS corner widget ─────────────────────────────────────────────────────────

class _GpsCornerWidget extends StatelessWidget {
  final double lat;
  final double lon;
  const _GpsCornerWidget({required this.lat, required this.lon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'GPS',
                style: TextStyle(
                  color: Color(0xFF4ADE80),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            lat.toStringAsFixed(5),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            lon.toStringAsFixed(5),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Triangle painter (ponteiro do marcador) ───────────────────────────────────

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = ui.Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

// ─── ALL DELIVERIES MAP SCREEN ───────────────────────────────────────────────

class DeliveriesMapScreen extends StatefulWidget {
  final Delivery? focused;
  const DeliveriesMapScreen({super.key, this.focused});

  @override
  State<DeliveriesMapScreen> createState() => _DeliveriesMapScreenState();
}

class _DeliveriesMapScreenState extends State<DeliveriesMapScreen> {
  Delivery? _selected;
  final MapController _mapController = MapController();
  LatLng _mapCenter = const LatLng(-23.5505, -46.6333);

  @override
  void initState() {
    super.initState();
    _selected = widget.focused;
    if (widget.focused != null) {
      _mapCenter =
          LatLng(widget.focused!.latitude, widget.focused!.longitude);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(_mapCenter, 14);
      });
    }
  }

  Future<void> _goToMyLocation() async {
    final pos = await LocationService().getCurrentPosition();
    if (mounted) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = context.watch<DeliveryProvider>().deliveries;

    final LatLng center = widget.focused != null
        ? LatLng(widget.focused!.latitude, widget.focused!.longitude)
        : (deliveries.isNotEmpty
            ? LatLng(deliveries.first.latitude, deliveries.first.longitude)
            : const LatLng(-23.5505, -46.6333));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Mapa de Entregas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // ── Mapa ────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
              onTap: (tapPos, latLng) => setState(() => _selected = null),
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  setState(() => _mapCenter = pos.center);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.atv5',
              ),
              MarkerLayer(
                markers: deliveries.map((d) {
                  final color = statusColor(d.status);
                  final isSelected = _selected?.id == d.id;
                  return Marker(
                    point: LatLng(d.latitude, d.longitude),
                    width: 70,
                    height: 80,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selected = d);
                        _mapController.move(
                            LatLng(d.latitude, d.longitude), 15);
                      },
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isSelected ? 52 : 44,
                            height: isSelected ? 52 : 44,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white,
                                  width: isSelected ? 3 : 2),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: isSelected ? 12 : 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              statusIcon(d.status),
                              color: Colors.white,
                              size: isSelected ? 26 : 22,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? color : Colors.white,
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.15),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              d.codigo,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF111827),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ── GPS no canto direito ────────────────────────────────────────
          Positioned(
            top: 12,
            right: 12,
            child: _GpsCornerWidget(
              lat: _mapCenter.latitude,
              lon: _mapCenter.longitude,
            ),
          ),

          // ── Card de entrega selecionada ─────────────────────────────────
          if (_selected != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: statusColor(_selected!.status)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            statusIcon(_selected!.status),
                            color: statusColor(_selected!.status),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_selected!.codigo} — ${_selected!.nomeDestinatario}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              Text(
                                _selected!.endereco,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF6B7280)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: statusColor(_selected!.status)
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                        color: statusColor(_selected!.status)
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      _selected!.status,
                                      style: TextStyle(
                                        color:
                                            statusColor(_selected!.status),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.location_on_outlined,
                                      size: 12, color: Color(0xFF9CA3AF)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${_selected!.latitude.toStringAsFixed(5)}, '
                                    '${_selected!.longitude.toStringAsFixed(5)}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // ── Botão minha localização ─────────────────────────────────────
          Positioned(
            bottom: _selected != null ? 140 : 20,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              heroTag: 'myLoc',
              elevation: 4,
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
