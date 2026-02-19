import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game/ski_game.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait and hide status bar
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const SkiRunApp());
}

class SkiRunApp extends StatelessWidget {
  const SkiRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ski Run',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  late final SkiGame _game;

  @override
  void initState() {
    super.initState();
    _game = SkiGame();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause game when app goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_game.state == GameState.playing) {
        _game.player.turnDir = 0;
        _game.player.touchSide = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Android back button: return to menu if playing, else allow exit
          if (_game.state == GameState.playing) {
            _game.state = GameState.dead;
          } else if (_game.state == GameState.dead) {
            _game.state = GameState.menu;
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: GameWidget(game: _game),
    );
  }
}
