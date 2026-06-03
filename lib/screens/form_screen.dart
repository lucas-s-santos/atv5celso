import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../core/colors.dart';
import '../core/utils.dart';
import '../models/delivery.dart';
import '../providers/delivery_provider.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';

class FormScreen extends StatefulWidget {
  final Delivery? delivery;
  const FormScreen({super.key, this.delivery});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
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
    try {
      final address = await GeocodingService().reverseGeocode(pos.latitude, pos.longitude);
      if (mounted && address != null) setState(() => _enderecoCtrl.text = address);
    } catch (_) {
      // Sem internet: geocoding falha silenciosamente, usuário digita o endereço
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Endereço não encontrado. Tente ser mais específico.'),
          backgroundColor: Colors.red,
        ));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Defina a localização antes de salvar.'),
        backgroundColor: Colors.orange,
      ));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('GPS indisponível — localização simulada.'),
          backgroundColor: Colors.orange,
        ));
      }
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erro ao salvar: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEdit ? 'Editar Entrega' : 'Nova Entrega',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Seção Dados ──────────────────────────────────────────────
              _SectionHeader(label: 'Dados da Entrega', icon: Icons.inventory_2_outlined),
              const SizedBox(height: 12),
              _buildField(
                controller: _codigoCtrl,
                label: 'Código da Entrega',
                icon: Icons.qr_code_2_outlined,
                validator: (v) => v!.trim().isEmpty ? 'Informe o código' : null,
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _nomeCtrl,
                label: 'Nome do Destinatário',
                icon: Icons.person_outline_rounded,
                validator: (v) => v!.trim().isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              // Campo endereço com busca
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
                            icon: const Icon(Icons.search_rounded,
                                color: AppColors.primaryLight),
                            onPressed: _geocodeAddress,
                          ),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppColors.primaryLight, width: 2),
                  ),
                ),
                validator: (v) =>
                    v!.trim().isEmpty ? 'Informe o endereço' : null,
              ),
              const SizedBox(height: 12),
              // Dropdown status
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(statusIcon(_status),
                      color: statusColor(_status), size: 22),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppColors.primaryLight, width: 2),
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
              // ── Seção GPS ────────────────────────────────────────────────
              _SectionHeader(label: 'Localização GPS', icon: Icons.my_location_rounded),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CoordRow(
                            label: 'LAT',
                            value: _hasGps ? _lat!.toStringAsFixed(6) : '—',
                            loading: _loadingGps,
                          ),
                          const SizedBox(height: 6),
                          _CoordRow(
                            label: 'LNG',
                            value: _hasGps ? _lon!.toStringAsFixed(6) : '—',
                            loading: _loadingGps,
                          ),
                          if (_isMock && _hasGps) ...[
                            const SizedBox(height: 6),
                            Row(children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 13, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text('Localização simulada',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.orange[700])),
                            ]),
                          ],
                        ],
                      ),
                    ),
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
                          : const Icon(Icons.gps_fixed_rounded, size: 18),
                      label: const Text('Obter GPS',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              // Mini-mapa
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
                                  child: Column(children: [
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
                                      child: const Icon(Icons.local_shipping,
                                          color: Colors.white, size: 14),
                                    ),
                                    CustomPaint(
                                      size: const Size(12, 8),
                                      painter:
                                          _TrianglePainter(statusColor(_status)),
                                    ),
                                  ]),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _GpsOverlay(lat: _lat!, lon: _lon!),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              // Botão salvar
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
                      : Icon(_isEdit
                          ? Icons.save_rounded
                          : Icons.check_circle_outline_rounded),
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

  Widget _buildField({
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.primaryLight, width: 2),
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
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.primaryLight),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryLight,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(width: 8),
      const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
    ]);
  }
}

// ── Coord row ─────────────────────────────────────────────────────────────────

class _CoordRow extends StatelessWidget {
  final String label;
  final String value;
  final bool loading;
  const _CoordRow(
      {required this.label, required this.value, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
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
              color: AppColors.primary),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(width: 8),
      loading
          ? const SizedBox(
              width: 60,
              height: 10,
              child: LinearProgressIndicator(minHeight: 2))
          : Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
    ]);
  }
}

// ── GPS overlay ───────────────────────────────────────────────────────────────

class _GpsOverlay extends StatelessWidget {
  final double lat;
  final double lon;
  const _GpsOverlay({required this.lat, required this.lon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  color: Color(0xFF4ADE80), shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            const Text('GPS',
                style: TextStyle(
                    color: Color(0xFF4ADE80),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
          ]),
          const SizedBox(height: 4),
          Text(lat.toStringAsFixed(5),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500)),
          Text(lon.toStringAsFixed(5),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Triangle painter ──────────────────────────────────────────────────────────

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
