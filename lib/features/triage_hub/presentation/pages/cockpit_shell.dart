import 'package:flutter/material.dart';
import 'package:local2local/features/triage_hub/presentation/widgets/cockpit_header.dart';

class CockpitShell extends StatefulWidget {
  const CockpitShell({super.key});

  @override
  State<CockpitShell> createState() => _CockpitShellState();
}

class _CockpitShellState extends State<CockpitShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      body: Row(
        children: [
          // SIDE NAVIGATION BAR
          NavigationRail(
            backgroundColor: const Color(0xFF16162A),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.selected,
            selectedIconTheme: const IconThemeData(color: Colors.blueAccent),
            unselectedIconTheme: const IconThemeData(color: Colors.white24),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.list_alt),
                label: Text('Triage'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.grid_view),
                label: Text('Health'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.directions_car),
                label: Text('Fleet'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.psychology),
                label: Text('Evolution'),
              ),
            ],
          ),
          // MAIN CONTENT AREA
          Expanded(
            child: Column(
              children: [
                const CockpitHeader(),
                const Expanded(
                  child: Center(
                    child: Text(
                      'L2LAAF COCKPIT ACTIVE',
                      style: TextStyle(color: Colors.white24, letterSpacing: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}