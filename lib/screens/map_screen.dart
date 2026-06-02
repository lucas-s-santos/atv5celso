import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../core/colors.dart';
import '../core/utils.dart';
import '../models/delivery.dart';
import '../providers/delivery_provider.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  final Delivery? focused;
  const MapScreen({super.key, this.focused});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Delivery? _selected;
  final MapController _mapController = MapController();
  LatLng _mapCenter = const LatLng(-23.5505, -46.6333);

  @override
  void initState() {
    super.initState();
    _selected = widget.focused;
    if (widget.focused != null) {
      _mapCenter = LatLng(widget.focused!.latitude, widget.focused!.longitude);
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
        elevation: 0,
        title: const Text('Mapa de Entregas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
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
                if (hasGesture) setState(() => _mapCenter = pos.center);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                        _mapController.move(LatLng(d.latitude, d.longitude), 15);
                      },
                      child: Column(children: [
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
                          child: Icon(statusIcon(d.status),
                              color: Colors.white,
                              size: isSelected ? 26 : 22),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? color : Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
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
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ── Indicador GPS ────────────────────────────────────────────────
          Positioned(
            top: 12,
            right: 12,
            child: _MapGpsOverlay(center: _mapCenter),
          ),

          // ── Card de entrega selecionada ──────────────────────────────────
          if (_selected != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: statusColor(_selected!.status)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(statusIcon(_selected!.status),
                            color: statusColor(_selected!.status), size: 26),
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
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _selected!.endereco,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor(_selected!.status)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: statusColor(_selected!.status)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                _selected!.status,
                                style: TextStyle(
                                  color: statusColor(_selected!.status),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),

          // ── Botão minha localização ──────────────────────────────────────
          Positioned(
            bottom: _selected != null ? 150 : 20,
            right: 16,
            child: FloatingActionButton.small(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              heroTag: 'myLoc',
              elevation: 4,
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── GPS overlay no mapa ───────────────────────────────────────────────────────

class _MapGpsOverlay extends StatelessWidget {
  final LatLng center;
  const _MapGpsOverlay({required this.center});

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
          Text(center.latitude.toStringAsFixed(5),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500)),
          Text(center.longitude.toStringAsFixed(5),
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
