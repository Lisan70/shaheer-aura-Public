import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/theme.dart';
import '../models/dashboard_data.dart';
import '../widgets/stat_card.dart';
import '../widgets/revenue_chart.dart';
import '../widgets/ad_performance_card.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> stats = {};
  List<RevenuePoint> weeklyRevenue = [];
  List<AdPerformance> adPerformance = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // ✅ Safe number parsing helpers (handles String, int, double, or null from Firestore)
  int _toInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  Future<void> _loadStats() async {
    try {
      // dashboard/stats holds the main summary numbers
      final doc = await FirebaseFirestore.instance
          .collection('dashboard')
          .doc('stats')
          .get();

      // ✅ FIXED: weeklyRevenue is a TOP-LEVEL collection (not a subcollection of dashboard/stats)
      final revenueSnap = await FirebaseFirestore.instance
          .collection('weeklyRevenue')
          .orderBy('day')
          .get();

      // ✅ FIXED: adPerformance is a TOP-LEVEL collection (not a subcollection of dashboard/stats)
      final adSnap = await FirebaseFirestore.instance
          .collection('adPerformance')
          .get();

      if (mounted) {
        setState(() {
          stats = doc.exists ? doc.data()! : {};

          weeklyRevenue = revenueSnap.docs.map((d) {
            final data = d.data();
            return RevenuePoint(
              data['day']?.toString() ?? '',
              _toDouble(data['revenue']),
            );
          }).toList();

          adPerformance = adSnap.docs.map((d) {
            final data = d.data();
            return AdPerformance(
              type: data['name']?.toString() ?? 'Unknown',
              impressions: _toInt(data['impressions'], 10000),
              clicks: _toInt(data['clicks'], 0),
              revenue: _toDouble(data['revenue'], 0.0),
              icon: data['icon']?.toString() ?? '📊',
            );
          }).toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data load error: $e'),
            backgroundColor: AuraTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await _loadStats();
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;
    final isMedium = width > 600;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AuraTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: AuraTheme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AuraTheme.background,
      appBar: AppBar(
        backgroundColor: AuraTheme.surface,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CustomPaint(painter: _AuraLogoPainter()),
            ),
            const SizedBox(width: 10),
            const Text(
              'SHAHEER AURA',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AuraTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AuraTheme.primaryLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Business Dashboard',
                style: TextStyle(
                  fontSize: 11,
                  color: AuraTheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : _refresh,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AuraTheme.primary),
                  )
                : const Icon(Icons.refresh_rounded,
                    color: AuraTheme.textSecondary),
            tooltip: 'Refresh',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AuraTheme.primaryLight,
                child: const Text(
                  'S',
                  style: TextStyle(
                    color: AuraTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AuraTheme.border),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AuraTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(),
              const SizedBox(height: 20),
              _buildTodayHighlight(),
              const SizedBox(height: 20),
              _buildStatGrid(isWide, isMedium),
              const SizedBox(height: 20),
              RevenueChart(data: weeklyRevenue),
              const SizedBox(height: 20),
              AdPerformanceCard(ads: adPerformance),
              const SizedBox(height: 20),
              _buildClaudeCredit(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ FIXED: emojis replaced with Material Icons (no more □ boxes)
  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    String greeting;
    IconData greetingIcon;
    if (hour < 12) {
      greeting = 'Good Morning';
      greetingIcon = Icons.wb_twilight_rounded;
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
      greetingIcon = Icons.wb_sunny_rounded;
    } else {
      greeting = 'Good Evening';
      greetingIcon = Icons.nights_stay_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(greetingIcon, size: 20, color: AuraTheme.amber),
            const SizedBox(width: 8),
            Text('$greeting, Shaheer!',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AuraTheme.textPrimary)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Text('Your app is performing great!',
                style: TextStyle(fontSize: 13, color: AuraTheme.textSecondary)),
            const SizedBox(width: 6),
            const Icon(Icons.rocket_launch_rounded,
                size: 14, color: AuraTheme.textSecondary),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayHighlight() {
    final todayRevenue = stats['todayRevenue']?.toString() ?? '\$0.00';
    final revenueChange = stats['revenueChange']?.toString() ?? '0%';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AuraTheme.primary, Color(0xFF9C8DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AuraTheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Revenue',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  todayRevenue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$revenueChange more than yesterday',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.trending_up_rounded,
              color: Colors.white54, size: 64),
        ],
      ),
    );
  }

  Widget _buildStatGrid(bool isWide, bool isMedium) {
    final ctr = stats['ctr']?.toString() ?? '0';
    final cards = [
      StatCard(
        title: 'Total Revenue',
        value: stats['totalRevenue']?.toString() ?? '\$0',
        subtitle: 'All time earnings',
        growth: (stats['revenueGrowth'] ?? 0.0).toDouble(),
        iconBg: AuraTheme.successLight,
        iconColor: AuraTheme.success,
        icon: Icons.attach_money_rounded,
      ),
      StatCard(
        title: 'Total Users',
        value: stats['totalUsers']?.toString() ?? '0',
        subtitle: 'Registered in your app',
        growth: (stats['userGrowth'] ?? 0.0).toDouble(),
        iconBg: AuraTheme.primaryLight,
        iconColor: AuraTheme.primary,
        icon: Icons.people_alt_rounded,
      ),
      StatCard(
        title: 'Active Users',
        value: stats['activeUsers']?.toString() ?? '0',
        subtitle: 'Active today',
        growth: (stats['activeGrowth'] ?? 0.0).toDouble(),
        iconBg: AuraTheme.amberLight,
        iconColor: AuraTheme.amber,
        icon: Icons.online_prediction_rounded,
      ),
      StatCard(
        title: 'Ad Clicks',
        value: stats['adClicks']?.toString() ?? '0',
        subtitle: 'CTR: $ctr%',
        growth: (stats['ctrGrowth'] ?? 0.0).toDouble(),
        iconBg: AuraTheme.dangerLight,
        iconColor: AuraTheme.danger,
        icon: Icons.ads_click_rounded,
      ),
    ];

    if (isWide) {
      return GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
        children: cards,
      );
    } else if (isMedium) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: cards,
      );
    } else {
      return Column(
        children: cards
            .map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12), child: c))
            .toList(),
      );
    }
  }

  // ✅ FIXED: emojis replaced with Material Icons (no more □ boxes)
  Widget _buildClaudeCredit() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AuraTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome,
                color: Color(0xFFFF6B35), size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Built with Claude AI',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AuraTheme.textPrimary),
                ),
                Text(
                  'SHAHEER AURA — Powered by AI',
                  style:
                      TextStyle(fontSize: 11, color: AuraTheme.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.handshake_rounded, color: AuraTheme.primary, size: 20),
        ],
      ),
    );
  }
}

