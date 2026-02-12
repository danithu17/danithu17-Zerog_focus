import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- STATE MANAGEMENT ---
final selectedIndexProvider = StateProvider<int>((ref) => 0);
final isRunningProvider = StateProvider<bool>((ref) => false);
final timerValueProvider = StateProvider<int>((ref) => 1500);
final stardustProvider = StateProvider<int>((ref) => 0);
final unlockedPlanetsProvider = StateProvider<List<int>>((ref) => [0, 1, 2]); // මුලින් දෙන ටික

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
  PlanetInfo("MARS", 45, Colors.redAccent, Icons.circle),
  PlanetInfo("NEPTUNE", 90, Colors.indigoAccent, Icons.blur_on),
];

final selectedMissionProvider = StateProvider<int>((ref) => 1);

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

class MainNavigationLayout extends ConsumerStatefulWidget {
  const MainNavigationLayout({super.key});
  @override
  ConsumerState<MainNavigationLayout> createState() => _MainNavigationLayoutState();
}

class _MainNavigationLayoutState extends ConsumerState<MainNavigationLayout> {
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ප්ලැනට් සහ ස්ටාර්ඩස්ට් ලෝඩ් කරන ලොජික් එක
  _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    ref.read(stardustProvider.notifier).state = prefs.getInt('stardust') ?? 0;
    final savedPlanets = prefs.getStringList('unlocked') ?? ["0", "1", "2"];
    ref.read(unlockedPlanetsProvider.notifier).state = savedPlanets.map(int.parse).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedIndexProvider);
    final List<Widget> screens = [const OrbitDashboard(), const GalaxyCollection(), const StatsScreen()];

    return Scaffold(
      body: screens[selectedIndex],
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: GNav(
          gap: 8, activeColor: Colors.cyanAccent, iconSize: 24,
          padding: const EdgeInsets.all(16), tabBackgroundColor: Colors.cyanAccent.withOpacity(0.1),
          color: Colors.white54,
          tabs: const [
            GButton(icon: Icons.rocket_launch, text: 'Orbit'),
            GButton(icon: Icons.public, text: 'Galaxy'),
            GButton(icon: Icons.analytics, text: 'Stats'),
          ],
          selectedIndex: selectedIndex,
          onTabChange: (index) => ref.read(selectedIndexProvider.notifier).state = index,
        ),
      ),
    );
  }
}

// --- ORBIT DASHBOARD ---
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
      if (mounted) setState(() { gyroX = event.x * 3; gyroY = event.y * 3; });
    });
  }

  void _completeMission() async {
    final prefs = await SharedPreferences.getInstance();
    final mission = missions[ref.read(selectedMissionProvider)];
    
    // Stardust එකතු කිරීම (විනාඩියකට 10 බැගින්)
    int earned = mission.minutes * 10;
    int currentDust = ref.read(stardustProvider) + earned;
    ref.read(stardustProvider.notifier).state = currentDust;
    await prefs.setInt('stardust', currentDust);

    _showSuccessDialog(mission.name, earned);
  }

  void _showSuccessDialog(String name, int dust) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text("MISSION ACCOMPLISHED! 🚀"),
        content: Text("You explored $name and earned $dust Stardust!"),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("AWESOME"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeLeft = ref.watch(timerValueProvider);
    final isRunning = ref.watch(isRunningProvider);
    final dust = ref.watch(stardustProvider);
    final currentMission = missions[ref.watch(selectedMissionProvider)];
    double progress = timeLeft / (currentMission.minutes * 60);

    return Stack(
      children: [
        // Stardust Display
        Positioned(top: 50, right: 20, child: Row(children: [
          const Icon(Icons.auto_fix_high, color: Colors.amberAccent, size: 18),
          const SizedBox(width: 5),
          Text("$dust", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
        ])),

        // Orbit Paths (අලුතින් එකතු කළේ)
        Center(child: Container(
          width: 280, height: 280,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.05), width: 1)),
        )),

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
                boxShadow: [BoxShadow(color: currentMission.color.withOpacity(0.6), blurRadius: 25)],
              ),
            ),
          ),
        ),

        // Timer
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              CircularPercentIndicator(
                radius: 110.0, lineWidth: 4.0, percent: progress.clamp(0.0, 1.0),
                center: Text("${(timeLeft ~/ 60).toString().padLeft(2, '0')}:${(timeLeft % 60).toString().padLeft(2, '0')}",
                  style: const TextStyle(fontSize: 50, fontWeight: FontWeight.w100)),
                circularStrokeCap: CircularStrokeCap.round, backgroundColor: Colors.white10, progressColor: currentMission.color,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
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
                        _completeMission();
                      }
                    });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: isRunning ? Colors.red : currentMission.color),
                child: Text(isRunning ? "ABORT" : "START MISSION"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- GALAXY COLLECTION ---
class GalaxyCollection extends ConsumerWidget {
  const GalaxyCollection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(unlockedPlanetsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("MY UNIVERSE"), backgroundColor: Colors.transparent),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 20),
        itemCount: unlocked.length,
        itemBuilder: (context, index) {
          final m = missions[unlocked[index]];
          return Column(children: [Icon(m.icon, color: m.color, size: 50), Text(m.name)]);
        },
      ),
    );
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text("Stats Coming Soon"));
}