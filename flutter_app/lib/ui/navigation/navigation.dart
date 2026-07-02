import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class RoleShell extends StatefulWidget {
  const RoleShell({super.key, required this.role});
  final Role role;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int selected = 0;
  final List<int> _tabHistory =
      []; // tracks visited tabs for proper back navigation
  late List<GlobalKey<NavigatorState>> _navKeys;
  late List<bool> _tabHasSubPages;
  late List<_FabObserver> _fabObservers;
  DateTime? _lastPressedAt;

  @override
  void initState() {
    super.initState();
    globalMapState.addListener(_onMapStateChanged);
    globalActiveTabOverride.addListener(_onActiveTabOverrideChanged);
    final count = destinations(widget.role).length;
    _navKeys = List.generate(count, (_) => GlobalKey<NavigatorState>());
    _tabHasSubPages = List.filled(count, false);
    _fabObservers = List.generate(
      count,
      (index) => _FabObserver(
        onDepthChanged: (hasSub) {
          if (mounted) {
            setState(() {
              _tabHasSubPages[index] = hasSub;
            });
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    globalMapState.removeListener(_onMapStateChanged);
    globalActiveTabOverride.removeListener(_onActiveTabOverrideChanged);
    super.dispose();
  }

  void _onActiveTabOverrideChanged() {
    final idx = globalActiveTabOverride.value;
    if (idx != null) {
      if (idx >= 0 && idx < _navKeys.length) {
        _selectTab(idx);
      }
      globalActiveTabOverride.value = null; // Reset override
    }
  }

  void _onMapStateChanged() {
    if (globalMapState.value.mode == MapMode.routing &&
        widget.role == Role.user) {
      if (selected != 1) _selectTab(1);
    }
  }

  // Switch to a tab and record history so back can return to previous tab.
  void _selectTab(int index) {
    setState(() {
      if (selected == index) {
        // Tapping the same tab scrolls it back to root
        _navKeys[index].currentState?.popUntil((r) => r.isFirst);
      } else {
        _tabHistory.add(selected); // remember where we came from
        selected = index;
      }
    });
  }

  void _handleBackNavigation() {
    // 1. If current tab has pages on its own sub-stack, pop them first
    final currentNav = _navKeys[selected].currentState;
    if (currentNav != null && currentNav.canPop()) {
      currentNav.pop();
      return;
    }

    // 2. If we are not on the Home/Dashboard tab (index 0), switch back to index 0
    if (selected != 0) {
      setState(() {
        selected = 0;
        _tabHistory.clear();
      });
      return;
    }

    // 3. We are on the Home/Dashboard root tab (selected == 0) — show exit warning
    final now = DateTime.now();
    if (_lastPressedAt == null ||
        now.difference(_lastPressedAt!) > const Duration(seconds: 4)) {
      _lastPressedAt = now;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Swipe or press back again to exit app'),
            duration: Duration(seconds: 4),
          ),
        );
      return;
    }

    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final items = destinations(widget.role);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    // Automatically shrink/hide giant Scan circular FAB when:
    // 1. Keyboard is open
    // 2. Active in B2B Chat (index 4)
    // 3. A bottom sheet or dialog route is currently pushed on top
    final bool isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final bool hideHugeFab =
        (MediaQuery.of(context).viewInsets.bottom > 0) ||
        (widget.role == Role.seller && selected == 4) ||
        (!isCurrentRoute) ||
        _tabHasSubPages[selected];

    if (widget.role == Role.admin && wide) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBackNavigation();
        },
        child: Scaffold(
          appBar: MainHeader(role: widget.role, onExit: _handleBackNavigation),
          body: Row(
            children: [
              AdminRail(
                selected: selected,
                onSelect: (i) => setState(() => selected = i),
                items: items,
              ),
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey('admin_tab_$selected'),
                  child: items[selected].page(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        appBar: _tabHasSubPages[selected]
            ? null
            : MainHeader(role: widget.role, onExit: _handleBackNavigation),
        body: RepaintBoundary(
          child: IndexedStack(
            index: selected,
            children: items.asMap().entries.map((entry) {
              return _KeepAliveTab(
                active: entry.key == selected,
                child: Navigator(
                  key: _navKeys[entry.key],
                  observers: [_fabObservers[entry.key]],
                  onGenerateRoute: (settings) => PageRouteBuilder(
                    pageBuilder: (_, __, ___) => entry.value.page(),
                    transitionDuration: const Duration(milliseconds: 220),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 180,
                    ),
                    transitionsBuilder: (_, animation, __, child) {
                      return FadeTransition(
                        opacity: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
                        child: child,
                      );
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        floatingActionButton:
            (widget.role == Role.user || widget.role == Role.seller)
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                reverseDuration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (child, animation) {
                  final offsetAnimation =
                      Tween<Offset>(
                        begin: const Offset(0.0, 2.0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOut,
                        ),
                      );
                  return SlideTransition(
                    position: offsetAnimation,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: !hideHugeFab
                    ? GestureDetector(
                        key: const ValueKey('fab_visible'),
                        onTap: () => _selectTab(2),
                        onLongPress: () {
                          Feedback.forLongPress(context);
                          _selectTab(2);
                        },
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: const BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                              BoxShadow(
                                color: primary,
                                blurRadius: 15,
                                spreadRadius: -5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('fab_hidden')),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: (widget.role == Role.admin)
            ? _buildScrollableBottomNav(items)
            : NavigationBar(
                selectedIndex: selected,
                height: 72,
                onDestinationSelected: _selectTab,
                destinations: [
                  for (int i = 0; i < items.length; i++)
                    NavigationDestination(
                      icon:
                          ((widget.role == Role.user ||
                                  widget.role == Role.seller) &&
                              i == 2)
                          ? AnimatedOpacity(
                              opacity: hideHugeFab ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: _buildIconWithBadge(items[i]),
                            )
                          : _buildIconWithBadge(items[i]),
                      label: items[i].label,
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildIconWithBadge(NavItem item, {Color? color, double? size}) {
    if (item.label == 'Chats') {
      return ValueListenableBuilder<int>(
        valueListenable: liveSocketService.unreadChatCount,
        builder: (context, count, child) {
          if (count > 0) {
            return Badge(
              label: Text(count > 99 ? '99+' : count.toString()),
              child: Icon(item.icon, color: color, size: size),
            );
          }
          return Icon(item.icon, color: color, size: size);
        },
      );
    }
    return Icon(item.icon, color: color, size: size);
  }

  Widget _buildScrollableBottomNav(List<NavItem> items) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final isSelected = selected == i;
            final width = MediaQuery.sizeOf(context).width / 4.5;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _selectTab(i),
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated pill + icon
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primary.withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 1.0, end: isSelected ? 1.15 : 1.0),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) => Transform.scale(
                          scale: scale,
                          child: _buildIconWithBadge(
                            items[i],
                            color: isSelected ? primary : muted,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w600,
                        color: isSelected ? primary : muted,
                        fontFamily: 'Inter',
                      ),
                      child: Text(items[i].label),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FabObserver extends NavigatorObserver {
  _FabObserver({required this.onDepthChanged});
  final ValueChanged<bool> onDepthChanged;

  @override
  void didPush(Route route, Route? previousRoute) {
    if (previousRoute != null) onDepthChanged(true);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (navigator?.canPop() == false) onDepthChanged(false);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    if (navigator?.canPop() == false) onDepthChanged(false);
  }
}

class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.child, required this.active});
  final Widget child;
  final bool active;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  bool _hasBuilt = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.active) {
      _hasBuilt = true;
    }
    if (!_hasBuilt) {
      return const SizedBox.shrink();
    }
    return widget.child;
  }
}

class NavItem {
  const NavItem(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget Function() page;
}

List<NavItem> destinations(Role role) => switch (role) {
  Role.user => [
    const NavItem('Home', Icons.home_outlined, UserHomePage.new),
    const NavItem('Chats', Icons.chat_bubble_outline, ShopPaymentPage.new),
    const NavItem('Scan', Icons.qr_code_scanner, UserScanPage.new),
    const NavItem('Saved', Icons.favorite_border, UserSavedPage.new),
    const NavItem('History', Icons.history_rounded, UserHistoryPage.new),
  ],
  Role.seller => [
    const NavItem('Dash', Icons.dashboard_outlined, SellerDashboardPage.new),
    const NavItem('Shelf', Icons.inventory_2_outlined, SellerInventoryPage.new),
    const NavItem('Scan', Icons.qr_code_scanner, SellerScanPage.new),
    const NavItem('Chats', Icons.chat_bubble_outline, SellerChatPage.new),
    const NavItem('B2B Chat', Icons.handshake_outlined, B2BChatPage.new),
  ],
  Role.admin => [
    const NavItem(
      'Overview',
      Icons.admin_panel_settings_outlined,
      AdminDashboardPage.new,
    ),
    const NavItem('Shops', Icons.store_outlined, AdminShopsPage.new),
    const NavItem(
      'Financials',
      Icons.account_balance_wallet_outlined,
      AdminFinancialsPage.new,
    ),
    const NavItem(
      'Signals',
      Icons.notifications_active_outlined,
      AdminSignalsPage.new,
    ),
    const NavItem('Promos', Icons.campaign_outlined, AdminPromotionsPage.new),
    const NavItem('Disputes', Icons.gavel_outlined, AdminDisputesPage.new),
    const NavItem(
      'Accounts',
      Icons.manage_accounts_outlined,
      AdminAccountsPage.new,
    ),
  ],
};
