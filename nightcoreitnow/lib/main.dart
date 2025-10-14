import 'dart:io';
import 'package:flutter/material.dart' as material; // Using alias to prevent conflicts
import 'package:fluent_ui/fluent_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:process_run/shell.dart';
import 'package:window_manager/window_manager.dart';

// Application entry point
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    title: "Nightcore It, Now!",
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setIcon('assets/icon.ico');
  });

  runApp(const NightcoreApp());
}

class NightcoreApp extends StatelessWidget {
  const NightcoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Using FluentApp as the root for the UI
    return FluentApp(
      title: 'Nightcore It, Now!',
      theme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: material.Colors.purple.toAccentColor(),
        visualDensity: VisualDensity.standard,
        focusTheme: FocusThemeData(
          glowFactor: is10footScreen(context) ? 2.0 : 0.0,
        ),
      ),
      home: const SplashScreen(), // The first screen is the splash screen
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- Splash Screen ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // Starts the animations and the transition to the main screen
    _startAnimation();
  }

  void _startAnimation() async {
    // The animation starts after a short delay
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _visible = true);

    // After the animation duration, navigate to the home screen
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      content: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Fade animation for the GIF
            AnimatedOpacity(
              opacity: _visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 1500),
              child: Image.asset(
                'assets/splash.gif', // Your GIF here!
                gaplessPlayback: true, // Prevents flickering
                height: 300,
              ),
            ),
            // NEW: Enhanced animation for the title text
            AnimatedPadding(
              padding: EdgeInsets.only(top: _visible ? 150.0 : 250.0), // Slides up
              duration: const Duration(milliseconds: 1200),
              curve: Curves.fastOutSlowIn,
              child: AnimatedScale(
                scale: _visible ? 1.0 : 0.5, // Zooms in with a bounce
                duration: const Duration(milliseconds: 1200),
                curve: Curves.elasticOut,
                child: AnimatedOpacity(
                  opacity: _visible ? 1.0 : 0.0, // Fades in
                  duration: const Duration(milliseconds: 800),
                  child: Text(
                    'Nightcore It, Now!',
                    textAlign: TextAlign.center,
                    style: FluentTheme.of(context).typography.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 40, // Increased font size
                      shadows: [
                        // Enhanced glow effect
                        const Shadow(blurRadius: 20.0, color: material.Colors.purple),
                        const Shadow(blurRadius: 10.0, color: material.Colors.purpleAccent),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// --- Home Screen ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _inputFile;
  String? _outputFile;
  double _speedPercentage = 125.0; // Initial slider value (125%)
  bool _isSlowedMode = false;
  
  bool _isProcessing = false;
  String _statusMessage = 'Ready to start...';
  double? _ffmpegProgress;

  // Function to select the input file
  Future<void> _pickInputFile() async {
    final result = await FilePicker.platform.pickFiles(
      //type: FileType.audio,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'flac', 'ogg'],
      dialogTitle: 'Select an audio file',
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _inputFile = result.files.single.path;
        // Suggests a name for the output file
        final file = File(_inputFile!);
        final dir = file.parent.path;
        final filename = file.path.split(Platform.pathSeparator).last;
        final ext = filename.split('.').last;
        final nameWithoutExt = filename.substring(0, filename.length - ext.length - 1);
        _outputFile = '$dir${Platform.pathSeparator}${nameWithoutExt}_nightcore.$ext';
        _statusMessage = 'Input file selected.';
      });
    }
  }

  // Function to define where to save the output file
  Future<void> _pickOutputFile() async {
    final originalFileName = _inputFile?.split(Platform.pathSeparator).last ?? 'output.mp3';
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save the nightcore file',
      fileName: originalFileName,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'flac', 'ogg'],
    );
    if (result != null) {
      setState(() {
        _outputFile = result;
      });
    }
  }

  // Main function that runs FFmpeg
  Future<void> _processFile() async {
    if (_inputFile == null || _outputFile == null) {
      _showErrorDialog('Error', 'Please select an input file and an output destination.');
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Processing...';
      _ffmpegProgress = null; // Show indeterminate progress bar
    });

    try {
      // REINVENTED LOGIC
      final double speedMultiplier = _speedPercentage / 100.0;
      final int newSampleRate = _isSlowedMode ? (44100 * speedMultiplier).round() : (44100 * (speedMultiplier * 2)).round();

      final ffmpegCommand = [
        '-y',
        '-i', '"$_inputFile"',
        '-af', '"asetrate=$newSampleRate,aresample=44100"',
        '-vn',
        '"$_outputFile"'
      ].join(' ');
      
      var shell = Shell(verbose: false);
      
      // Check if ffmpeg exists in the system path or in the app directory
      bool ffmpegExists = await _isFfmpegAvailable(shell);
      if (!ffmpegExists) {
        throw const ProcessException("ffmpeg", [], "Executable not found. Please check the instructions in the README.", 1);
      }
      
      await shell.run('ffmpeg $ffmpegCommand');
      
      setState(() {
        _statusMessage = 'Successfully completed! File saved to:\n$_outputFile';
        _ffmpegProgress = 1.0;
      });

    } on ProcessException catch (e) {
      _showErrorDialog('FFmpeg Error', 'Error during processing.\nMake sure FFmpeg is installed and accessible in your PATH.\n\nDetails: ${e.message}');
      setState(() => _statusMessage = 'An error occurred during processing.');
    } catch (e) {
       _showErrorDialog('Unexpected Error', 'An error occurred: $e');
       setState(() => _statusMessage = 'An error occurred.');
    } finally {
      setState(() => _isProcessing = false);
    }
  }
  
  // Checks for FFmpeg availability
  Future<bool> _isFfmpegAvailable(Shell shell) async {
    try {
      // which/where searches the PATH
      await shell.run('which ffmpeg');
      return true;
    } catch (_) {
      try {
        await shell.run('where ffmpeg');
        return true;
      } catch (_) {
        // If not in path, check the executable's directory
        final ffmpegPath = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
        final localFfmpeg = File('${Directory.current.path}${Platform.pathSeparator}$ffmpegPath');
        return await localFfmpeg.exists();
      }
    }
  }

  // Shows an error dialog
  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          FilledButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: const PageHeader(title: Text('Nightcore It, Now!')),
      content: Stack(
        children: [
          // Background with the "loli"
          Positioned.fill(
            child: Opacity(
              opacity: 0.15, // Transparency to not be distracting
              child: Image.asset(
                'assets/background.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Main content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Input File Section
                    InfoLabel(
                      label: '1. Select the input audio file',
                      child: Row(
                        children: [
                          Expanded(
                            child: TextBox(
                              controller: TextEditingController(text: _inputFile ?? 'No file selected'),
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Button(
                            onPressed: _isProcessing ? null : _pickInputFile,
                            child: const Text('Browse...'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Output File Section
                    InfoLabel(
                      label: '2. Choose where to save the converted file',
                      child: Row(
                        children: [
                          Expanded(
                            child: TextBox(
                              controller: TextEditingController(text: _outputFile ?? 'No destination selected'),
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Button(
                            onPressed: _isProcessing ? null : _pickOutputFile,
                            child: const Text('Browse...'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // Speed Slider Section
                    InfoLabel(
                      label: '3. Set the speed (${_speedPercentage.toInt()}%)',
                      child: Slider(
                        min: 1,
                        max: 200,
                        value: _speedPercentage,
                        onChanged: _isProcessing
                            ? null
                            : (v) => setState(() => _speedPercentage = v),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Slowed Mode Checkbox
                    Checkbox(
                      checked: _isSlowedMode,
                      onChanged: (value) {
                        setState(() {
                          _isSlowedMode = value ?? false;
                        });
                      },
                      content: const Text('Use Slowed Mode'),
                    ),
                    const SizedBox(height: 40),

                    // Start Button
                    FilledButton(
                      onPressed: (_inputFile == null || _isProcessing) ? null : _processFile,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _isProcessing ? 'Processing...' : 'Nightcore It!',
                          style: FluentTheme.of(context).typography.bodyLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Status and Progress Bar Area
                    Card(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: FluentTheme.of(context).typography.body,
                          ),
                          if (_isProcessing) ...[
                            const SizedBox(height: 12),
                            ProgressBar(value: _ffmpegProgress),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}