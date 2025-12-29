import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:new_amst_flutter/Data/order_storage.dart';

class SalesChartSection extends StatelessWidget {
  const SalesChartSection({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderRecord>>(
      stream: OrdersStorage().watchOrders(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data ?? const <OrderRecord>[];
        if (data.isEmpty) {
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            color: const Color(0xFF0B1220),
            elevation: 6,
            child: const SizedBox(
              height: 240,
              child: Center(
                child: Text(
                  'No sales yet.\nAdd some orders to see the insight chart.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }

        final Map<DateTime, int> qtyByDay = {};
        for (final o in data) {
          final d = DateTime(
            o.createdAt.year,
            o.createdAt.month,
            o.createdAt.day,
          );
          qtyByDay[d] = (qtyByDay[d] ?? 0) + o.totalQty;
        }

        final sortedDays = qtyByDay.keys.toList()..sort();
        final points = <FlSpot>[];

        for (var i = 0; i < sortedDays.length; i++) {
          final day = sortedDays[i];
          final qty = qtyByDay[day] ?? 0;
          points.add(FlSpot(i.toDouble(), qty.toDouble()));
        }

        // ---------- Stats for header chips ----------
        final today = DateTime.now();
        final todayKey = DateTime(today.year, today.month, today.day);
        final int todayQty = qtyByDay[todayKey] ?? 0;

        final last7Start = todayKey.subtract(const Duration(days: 6));
        final prev7Start = last7Start.subtract(const Duration(days: 7));
        final prev7End = last7Start.subtract(const Duration(days: 1));

        int last7Total = 0;
        int prev7Total = 0;

        qtyByDay.forEach((day, qty) {
          if (!day.isBefore(last7Start) && !day.isAfter(todayKey)) {
            last7Total += qty;
          } else if (!day.isBefore(prev7Start) && !day.isAfter(prev7End)) {
            prev7Total += qty;
          }
        });

        double changePct = 0;
        if (prev7Total > 0) {
          changePct = ((last7Total - prev7Total) / prev7Total) * 100;
        }

        final bool isUp = changePct >= 0;
        final Color trendColor = isUp
            ? const Color(0xFF22C55E)
            : const Color(0xFFEF4444);

        final maxY = points
            .map((e) => e.y)
            .fold<double>(0, (a, b) => b > a ? b : a);
        final double yInterval = maxY <= 5
            ? 1
            : (maxY <= 10 ? 2 : (maxY <= 20 ? 5 : (maxY / 4).ceilToDouble()));

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          color: const Color(0xFF020617),
          elevation: 10,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF020617),
                  Color(0xFF020617),
                  Color(0xFF111827),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 290,
              width: MediaQuery.of(context).size.width * 0.90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 32,
                        width: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0EA5E9), Color(0xFFA855F7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.show_chart_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Sales Insight',
                              style: TextStyle(
                                fontFamily: 'ClashGrotesk',
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Total quantity sold by day',
                              style: TextStyle(
                                fontFamily: 'ClashGrotesk',
                                fontSize: 11,
                                color: Colors.white54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: const Color(0xFF020617),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF60A5FA), // blue dot
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${sortedDays.length} days',
                              style: TextStyle(
                                fontFamily: 'ClashGrotesk',
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      _StatChip(
                        label: 'Today',
                        value: '$todayQty',
                        color: const Color(0xFF22C55E), // green
                      ),
                      const SizedBox(width: 4),
                      _StatChip(
                        label: 'Last 7 days',
                        value: '$last7Total',
                        color: const Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 4),
                      if (prev7Total > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: trendColor.withOpacity(0.08),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isUp
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                size: 16,
                                color: trendColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${isUp ? '+' : ''}${changePct.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontFamily: 'ClashGrotesk',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: trendColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'vs 7d',
                                style: TextStyle(
                                  fontFamily: 'ClashGrotesk',
                                  fontSize: 10,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ---- Chart ----
                  Expanded(
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: (points.length - 1).toDouble(),
                        minY: 0,
                        maxY: maxY == 0 ? 5 : maxY * 1.3,
                        lineTouchData: LineTouchData(
                          enabled: true,
                          handleBuiltInTouches: true,
                          touchTooltipData: LineTouchTooltipData(
                            tooltipRoundedRadius: 8,
                            tooltipPadding: const EdgeInsets.all(8),
                            // tooltipBgColor: const Color(0xFF020617),
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final idx = spot.x.toInt();
                                final d = sortedDays[idx];
                                final label = '${d.day}/${d.month}';
                                return LineTooltipItem(
                                  '$label\n',
                                  const TextStyle(
                                    fontFamily: 'ClashGrotesk',
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '${spot.y.toInt()} qty',
                                      style: const TextStyle(
                                        fontFamily: 'ClashGrotesk',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList();
                            },
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawHorizontalLine: true,
                          drawVerticalLine: false,
                          horizontalInterval: yInterval,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.white.withOpacity(0.06),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 26,
                              interval: yInterval,
                              getTitlesWidget: (value, meta) {
                                if (value < 0) return const SizedBox.shrink();
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'ClashGrotesk',
                                    color: Colors.white60,
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= sortedDays.length) {
                                  return const SizedBox.shrink();
                                }
                                final d = sortedDays[i];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${d.day}/${d.month}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'ClashGrotesk',
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            spots: points,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              checkToShowDot: (spot, _) => true,
                            ),
                            color: const Color(0xFF60A5FA),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF60A5FA).withOpacity(0.45),
                                  const Color(0xFF60A5FA).withOpacity(0.01),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // ---- Small legend / hint ----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Row(
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 14,
                            color: Colors.white70,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Tap a point to see exact qty',
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              fontSize: 10,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: Color(0xFF60A5FA)),
                          SizedBox(width: 4),
                          Text(
                            'Qty sold',
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              fontSize: 10,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 11,
              color: Colors.white54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
