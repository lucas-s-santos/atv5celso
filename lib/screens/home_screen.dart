import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/colors.dart';
import '../models/delivery.dart';
import '../providers/delivery_provider.dart';
import '../widgets/delivery_card.dart';
import 'form_screen.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _searchActive = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  static const _tabs = <(String?, String)>[
    (null,               'Todos'),
    ('pendente',         'Pendente'),
    ('em transporte',    'Em rota'),
    ('saiu para entrega','Saiu'),
    ('entregue',         'Entregue'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _searchCtrl.addListener(() => setState(() => _searchQuery = _searchCtrl.text));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>().load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Delivery> _filtered(List<Delivery> all, String? status) {
    var list = status == null ? all : all.where((d) => d.status == status).toList();
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list
          .where((d) =>
              d.codigo.toLowerCase().contains(q) ||
              d.nomeDestinatario.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryProvider>();
    final all = provider.deliveries;

    // Notificação de nova entrega via Firebase
    if (provider.newDeliveriesFromSync.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final count = provider.newDeliveriesFromSync.length;
        provider.clearNewDeliveries();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.cloud_download_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                '$count nova${count > 1 ? 's entregas recebidas' : ' entrega recebida'} do Firebase',
              ),
            ]),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black12,
        scrolledUnderElevation: 2,
        title: _searchActive
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar código ou destinatário...',
                  hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                    fontSize: 16, color: AppColors.textPrimary),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Entregas',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: provider.isSyncing
                        ? const Text(
                            'Sincronizando...',
                            key: ValueKey('sync'),
                            style: TextStyle(
                                fontSize: 11, color: AppColors.primaryLight),
                          )
                        : Text(
                            '${all.length} registro${all.length != 1 ? 's' : ''}',
                            key: const ValueKey('count'),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                  ),
                ],
              ),
        actions: [
          if (provider.isSyncing && !_searchActive)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryLight),
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              _searchActive ? Icons.close_rounded : Icons.search_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: () => setState(() {
              _searchActive = !_searchActive;
              if (!_searchActive) {
                _searchCtrl.clear();
                _searchQuery = '';
              }
            }),
          ),
          if (!_searchActive)
            IconButton(
              icon: const Icon(Icons.map_outlined, color: AppColors.textSecondary),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MapScreen())),
            ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500, fontSize: 13),
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            dividerColor: AppColors.divider,
            tabs: _tabs.map((t) {
              final count = t.$1 == null
                  ? all.length
                  : all.where((d) => d.status == t.$1).length;
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.$2),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      body: Column(
        children: [
          // Banner offline
          if (provider.usingLocalData)
            Container(
              color: Colors.orange.shade700,
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Row(children: [
                Icon(Icons.cloud_off_rounded, color: Colors.white, size: 14),
                SizedBox(width: 8),
                Text(
                  'Sem conexão — exibindo dados locais',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),

          // Hero card com totais
          _HeroCard(deliveries: all),

          // Lista por aba
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((t) {
                final filtered = _filtered(all, t.$1);
                if (filtered.isEmpty) return const _EmptyState();
                return ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => DeliveryCard(
                    delivery: filtered[i],
                    provider: provider,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FormScreen()),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova Entrega',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final List<Delivery> deliveries;
  const _HeroCard({required this.deliveries});

  @override
  Widget build(BuildContext context) {
    final pendentes   = deliveries.where((d) => d.status == 'pendente').length;
    final transporte  = deliveries.where((d) => d.status == 'em transporte').length;
    final saiu        = deliveries.where((d) => d.status == 'saiu para entrega').length;
    final entregues   = deliveries.where((d) => d.status == 'entregue').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Total
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total de Entregas',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                '${deliveries.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF86EFAC),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text('Firebase ativo',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
            ],
          ),
          const Spacer(),
          // Mini stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MiniStat(count: pendentes,  label: 'Pendente',   color: const Color(0xFFC4B5FD)),
              const SizedBox(height: 10),
              _MiniStat(count: transporte, label: 'Em rota',    color: const Color(0xFF7DD3FC)),
              const SizedBox(height: 10),
              _MiniStat(count: saiu,       label: 'Saiu',       color: const Color(0xFFFCD34D)),
              const SizedBox(height: 10),
              _MiniStat(count: entregues,  label: 'Entregue',   color: const Color(0xFF6EE7B7)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _MiniStat(
      {required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inbox_rounded,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma entrega aqui',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Toque em + Nova Entrega para começar',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
