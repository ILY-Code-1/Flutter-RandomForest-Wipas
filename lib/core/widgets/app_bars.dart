import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'badges.dart';

/// System text scale, clamped like the app (max 130%). Used to size the app
/// bars so enlarged titles are never clipped.
double _textScale() => WidgetsBinding.instance.platformDispatcher.textScaleFactor.clamp(1.0, 1.3);

/// Navy top bar for main tabs: title, one-line subtitle (or custom row) and
/// optional bell with unread badge. Min height 64.
class WipasAppBarTop extends StatelessWidget implements PreferredSizeWidget {
  const WipasAppBarTop({super.key, required this.title, this.subtitle, this.subtitleWidget, this.unreadCount, this.onBell});

  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;

  /// When non-null the bell is shown.
  final int? unreadCount;
  final VoidCallback? onBell;

  @override
  Size get preferredSize {
    final t = _textScale();
    final h = subtitleWidget != null ? 16 + 30 * t + 6 + (20 * t < 32 ? 32 : 20 * t) : 16 + 30 * t + 18 * t;
    return Size.fromHeight((h < WipasSize.appBar ? WipasSize.appBar : h).ceilToDouble() + 2);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: WipasColors.navy,
      child: SafeArea(
        bottom: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: WipasSize.appBar),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(WipasSpace.lg, WipasSpace.sm, WipasSpace.sm, WipasSpace.sm),
            child: Row(children: [
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Semantics(
                    header: true,
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WipasText.title.copyWith(color: Colors.white, fontSize: 21)),
                  ),
                  if (subtitleWidget != null) ...[const SizedBox(height: 6), subtitleWidget!],
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WipasText.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                ]),
              ),
              if (unreadCount != null)
                Semantics(
                  button: true,
                  label: 'Notifikasi, $unreadCount belum dibaca',
                  excludeSemantics: true,
                  child: SizedBox(
                    width: WipasSize.touch,
                    height: WipasSize.touch,
                    child: InkResponse(
                      onTap: onBell,
                      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                        const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                        if (unreadCount! > 0)
                          Positioned(right: 4, top: 2, child: WipasCountBadge(unreadCount!, outline: WipasColors.navy)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Secondary top bar: back button (48dp) + title + subtitle.
class WipasAppBarSub extends StatelessWidget implements PreferredSizeWidget {
  const WipasAppBarSub({super.key, required this.title, this.subtitle, this.onBack});

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  @override
  Size get preferredSize {
    final h = 8 + (30 + 18) * _textScale();
    return Size.fromHeight((h < WipasSize.appBar ? WipasSize.appBar : h).ceilToDouble() + 4);
  }

  @override
  Widget build(BuildContext context) => Material(
        color: WipasColors.navy,
        child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: WipasSize.appBar),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: WipasSpace.xs, vertical: WipasSpace.xs),
              child: Row(children: [
                IconButton(
                  tooltip: 'Kembali',
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  constraints: const BoxConstraints(minWidth: WipasSize.touch, minHeight: WipasSize.touch),
                ),
                const SizedBox(width: WipasSpace.xs),
                Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Semantics(
                      header: true,
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WipasText.title.copyWith(color: Colors.white, fontSize: 21)),
                    ),
                    if (subtitle != null)
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WipasText.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}

class NavTab {
  const NavTab({required this.path, required this.label, required this.icon, required this.activeIcon, this.badge = 0});
  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int badge;
}

/// Bottom navigation (80dp) with a 64×32 pill indicator.
class WipasBottomNav extends StatelessWidget {
  const WipasBottomNav({super.key, required this.tabs, required this.currentIndex, required this.onTap});

  final List<NavTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: WipasColors.surface,
          border: Border(top: BorderSide(color: WipasColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: WipasSize.bottomNav,
            child: Row(children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(child: _NavItem(tab: tabs[i], selected: i == currentIndex, onTap: () => onTap(i))),
            ]),
          ),
        ),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.selected, required this.onTap});
  final NavTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: '${tab.label}${tab.badge > 0 ? ', ${tab.badge} perlu perhatian' : ''}',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              Container(
                width: WipasSize.navIndicator.width,
                height: WipasSize.navIndicator.height,
                decoration: BoxDecoration(
                  color: selected ? WipasColors.navyTint : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(selected ? tab.activeIcon : tab.icon,
                    color: selected ? WipasColors.navy : WipasColors.textSecondary, size: WipasSize.iconLarge),
              ),
              if (tab.badge > 0) Positioned(right: 8, top: -6, child: WipasCountBadge(tab.badge, outline: Colors.white)),
            ]),
            const SizedBox(height: 4),
            Text(tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WipasText.bodySmall.copyWith(
                  color: selected ? WipasColors.navy : WipasColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                )),
          ]),
        ),
      );
}
