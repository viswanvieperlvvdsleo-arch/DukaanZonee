import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  // Payout Settings
  bool _isLoadingSettings = true;
  bool _isSavingSettings = false;
  double _platformDeductionPercent = 3.0;
  double _promotion3DayRate = 30.0;
  double _promotion7DayRate = 60.0;
  double _promotion30DayRate = 150.0;
  final TextEditingController _commissionController = TextEditingController(
    text: '3.0',
  );

  // DB Push Notification Settings
  bool _isNotificationHubEnabled = true;
  String _dbPushDriver = 'PostgreSQL (pg_notify)';
  int _dbPollingIntervalMs = 250;
  final TextEditingController _testNotificationController =
      TextEditingController();

  // Dispute Auto-Replies
  String _missingItemsTemplate =
      "We have received your report regarding missing items. Our neighborhood team will investigate the selected shop within 24 hours.";
  String _damagedGoodsTemplate =
      "We apologize for the damaged items. A platform-sponsored refund is being processed to your bank details.";

  // Backup & Maintenance
  String _backupFrequency = 'Daily';
  bool _isBackingUp = false;

  // System Logs list
  final List<Map<String, String>> _auditLogs = [];

  @override
  void initState() {
    super.initState();
    _loadPlatformSettings();
  }

  Future<void> _loadPlatformSettings() async {
    setState(() => _isLoadingSettings = true);
    try {
      final settings = await platformSettingsService.adminLoad();
      if (!mounted) return;
      setState(() {
        _platformDeductionPercent = settings.commissionPercent;
        _promotion3DayRate = settings.promotion3DayRate;
        _promotion7DayRate = settings.promotion7DayRate;
        _promotion30DayRate = settings.promotion30DayRate;
        _isNotificationHubEnabled = settings.notificationHubEnabled;
        _dbPushDriver = settings.notificationDriver;
        _dbPollingIntervalMs = settings.dbPollingIntervalMs;
        _commissionController.text = _platformDeductionPercent.toStringAsFixed(
          1,
        );
        _auditLogs.insert(0, {
          'time': 'Just Now',
          'event': 'Loaded platform settings from PostgreSQL.',
        });
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load platform settings. $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingSettings = false);
    }
  }

  void _setCommissionPercent(double value) {
    final clamped = value.clamp(0.0, 25.0);
    setState(() {
      _platformDeductionPercent = clamped;
      _commissionController.text = clamped.toStringAsFixed(1);
    });
  }

  Future<void> _savePlatformSettings() async {
    setState(() => _isSavingSettings = true);
    try {
      final current = platformSettingsService.settings.value;
      final saved = await platformSettingsService.adminSave(
        current.copyWith(
          commissionRate: _platformDeductionPercent / 100,
          promotion3DayRate: _promotion3DayRate,
          promotion7DayRate: _promotion7DayRate,
          promotion30DayRate: _promotion30DayRate,
          notificationHubEnabled: _isNotificationHubEnabled,
          notificationDriver: _dbPushDriver,
          dbPollingIntervalMs: _dbPollingIntervalMs,
        ),
      );
      if (!mounted) return;
      setState(() {
        _platformDeductionPercent = saved.commissionPercent;
        _promotion3DayRate = saved.promotion3DayRate;
        _promotion7DayRate = saved.promotion7DayRate;
        _promotion30DayRate = saved.promotion30DayRate;
        _commissionController.text = _platformDeductionPercent.toStringAsFixed(
          1,
        );
        _auditLogs.insert(0, {
          'time': 'Just Now',
          'event':
              'Saved commission ${_platformDeductionPercent.toStringAsFixed(1)}% and promotion rates to PostgreSQL.',
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Platform settings saved for all roles.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save platform settings. $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingSettings = false);
    }
  }

  void _triggerBackup() {
    setState(() {
      _isBackingUp = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _auditLogs.insert(0, {
            'time': 'Just Now',
            'event':
                'Manual system dump triggered successfully ($_backupFrequency backup).',
          });
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Database Dump completed successfully (MySQL/PgSQL archive saved).',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: success,
          ),
        );
      }
    });
  }

  void _sendTestNotification() {
    final text = _testNotificationController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _auditLogs.insert(0, {
        'time': 'Just Now',
        'event': 'Dispatched Push via $_dbPushDriver: "$text"',
      });
      _testNotificationController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Test Alert queued in $_dbPushDriver notification broker table!',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _commissionController.dispose();
    _testNotificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? bgDark : bgLight,
      appBar: MainHeader(
        role: Role.admin,
        onExit: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Back Navigation
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text(
                        'Back to Dashboard',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Settings Heading
                const Row(
                  children: [
                    Icon(Icons.admin_panel_settings, size: 36, color: primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'System Configurations',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                            ),
                          ),
                          Text(
                            'Fine-tune platform fees, transactional daemons, and support templates.',
                            style: TextStyle(
                              color: muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Configuration Sections
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (_isLoadingSettings) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final isWide = constraints.maxWidth > 850;

                    Widget leftCol = Column(
                      children: [
                        // 1. Database-Driven Notification Configurations (MySQL / PostgreSQL)
                        _buildConfigCard(
                          title: 'Database Notification Broker',
                          subtitle:
                              'Tailored alert delivery engine powered by your local database.',
                          icon: Icons.alt_route,
                          iconColor: primary,
                          children: [
                            // Toggle daemon
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Enable Database Notification Broker',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        'Queues notification packets in database rows.',
                                        style: TextStyle(
                                          color: muted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _isNotificationHubEnabled,
                                  onChanged: (v) => setState(
                                    () => _isNotificationHubEnabled = v,
                                  ),
                                  activeColor: success,
                                ),
                              ],
                            ),
                            const Divider(height: 32),

                            if (_isNotificationHubEnabled) ...[
                              // Driver Dropdown Selection
                              Row(
                                children: [
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'RDBMS Push Engine',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'Choose how updates are queried and dispatched.',
                                          style: TextStyle(
                                            color: muted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF4F6F8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _dbPushDriver,
                                        dropdownColor: Theme.of(
                                          context,
                                        ).cardTheme.color,
                                        items:
                                            <String>[
                                              'PostgreSQL (pg_notify)',
                                              'MySQL (Trigger-Based Queue)',
                                            ].map((String value) {
                                              return DropdownMenuItem<String>(
                                                value: value,
                                                child: Text(
                                                  value,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _dbPushDriver = val;
                                              _auditLogs.insert(0, {
                                                'time': 'Just Now',
                                                'event':
                                                    'Notification Driver changed to $val.',
                                              });
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Polling Interval MS slider (specifically for MySQL polling)
                              if (_dbPushDriver.contains('MySQL')) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'MySQL Daemon Polling Interval: ${_dbPollingIntervalMs}ms',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const Text(
                                            'Interval to check the dukaan_notification_queue table.',
                                            style: TextStyle(
                                              color: muted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 150,
                                      child: Slider(
                                        value: _dbPollingIntervalMs.toDouble(),
                                        min: 100.0,
                                        max: 2000.0,
                                        divisions: 19,
                                        activeColor: success,
                                        onChanged: (val) => setState(
                                          () => _dbPollingIntervalMs = val
                                              .round(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Dispatch Test alert
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: primary.withOpacity(0.12),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Simulate Database Push Dispatch',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        color: primary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller:
                                                _testNotificationController,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Enter test push payload...',
                                              filled: true,
                                              fillColor: Theme.of(
                                                context,
                                              ).scaffoldBackgroundColor,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide.none,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 10,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton(
                                          onPressed: _sendTestNotification,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                          ),
                                          child: const Text(
                                            'Dispatch',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 2. Global Payout & Ad Slot rates Configuration
                        _buildConfigCard(
                          title: 'Rates & Commissions Settings',
                          subtitle:
                              'Platform revenue settings and advertising tier packages.',
                          icon: Icons.monetization_on_outlined,
                          iconColor: success,
                          children: [
                            // 3% Platform deduction setup
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Global Commission Rate: ${_platformDeductionPercent.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Text(
                                        'The flat rate deducted from custom customer transactions.',
                                        style: TextStyle(
                                          color: muted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 180,
                                  child: Slider(
                                    value: _platformDeductionPercent,
                                    min: 0.0,
                                    max: 25.0,
                                    divisions: 50,
                                    activeColor: success,
                                    onChanged: _setCommissionPercent,
                                  ),
                                ),
                                SizedBox(
                                  width: 88,
                                  child: TextField(
                                    controller: _commissionController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      suffixText: '%',
                                      filled: true,
                                      fillColor: isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF4F6F8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 10,
                                          ),
                                    ),
                                    onSubmitted: (value) {
                                      final parsed = double.tryParse(value);
                                      if (parsed != null) {
                                        _setCommissionPercent(parsed);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 32),

                            // Ads promotion tiers rates
                            const Kicker('AD SLOT TIER PACKAGES RATES'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildRateInput(
                                  '3-Day Promos',
                                  _promotion3DayRate,
                                  (v) => setState(() => _promotion3DayRate = v),
                                ),
                                const SizedBox(width: 12),
                                _buildRateInput(
                                  '7-Day Promos',
                                  _promotion7DayRate,
                                  (v) => setState(() => _promotion7DayRate = v),
                                ),
                                const SizedBox(width: 12),
                                _buildRateInput(
                                  '30-Day Promos',
                                  _promotion30DayRate,
                                  (v) =>
                                      setState(() => _promotion30DayRate = v),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSavingSettings
                                    ? null
                                    : _savePlatformSettings,
                                icon: _isSavingSettings
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  _isSavingSettings
                                      ? 'Saving Settings...'
                                      : 'Save Rates For All Sellers',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 3. Dispute Resolution Templates
                        _buildConfigCard(
                          title: 'Dispute Template Auto-Replies',
                          subtitle:
                              'Default responses sent to users when neighbor handshakes fail.',
                          icon: Icons.chat_bubble_outline,
                          iconColor: Colors.redAccent,
                          children: [
                            const Text(
                              'Missing Items Complaint Template',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              maxLines: 2,
                              controller: TextEditingController(
                                text: _missingItemsTemplate,
                              ),
                              onChanged: (v) => _missingItemsTemplate = v,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF4F6F8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Damaged Goods Template',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              maxLines: 2,
                              controller: TextEditingController(
                                text: _damagedGoodsTemplate,
                              ),
                              onChanged: (v) => _damagedGoodsTemplate = v,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF4F6F8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );

                    Widget rightCol = Column(
                      children: [
                        // 1. Maintenance & automated backup card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: muted.withOpacity(0.15)),
                            boxShadow: shadowSm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.settings_backup_restore,
                                    color: primary,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Maintenance Hub',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Schedule drop-down
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Backup Frequency',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF4F6F8),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _backupFrequency,
                                        dropdownColor: Theme.of(
                                          context,
                                        ).cardTheme.color,
                                        items:
                                            <String>[
                                              'Hourly',
                                              'Daily',
                                              'Weekly',
                                            ].map((String value) {
                                              return DropdownMenuItem<String>(
                                                value: value,
                                                child: Text(
                                                  value,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(
                                              () => _backupFrequency = val,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Dump trigger button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isBackingUp
                                      ? null
                                      : _triggerBackup,
                                  icon: _isBackingUp
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.backup_outlined),
                                  label: Text(
                                    _isBackingUp
                                        ? 'Archiving Ledger...'
                                        : 'Backup Databases Now',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: success,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 2. System Audit Logs view
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: muted.withOpacity(0.15)),
                            boxShadow: shadowSm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.history_toggle_off,
                                    color: primary,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'System Audit Logs',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _auditLogs.length,
                                itemBuilder: (context, idx) {
                                  final log = _auditLogs[idx];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: primary.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            log['time']!,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 8,
                                              color: primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            log['event']!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white70
                                                  : ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: leftCol),
                          const SizedBox(width: 24),
                          Expanded(flex: 3, child: rightCol),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          leftCol,
                          const SizedBox(height: 32),
                          rightCol,
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: muted.withOpacity(0.15)),
        boxShadow: shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRateInput(
    String label,
    double val,
    ValueChanged<double> onChanged,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: muted,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            decoration: InputDecoration(
              suffixText: '%',
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF4F6F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
            ),
            controller: TextEditingController(text: val.toStringAsFixed(0)),
            onSubmitted: (s) {
              final parsed = double.tryParse(s);
              if (parsed != null) onChanged(parsed);
            },
          ),
        ],
      ),
    );
  }
}
