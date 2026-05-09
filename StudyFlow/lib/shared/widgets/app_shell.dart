import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _routes = [
    '/today',
    '/schedule',
    '/tutor',
    '/routines',
    '/settings',
  ];

  int _indexFromLocation(String location) {
    for (var i = 0; i < _routes.length; i++) {
      if (location.startsWith(_routes[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _indexFromLocation(location);
    final width = MediaQuery.of(context).size.width;
    final useRail = width >= 700;

    const destinations = [
      _NavItem(icon: Icons.today_outlined, selected: Icons.today, label: 'Hoy'),
      _NavItem(
          icon: Icons.calendar_view_week_outlined,
          selected: Icons.calendar_view_week,
          label: 'Horario'),
      _NavItem(
          icon: Icons.school_outlined, selected: Icons.school, label: 'Tutor'),
      _NavItem(
          icon: Icons.auto_awesome_outlined,
          selected: Icons.auto_awesome,
          label: 'Rutinas'),
      _NavItem(
          icon: Icons.settings_outlined,
          selected: Icons.settings,
          label: 'Ajustes'),
    ];

    void goTo(int i) => context.go(_routes[i]);
    void goSearch() => context.go('/search');

    final content = Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyT): _GoTodayIntent(),
        SingleActivator(LogicalKeyboardKey.keyS): _GoScheduleIntent(),
        SingleActivator(LogicalKeyboardKey.keyN): _GoNewTaskIntent(),
      },
      child: Actions(
        actions: {
          _GoTodayIntent: CallbackAction<_GoTodayIntent>(
            onInvoke: (_) => context.go('/today'),
          ),
          _GoScheduleIntent: CallbackAction<_GoScheduleIntent>(
            onInvoke: (_) => context.go('/schedule'),
          ),
          _GoNewTaskIntent: CallbackAction<_GoNewTaskIntent>(
            onInvoke: (_) {
              context.go('/today');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Pulsa Nueva tarea para crearla.')),
              );
              return null;
            },
          ),
        },
        child: child,
      ),
    );

    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: idx,
              onDestinationSelected: goTo,
              labelType: NavigationRailLabelType.all,
              trailing: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: IconButton(
                  tooltip: 'Buscar',
                  onPressed: goSearch,
                  icon: const Icon(Icons.search),
                ),
              ),
              destinations: destinations
                  .map((d) => NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selected),
                        label: Text(d.label),
                      ))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: goTo,
        items: destinations
            .map((d) => BottomNavigationBarItem(
                  icon: Icon(d.icon),
                  activeIcon: Icon(d.selected),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}

class _GoTodayIntent extends Intent {
  const _GoTodayIntent();
}

class _GoScheduleIntent extends Intent {
  const _GoScheduleIntent();
}

class _GoNewTaskIntent extends Intent {
  const _GoNewTaskIntent();
}

class _NavItem {
  final IconData icon;
  final IconData selected;
  final String label;
  const _NavItem(
      {required this.icon, required this.selected, required this.label});
}
