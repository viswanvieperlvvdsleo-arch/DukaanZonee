import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class SellerMetricAnalyticsPage extends StatefulWidget {
  const SellerMetricAnalyticsPage({
    super.key,
    required this.title,
    required this.payments,
    this.initialCustomerId,
  });

  final String title;
  final List<Map<String, dynamic>> payments;
  final String? initialCustomerId;

  @override
  State<SellerMetricAnalyticsPage> createState() =>
      _SellerMetricAnalyticsPageState();
}

class _SellerMetricAnalyticsPageState extends State<SellerMetricAnalyticsPage> {
  _MetricWindow _window = _MetricWindow.daily;
  String? _selectedCustomerId;

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.initialCustomerId;
  }

  @override
  Widget build(BuildContext context) {
    final scopedPayments = _timeScopedPayments(widget.payments, _window);
    final customerSummaries = _buildCustomerSummaries(scopedPayments);
    final filteredPayments = _selectedCustomerId == null
        ? scopedPayments
        : scopedPayments
            .where(
              (payment) =>
                  _paymentUserId(payment) != null &&
                  _paymentUserId(payment) == _selectedCustomerId,
            )
            .toList();
    final chartPoints = _buildChartPoints(filteredPayments, _window);
    final totalValue = filteredPayments.fold<int>(
      0,
      (sum, payment) => sum + _metricValue(payment),
    );
    final totalOrders = filteredPayments.length;
    final averageTicket =
        totalOrders == 0 ? 0 : (totalValue / totalOrders).round();
    final selectedCustomer = customerSummaries
        .where((summary) => summary.id == _selectedCustomerId)
        .cast<_CustomerSummary?>()
        .firstWhere((summary) => summary != null, orElse: () => null);

    return AppPage(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PageTitle(
                widget.title,
                'Live backend payments, customer drilldown, and time-based trend view.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _MetricWindow.values.map((window) {
            final active = _window == window;
            return InkWell(
              onTap: () => setState(() => _window = window),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: active ? primary : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: active ? primary : muted.withOpacity(0.18),
                  ),
                  boxShadow: active ? shadowSm : null,
                ),
                child: Text(
                  window.label,
                  style: TextStyle(
                    color: active ? Colors.white : ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 860;
            final summaryCards = [
              _SummaryCard(
                title: widget.title,
                value: _formatRupeesCents(totalValue),
                note: '$totalOrders payment${totalOrders == 1 ? '' : 's'} in ${_window.label.toLowerCase()} view',
              ),
              _SummaryCard(
                title: 'Average Ticket',
                value: _formatRupeesCents(averageTicket),
                note: selectedCustomer == null
                    ? 'Across all active customers'
                    : 'Focused on ${selectedCustomer.name}',
              ),
              _SummaryCard(
                title: 'Selected Customer',
                value: selectedCustomer?.name ?? 'All',
                note: selectedCustomer == null
                    ? 'Tap a customer below to isolate history'
                    : '${selectedCustomer.count} payment${selectedCustomer.count == 1 ? '' : 's'} in this window',
              ),
            ];
            if (isWide) {
              return Row(
                children: List.generate(summaryCards.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == summaryCards.length - 1 ? 0 : 14,
                      ),
                      child: summaryCards[index],
                    ),
                  );
                }),
              );
            }
            return Column(
              children: List.generate(summaryCards.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == summaryCards.length - 1 ? 0 : 14,
                  ),
                  child: summaryCards[index],
                );
              }),
            );
          },
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: shadowSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Kicker('TREND'),
              const SizedBox(height: 12),
              Text(
                _chartHeadline(chartPoints),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 220,
                child: chartPoints.isEmpty
                    ? const Center(
                        child: Text(
                          'No completed payments in this time window yet.',
                          style: TextStyle(
                            color: muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : _MetricBarChart(
                        points: chartPoints,
                        formatter: _formatShortRupees,
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Kicker('CUSTOMERS'),
        const SizedBox(height: 12),
        if (customerSummaries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: shadowSm,
            ),
            child: const Text(
              'No customer payments in this window yet.',
              style: TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CustomerChip(
                label: 'All Customers',
                total: _formatRupeesCents(
                  customerSummaries.fold<int>(
                    0,
                    (sum, summary) => sum + summary.total,
                  ),
                ),
                selected: _selectedCustomerId == null,
                onTap: () => setState(() => _selectedCustomerId = null),
              ),
              ...customerSummaries.map((summary) {
                return _CustomerChip(
                  label: summary.name,
                  total: _formatRupeesCents(summary.total),
                  selected: _selectedCustomerId == summary.id,
                  onTap: () => setState(() => _selectedCustomerId = summary.id),
                );
              }),
            ],
          ),
        const SizedBox(height: 24),
        const Kicker('PAYMENT HISTORY'),
        const SizedBox(height: 12),
        if (filteredPayments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: shadowSm,
            ),
            child: const Text(
              'No history for the current customer/time filter.',
              style: TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
          )
        else
          Column(
            children: filteredPayments.map((payment) {
              final user = Map<String, dynamic>.from(
                payment['user'] as Map? ?? const {},
              );
              final items = (payment['items'] as List? ?? const [])
                  .whereType<Map>()
                  .map((item) {
                    final name = item['name']?.toString() ?? 'Item';
                    final qty = item['quantity'] as int? ?? 1;
                    return '$name x$qty';
                  })
                  .join(', ');
              final createdAt = _paymentTime(payment);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: shadowSm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(user['name']?.toString() ?? 'C'),
                        style: const TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name']?.toString() ?? 'Customer',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            items.isEmpty ? 'Direct payment' : items,
                            style: const TextStyle(
                              color: muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _formatHistoryTime(createdAt),
                            style: const TextStyle(
                              color: muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatRupeesCents(_metricValue(payment)),
                          style: const TextStyle(
                            color: success,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            (payment['status']?.toString() ?? 'completed')
                                .toUpperCase(),
                            style: const TextStyle(
                              color: success,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  List<Map<String, dynamic>> _timeScopedPayments(
    List<Map<String, dynamic>> payments,
    _MetricWindow window,
  ) {
    final now = DateTime.now();
    DateTime cutoff;
    switch (window) {
      case _MetricWindow.daily:
        cutoff = DateTime(now.year, now.month, now.day);
        break;
      case _MetricWindow.weekly:
        cutoff = DateTime(now.year, now.month, now.day).subtract(
          const Duration(days: 6),
        );
        break;
      case _MetricWindow.monthly:
        cutoff = DateTime(now.year, now.month, now.day).subtract(
          const Duration(days: 29),
        );
        break;
      case _MetricWindow.yearly:
        cutoff = DateTime(now.year - 1, now.month, now.day);
        break;
    }
    final filtered = payments.where((payment) {
      final timestamp = _paymentTime(payment);
      return timestamp != null && !timestamp.isBefore(cutoff);
    }).toList();
    filtered.sort((a, b) {
      final left = _paymentTime(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = _paymentTime(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return filtered;
  }

  List<_CustomerSummary> _buildCustomerSummaries(
    List<Map<String, dynamic>> payments,
  ) {
    final bucket = <String, _CustomerSummary>{};
    for (final payment in payments) {
      final user = Map<String, dynamic>.from(
        payment['user'] as Map? ?? const {},
      );
      final id = user['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final current = bucket[id];
      final total = _metricValue(payment);
      bucket[id] = _CustomerSummary(
        id: id,
        name: user['name']?.toString() ?? 'Customer',
        total: (current?.total ?? 0) + total,
        count: (current?.count ?? 0) + 1,
      );
    }
    final values = bucket.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return values;
  }

  List<_ChartPoint> _buildChartPoints(
    List<Map<String, dynamic>> payments,
    _MetricWindow window,
  ) {
    final now = DateTime.now();
    final bucket = <String, int>{};
    final labels = <String>[];
    switch (window) {
      case _MetricWindow.daily:
        for (var hour = 0; hour < 24; hour += 4) {
          final label = '${hour.toString().padLeft(2, '0')}:00';
          labels.add(label);
          bucket[label] = 0;
        }
        for (final payment in payments) {
          final time = _paymentTime(payment);
          if (time == null) continue;
          final slot = (time.hour ~/ 4) * 4;
          final label = '${slot.toString().padLeft(2, '0')}:00';
          bucket[label] = (bucket[label] ?? 0) + _metricValue(payment);
        }
        break;
      case _MetricWindow.weekly:
        for (var index = 6; index >= 0; index--) {
          final day = now.subtract(Duration(days: index));
          final label = _weekdayLabel(day.weekday);
          labels.add(label);
          bucket[label] = 0;
        }
        for (final payment in payments) {
          final time = _paymentTime(payment);
          if (time == null) continue;
          final label = _weekdayLabel(time.weekday);
          bucket[label] = (bucket[label] ?? 0) + _metricValue(payment);
        }
        break;
      case _MetricWindow.monthly:
        for (var index = 4; index >= 0; index--) {
          final label = 'W${5 - index}';
          labels.add(label);
          bucket[label] = 0;
        }
        for (final payment in payments) {
          final time = _paymentTime(payment);
          if (time == null) continue;
          final span = now.difference(time).inDays;
          final weekIndex = (span ~/ 7).clamp(0, 4);
          final paymentLabel = 'W${5 - weekIndex}';
          bucket[paymentLabel] =
              (bucket[paymentLabel] ?? 0) + _metricValue(payment);
        }
        break;
      case _MetricWindow.yearly:
        for (var index = 11; index >= 0; index--) {
          final month = DateTime(now.year, now.month - index, 1);
          final label = _monthLabel(month.month);
          labels.add(label);
          bucket[label] = 0;
        }
        for (final payment in payments) {
          final time = _paymentTime(payment);
          if (time == null) continue;
          final label = _monthLabel(time.month);
          bucket[label] = (bucket[label] ?? 0) + _metricValue(payment);
        }
        break;
    }
    return labels
        .map((label) => _ChartPoint(label: label, value: bucket[label] ?? 0))
        .toList();
  }

  int _metricValue(Map<String, dynamic> payment) {
    switch (widget.title) {
      case 'Net To Seller':
        return payment['sellerNetCents'] as int? ?? 0;
      case 'DukaanZone fee':
        return payment['commissionCents'] as int? ?? 0;
      case 'Today Sales':
      default:
        return payment['grossCents'] as int? ?? 0;
    }
  }

  DateTime? _paymentTime(Map<String, dynamic> payment) {
    final raw = payment['createdAt']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  String? _paymentUserId(Map<String, dynamic> payment) {
    final user = Map<String, dynamic>.from(payment['user'] as Map? ?? const {});
    return user['id']?.toString();
  }

  String _chartHeadline(List<_ChartPoint> points) {
    if (points.isEmpty) return 'No trend activity yet';
    final strongest = points.reduce(
      (left, right) => left.value >= right.value ? left : right,
    );
    return '${strongest.label} is leading with ${_formatRupeesCents(strongest.value)}';
  }

  String _formatHistoryTime(DateTime? value) {
    if (value == null) return 'Unknown time';
    final day = value.day.toString().padLeft(2, '0');
    final month = _monthLabel(value.month);
    final year = value.year;
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final meridiem = value.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year • $hour:$minute $meridiem';
  }

  String _formatRupeesCents(int cents) {
    return 'Rs ${(cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2)}';
  }

  String _formatShortRupees(int cents) {
    final rupees = cents / 100;
    if (rupees >= 100000) {
      return 'Rs ${(rupees / 100000).toStringAsFixed(1)}L';
    }
    if (rupees >= 1000) {
      return 'Rs ${(rupees / 1000).toStringAsFixed(1)}k';
    }
    return _formatRupeesCents(cents);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _weekdayLabel(int weekday) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[(weekday - 1).clamp(0, 6)];
  }

  String _monthLabel(int month) {
    const labels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return labels[(month - 1).clamp(0, 11)];
  }
}

enum _MetricWindow {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  yearly('Yearly');

  const _MetricWindow(this.label);
  final String label;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.note,
  });

  final String title;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: const TextStyle(
              color: muted,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerChip extends StatelessWidget {
  const _CustomerChip({
    required this.label,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? primary : muted.withOpacity(0.18),
          ),
          boxShadow: selected ? shadowSm : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              total,
              style: TextStyle(
                color: selected ? Colors.white70 : muted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBarChart extends StatelessWidget {
  const _MetricBarChart({
    required this.points,
    required this.formatter,
  });

  final List<_ChartPoint> points;
  final String Function(int value) formatter;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<int>(
      0,
      (current, point) => point.value > current ? point.value : current,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: points.map((point) {
        final ratio = maxValue == 0 ? 0.0 : point.value / maxValue;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  formatter(point.value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: ratio),
                  duration: const Duration(milliseconds: 400),
                  builder: (context, value, _) {
                    return Container(
                      height: 130 * value + 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            primary.withOpacity(0.9),
                            success.withOpacity(0.92),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  point.label,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CustomerSummary {
  const _CustomerSummary({
    required this.id,
    required this.name,
    required this.total,
    required this.count,
  });

  final String id;
  final String name;
  final int total;
  final int count;
}

class _ChartPoint {
  const _ChartPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;
}