class _AuraLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = const Color(0xFF6C63FF)
      ..style = PaintingStyle.fill;
    final lightPaint = Paint()
      ..color = const Color(0xFF6C63FF).withOpacity(0.15)
      ..style = PaintingStyle.fill;
    final midPaint = Paint()
      ..color = const Color(0xFF6C63FF).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = const Color(0xFF6C63FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final outer = Path()
      ..moveTo(cx, cy - 17)
      ..lineTo(cx + 12, cy - 5)
      ..lineTo(cx, cy + 7)
      ..lineTo(cx - 12, cy - 5)
      ..close();
    canvas.drawPath(outer, lightPaint);

    final mid = Path()
      ..moveTo(cx, cy - 12)
      ..lineTo(cx + 8, cy - 3)
      ..lineTo(cx, cy + 5)
      ..lineTo(cx - 8, cy - 3)
      ..close();
    canvas.drawPath(mid, midPaint);

    final core = Path()
      ..moveTo(cx, cy - 8)
      ..lineTo(cx + 6, cy - 2)
      ..lineTo(cx, cy + 4)
      ..lineTo(cx - 6, cy - 2)
      ..close();
    canvas.drawPath(core, paint);

    canvas.drawLine(Offset(cx, cy - 19), Offset(cx, cy - 14), linePaint);
    canvas.drawLine(
        Offset(cx + 14, cy - 5), Offset(cx + 9, cy - 5), linePaint);
    canvas.drawLine(Offset(cx, cy + 9), Offset(cx, cy + 14), linePaint);
    canvas.drawLine(
        Offset(cx - 14, cy - 5), Offset(cx - 9, cy - 5), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
