import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/utils.dart';
import '../models/delivery.dart';
import '../models/status_entry.dart';
import '../providers/delivery_provider.dart';
import '../services/database_helper.dart';
import '../screens/form_screen.dart';
import '../screens/map_screen.dart';

class DeliveryCard extends StatefulWidget {
  final Delivery delivery;
  final DeliveryProvider provider;
  const DeliveryCard({super.key, required this.delivery, required this.provider});

  @override
  State<DeliveryCard> createState() => _DeliveryCardState();
}

class _DeliveryCardState extends State<DeliveryCard> {
  bool _historyExpanded = false;
  List<StatusEntry> _history = [];
  bool _loadingHistory = false;

  Future<void> _toggleHistory() async {
    if (_historyExpanded) {
      setState(() => _historyExpanded = false);
      return;
    }
    setState(() => _loadingHistory = true);
    final h = await DatabaseHelper.instance.fetchHistory(widget.delivery.id!);
    if (!mounted) return;
    setState(() {
      _history = h;
      _historyExpanded = true;
      _loadingHistory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.delivery;
    final color = statusColor(d.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // ── Card principal ─────────────────────────────────────────────
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Faixa colorida esquerda
                  Container(width: 6, color: color),
                  // Conteúdo
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Linha 1: código + badge de status + menu
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  d.codigo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              _StatusBadge(status: d.status, color: color),
                              _CardMenu(delivery: d, provider: widget.provider),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Nome
                          Text(
                            d.nomeDestinatario,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 3),
                          // Endereço
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 13, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  d.endereco,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Rodapé: GPS + data
                          Row(
                            children: [
                              const Icon(Icons.gps_fixed,
                                  size: 10, color: Color(0xFFCBD5E1)),
                              const SizedBox(width: 3),
                              Text(
                                '${d.latitude.toStringAsFixed(4)}, ${d.longitude.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFCBD5E1),
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.access_time_rounded,
                                  size: 10, color: Color(0xFFCBD5E1)),
                              const SizedBox(width: 3),
                              Text(
                                d.dataHoraAtualizacao,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFCBD5E1),
                                ),
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

            // ── Botão histórico ────────────────────────────────────────────
            InkWell(
              onTap: _toggleHistory,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(
                      top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _historyExpanded
                          ? Icons.unfold_less_rounded
                          : Icons.history_rounded,
                      size: 14,
                      color: AppColors.primaryLight,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _loadingHistory
                          ? 'Carregando...'
                          : _historyExpanded
                              ? 'Ocultar histórico'
                              : 'Histórico de status',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _historyExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.primaryLight,
                    ),
                  ],
                ),
              ),
            ),

            // ── Histórico expandido ────────────────────────────────────────
            if (_historyExpanded)
              Container(
                width: double.infinity,
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
                child: _history.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Nenhum histórico registrado.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      )
                    : Column(
                        children: _history.map((h) {
                          final c = statusColor(h.status);
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration:
                                      BoxDecoration(color: c, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    h.status,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  h.dataHora,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card menu ─────────────────────────────────────────────────────────────────

class _CardMenu extends StatelessWidget {
  final Delivery delivery;
  final DeliveryProvider provider;
  const _CardMenu({required this.delivery, required this.provider});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          color: Color(0xFFCBD5E1), size: 20),
      onSelected: (value) async {
        if (value == 'editar') {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => FormScreen(delivery: delivery)),
          );
        } else if (value == 'mapa') {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => MapScreen(focused: delivery)),
          );
        } else if (value == 'excluir') {
          _confirmDelete(context);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'editar',
          child: Row(children: [
            Icon(Icons.edit_rounded, size: 18),
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
            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red[400]),
            const SizedBox(width: 10),
            Text('Excluir', style: TextStyle(color: Colors.red[400])),
          ]),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Excluir entrega?'),
        content:
            Text('A entrega "${delivery.codigo}" será removida permanentemente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
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
