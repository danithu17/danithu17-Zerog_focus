import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

// --- STATE MANAGEMENT ---
final selectedIndexProvider = StateProvider<int>((ref) => 0);
final isRunningProvider = StateProvider<bool>((ref) => false);
final timerValueProvider = StateProvider<int>((ref) => 1500); // Default 25m

// Planet Selection State
class PlanetInfo {
  final String name;
  final int minutes;
  final Color color;
  final IconData icon;
  PlanetInfo(this.name, this.minutes, this.color, this.icon);
}

final List<PlanetInfo> missions = [
  PlanetInfo("MOON", 10, Colors.grey, Icons.nightlight_round),
  PlanetInfo("EARTH", 25, Colors.blueAccent, Icons.public),
  PlanetInfo("SATURN", 60, Colors.orangeAccent, Icons.brightness_low),
];

final selectedMissionProvider = StateProvider<int>((ref) => 1); // Default Earth

void main() => runApp(const ProviderScope(child: ZeroGApp()));

class ZeroGApp extends StatelessWidget {
  const ZeroGApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050508),
        primaryColor: Colors.cyanAccent,
      ),
      home: const MainNavigationLayout(),
    );
  }
}

class MainNavigationLayout extends ConsumerWidget {
  const MainNavigationLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedIndexProvider);
    final List<Widget> screens = [
      const OrbitDashboard(),
      const GalaxyCollection(),
      const StatsScreen(),
    ];

    return Scaffold(
      body: screens[selectedIndex],
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: GNav(
          gap: 8,
          activeColor: Colors.cyanAccent,
          iconSize: 24,
          padding: const EdgeInsets.all(16),
          tabBackgroundColor: Colors.cyanAccent.withOpacity(0.1),
          color: Colors.white54,
          tabs: const [
            GButton(icon: Icons.rocket_launch, text: 'Orbit'),
            GButton(icon: Icons.auto_awesome_motion, text: 'Galaxy'),
            GButton(icon: Icons.analytics, text: 'Stats'),
          ],
          selectedIndex: selectedIndex,
          onTabChange: (index) => ref.read(selectedIndexProvider.notifier).state = index,
        ),
      ),
    );
  }
}

// --- ORBIT DASHBOARD (HOME) ---
class OrbitDashboard extends ConsumerStatefulWidget {
  const OrbitDashboard({super.key});
  @override
  ConsumerState<OrbitDashboard> createState() => _OrbitDashboardState();
}

class _OrbitDashboardState extends ConsumerState<OrbitDashboard> with TickerProviderStateMixin {
  double gyroX = 0, gyroY = 0;
  late AnimationController _orbitController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    accelerometerEvents.listen((event) {
      if (mounted) setState(() { gyroX = event.x * 2.5; gyroY = event.y * 2.5; });
    });
  }

  void toggleTimer() {
    final isRunning = ref.read(isRunningProvider);
    if (isRunning) {
      _timer?.cancel();
      ref.read(isRunningProvider.notifier).state = false;
    } else {
      ref.read(isRunningProvider.notifier).state = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (ref.read(timerValueProvider) > 0) {
          ref.read(timerValueProvider.notifier).state--;
        } else {
          t.cancel();
          ref.read(isRunningProvider.notifier).state = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeLeft = ref.watch(timerValueProvider);
    final isRunning = ref.watch(isRunningProvider);
    final currentMission = missions[ref.watch(selectedMissionProvider)];
    double totalSeconds = currentMission.minutes * 60.0;
    double progress = timeLeft / totalSeconds;

    return Stack(
      children: [
        // Planet Selector (Horizontal List)
        if (!isRunning)
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: missions.length,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemBuilder: (context, index) {
                bool isSelected = ref.watch(selectedMissionProvider) == index;
                return GestureDetector(
                  onTap: () {
                    ref.read(selectedMissionProvider.notifier).state = index;
                    ref.read(timerValueProvider.notifier).state = missions[index].minutes * 60;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 100,
                    margin: const EdgeInsets.only(right: 15),
                    decoration: BoxDecoration(
                      color: isSelected ? missions[index].color.withOpacity(0.2) : Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? missions[index].color : Colors.transparent),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(missions[index].icon, color: missions[index].color),
                        const SizedBox(height: 5),
                        Text(missions[index].name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        Text("${missions[index].minutes}m", style: const TextStyle(fontSize: 12, color: Colors.white54)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // Floating Planet
        Center(
          child: AnimatedBuilder(
            animation: _orbitController,
            builder: (context, child) {
              double angle = _orbitController.value * 2 * math.pi;
              return Transform.translate(
                offset: Offset(math.cos(angle) * 140 + gyroX, math.sin(angle) * 140 + gyroY),
                child: child,
              );
            },
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [currentMission.color, Colors.black]),
                boxShadow: [BoxShadow(color: currentMission.color.withOpacity(0.5), blurRadius: 20)],
              ),
            ),
          ),
        ),

        // Timer UI
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              CircularPercentIndicator(
                radius: 115.0,
                lineWidth: 5.0,
                percent: progress.clamp(0.0, 1.0),
                center: Text(
                  "${(timeLeft ~/ 60).toString().padLeft(2, '0')}:${(timeLeft % 60).toString().padLeft(2, '0')}",
                  style: const TextStyle(fontSize: 50, fontWeight: FontWeight.w100),
                ),
                circularStrokeCap: CircularStrokeCap.round,
                backgroundColor: Colors.white10,
                progressColor: currentMission.color,
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: toggleTimer,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: isRunning ? Colors.redAccent : currentMission.color),
                    color: (isRunning ? Colors.redAccent : currentMission.color).withOpacity(0.05),
                  ),
                  child: Text(
                    isRunning ? "ABORT MISSION" : "START MISSION",
                    style: TextStyle(color: isRunning ? Colors.redAccent : currentMission.color, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class GalaxyCollection extends StatelessWidget {
  const GalaxyCollection({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Galaxy Collection (Unlocked Planets)"));
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Focus Statistics"));
  }
}