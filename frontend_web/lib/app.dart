import 'dart:async';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api_client.dart';
import 'l10n/app_localizations.dart';

class StudyServiceApp extends StatefulWidget {
  const StudyServiceApp({super.key});

  @override
  State<StudyServiceApp> createState() => _StudyServiceAppState();
}

class _StudyServiceAppState extends State<StudyServiceApp> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'StudyService Web',
          locale: Locale(_controller.localeCode),
          supportedLocales: const [
            Locale('en'),
            Locale('zh'),
            Locale('ko'),
            Locale('ru'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0F766E),
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF4F7F8),
            snackBarTheme: const SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF0F172A),
              elevation: 0,
              centerTitle: false,
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: const BorderSide(color: Color(0xFFD7E3F4)),
              ),
            ),
            chipTheme: ChipThemeData.fromDefaults(
              secondaryColor: const Color(0xFF0F766E),
              labelStyle: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
              brightness: Brightness.light,
            ),
            navigationRailTheme: const NavigationRailThemeData(
              backgroundColor: Colors.transparent,
              selectedIconTheme: IconThemeData(color: Color(0xFF0F766E)),
              selectedLabelTextStyle: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
              unselectedIconTheme: IconThemeData(color: Color(0xFF475569)),
              unselectedLabelTextStyle: TextStyle(color: Color(0xFF475569)),
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFD7E3F4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFD7E3F4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF0F766E),
                  width: 1.5,
                ),
              ),
            ),
          ),
          home: MainNavigationScreen(controller: _controller),
        );
      },
    );
  }

}

class AppController extends ChangeNotifier {
  AppController()
    : baseUrl = _defaultBaseUrl(),
      _api = ApiClient(baseUrl: _defaultBaseUrl());

  final ApiClient _api;

  String baseUrl;
  String localeCode = 'ko';
  String? token;
  UserProfile? currentUser;
  String? latestLectureId;
  int _lectureLibraryRevision = 0;

  ApiClient get api {
    _api.baseUrl = baseUrl;
    _api.token = token;
    return _api;
  }

  bool get isLoggedIn => token != null && token!.isNotEmpty;
  int get lectureLibraryRevision => _lectureLibraryRevision;

  void changeLanguage(String code) {
    if (localeCode == code) {
      return;
    }
    localeCode = code;
    notifyListeners();
  }

  void setBaseUrl(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'/$'), '');
    if (trimmed.isEmpty || trimmed == baseUrl) {
      return;
    }
    baseUrl = trimmed;
    notifyListeners();
  }

  Future<Map<String, dynamic>> checkHealth() => api.health();

  Future<UserProfile> register({
    required String email,
    required String password,
  }) async {
    final user = await api.register(email: email, password: password);
    currentUser = user;
    notifyListeners();
    return user;
  }

  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    token = await api.login(email: email, password: password);
    final user = await api.me();
    currentUser = user;
    notifyListeners();
    return user;
  }

  Future<UserProfile> refreshMe() async {
    final user = await api.me();
    currentUser = user;
    notifyListeners();
    return user;
  }

  void logout() {
    token = null;
    currentUser = null;
    latestLectureId = null;
    notifyListeners();
  }

  void markLectureUpdated(String lectureId) {
    if (lectureId.isEmpty) {
      return;
    }
    latestLectureId = lectureId;
    _lectureLibraryRevision += 1;
    notifyListeners();
  }
}

String _defaultBaseUrl() {
  if (kIsWeb) {
    return 'http://127.0.0.1:8000';
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:8000';
    default:
      return 'http://127.0.0.1:8000';
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userEmail = widget.controller.currentUser?.email;
    final destinations = <({IconData icon, String label, Widget page})>[
      (
        icon: Icons.home_outlined,
        label: l10n.home,
        page: HomeScreen(
          controller: widget.controller,
          onSelectFeature: (index) => setState(() => _selectedIndex = index),
        ),
      ),
      (
        icon: Icons.upload_file_outlined,
        label: l10n.recording,
        page: RecordingScreen(
          controller: widget.controller,
          onSelectFeature: (index) => setState(() => _selectedIndex = index),
        ),
      ),
      (
        icon: Icons.menu_book_outlined,
        label: l10n.aiSummary,
        page: AISummaryScreen(
          controller: widget.controller,
          onSelectFeature: (index) => setState(() => _selectedIndex = index),
        ),
      ),
      (
        icon: Icons.quiz_outlined,
        label: l10n.quiz,
        page: QuizScreen(
          controller: widget.controller,
          onSelectFeature: (index) => setState(() => _selectedIndex = index),
        ),
      ),
      (
        icon: Icons.event_note_outlined,
        label: l10n.planner,
        page: PlannerScreen(controller: widget.controller),
      ),
      (
        icon: Icons.translate_outlined,
        label: l10n.mail,
        page: MailTranslateScreen(controller: widget.controller),
      ),
      (
        icon: Icons.psychology_outlined,
        label: l10n.solver,
        page: SolverScreen(controller: widget.controller),
      ),
    ];
    final isWideLayout = MediaQuery.sizeOf(context).width >= 1080;
    final content = destinations[_selectedIndex].page;
    final currentLabel = destinations[_selectedIndex].label;

    return Scaffold(
      drawer: isWideLayout
          ? null
          : Drawer(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _LaunchBadge(label: 'Study smarter'),
                          const SizedBox(height: 14),
                          const Text(
                            'StudyService',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.controller.isLoggedIn
                                ? (userEmail ?? 'Signed in')
                                : 'Browse as guest',
                            style: const TextStyle(color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        children: [
                          for (final entry in destinations.asMap().entries)
                            ListTile(
                              leading: Icon(entry.value.icon),
                              selected: entry.key == _selectedIndex,
                              selectedTileColor: const Color(0xFFF0FDFA),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              title: Text(entry.value.label),
                              onTap: () {
                                Navigator.of(context).pop();
                                setState(() => _selectedIndex = entry.key);
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.appTitle),
            Text(
              currentLabel,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        titleSpacing: 20,
        actions: [
          if (isWideLayout)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: _HeaderStatusChip(
                  icon: widget.controller.isLoggedIn
                      ? Icons.verified_user_outlined
                      : Icons.person_outline,
                  label: widget.controller.isLoggedIn
                      ? (userEmail ?? 'Signed in')
                      : 'Browse as guest',
                ),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: widget.controller.changeLanguage,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'zh', child: Text('中文')),
              PopupMenuItem(value: 'ko', child: Text('한국어')),
              PopupMenuItem(value: 'ru', child: Text('Русский')),
            ],
            icon: const Icon(Icons.language),
          ),
        ],
      ),
      body: isWideLayout
          ? Row(
              children: [
                Container(
                  width: 276,
                  margin: const EdgeInsets.fromLTRB(20, 12, 0, 20),
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x140F172A),
                        blurRadius: 30,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _LaunchBadge(label: 'Web release'),
                      const SizedBox(height: 14),
                      const Text(
                        'StudyService',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Save lectures, review notes, build quizzes, and stay on top of your study plan in one calm workspace.',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: NavigationRail(
                          selectedIndex: _selectedIndex,
                          useIndicator: true,
                          groupAlignment: -0.95,
                          labelType: NavigationRailLabelType.all,
                          onDestinationSelected: (index) =>
                              setState(() => _selectedIndex = index),
                          destinations: [
                            for (final destination in destinations)
                              NavigationRailDestination(
                                icon: Icon(destination.icon),
                                label: Text(destination.label),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SidebarAccountCard(controller: widget.controller),
                    ],
                  ),
                ),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }

}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onSelectFeature,
  });

  final AppController controller;
  final ValueChanged<int> onSelectFeature;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  late final TextEditingController _baseUrlController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  String? _healthStatus;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: widget.controller.baseUrl);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _validateAuthInputs() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      _showMessage('Enter an email address first.');
      return false;
    }
    if (!_emailPattern.hasMatch(email)) {
      _showMessage('Enter a valid email address.');
      return false;
    }
    if (password.isEmpty) {
      _showMessage('Enter a password first.');
      return false;
    }
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser;
    final isWideLayout = MediaQuery.sizeOf(context).width >= 1080;
    final connectionCard = _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Connection',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              if (_healthStatus != null)
                Chip(
                  avatar: const Icon(Icons.favorite_outline, size: 18),
                  label: Text(_healthStatus!),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Use the default URL unless your API lives somewhere else.',
            style: TextStyle(color: Color(0xFF475569), height: 1.45),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: 'API base URL',
              hintText: 'http://127.0.0.1:8000',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          widget.controller.setBaseUrl(_baseUrlController.text);
                          _showMessage('Connection updated.');
                        },
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _loading
                      ? null
                      : () => _run(() async {
                          widget.controller.setBaseUrl(_baseUrlController.text);
                          final response = await widget.controller
                              .checkHealth();
                          if (!mounted) {
                            return;
                          }
                          setState(() {
                            _healthStatus =
                                response['status']?.toString() ?? 'unknown';
                          });
                          _showMessage('Connection looks good.');
                        }),
                  child: const Text('Check'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Change it only when the frontend and API are on different addresses.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ],
      ),
    );
    final authCard = _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your uploads, summaries, quizzes, and plans stay tied to the account you use here.',
            style: TextStyle(color: Color(0xFF475569), height: 1.45),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: _loading
                    ? null
                    : () => _run(() async {
                        if (!_validateAuthInputs()) {
                          return;
                        }
                        widget.controller.setBaseUrl(_baseUrlController.text);
                        final user = await widget.controller.register(
                          email: _emailController.text.trim(),
                          password: _passwordController.text,
                        );
                        _showMessage(
                          'Account created for ${user.email}. You can sign in now.',
                        );
                      }),
                child: const Text('Create account'),
              ),
              FilledButton.tonal(
                onPressed: _loading
                    ? null
                    : () => _run(() async {
                        if (!_validateAuthInputs()) {
                          return;
                        }
                        widget.controller.setBaseUrl(_baseUrlController.text);
                        final user = await widget.controller.login(
                          email: _emailController.text.trim(),
                          password: _passwordController.text,
                        );
                        _showMessage('Signed in as ${user.email}.');
                      }),
                child: const Text('Sign in'),
              ),
              OutlinedButton(
                onPressed: _loading
                      ? null
                      : () => _run(() async {
                          final user = await widget.controller.refreshMe();
                          _showMessage('Account refreshed for ${user.email}.');
                        }),
                child: const Text('Refresh account'),
              ),
              OutlinedButton(
                onPressed: _loading
                    ? null
                    : () {
                        widget.controller.logout();
                        _showMessage('Signed out.');
                      },
                child: const Text('Sign out'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _UserSummary(user: user, isLoggedIn: widget.controller.isLoggedIn),
        ],
      ),
    );

    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroPanel(
            onSelectFeature: widget.onSelectFeature,
            isLoggedIn: widget.controller.isLoggedIn,
          ),
          const SizedBox(height: 24),
          if (_loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],
          if (isWideLayout)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(
                        title: 'Get ready to study',
                        subtitle:
                            'Connect once, sign in, and then move straight into lectures, review notes, and quizzes.',
                      ),
                      connectionCard,
                      const SizedBox(height: 24),
                      const _SectionHeader(
                        title: 'Stay signed in',
                        subtitle:
                            'Use one account so your lectures and progress stay in the same place every time you come back.',
                      ),
                      authCard,
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _AccountSnapshotCard(controller: widget.controller),
                      const SizedBox(height: 16),
                      const _QuickStartCard(),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            const _SectionHeader(
              title: 'Get ready to study',
              subtitle:
                  'Connect once, sign in, and then move straight into lectures, review notes, and quizzes.',
            ),
            connectionCard,
            const SizedBox(height: 24),
            const _SectionHeader(
              title: 'Stay signed in',
              subtitle:
                  'Use one account so your lectures and progress stay in the same place every time you come back.',
            ),
            authCard,
            const SizedBox(height: 24),
            _AccountSnapshotCard(controller: widget.controller),
            const SizedBox(height: 16),
            const _QuickStartCard(),
          ],
        ],
      ),
    );
  }

}

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({
    super.key,
    required this.controller,
    required this.onSelectFeature,
  });

  final AppController controller;
  final ValueChanged<int> onSelectFeature;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  Timer? _statusPollTimer;
  PickedUpload? _selectedFile;
  bool _loading = false;
  bool _refreshInFlight = false;
  ProcessLectureResult? _result;

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    _titleController.dispose();
    _courseController.dispose();
    super.dispose();
  }

  bool _isProcessingStatus(String? status) {
    return switch (status) {
      'uploaded' || 'transcribing' || 'summarizing' || 'generating_quiz' =>
        true,
      _ => false,
    };
  }

  void _syncStatusPolling() {
    _statusPollTimer?.cancel();
    if (!_isProcessingStatus(_result?.lecture.status)) {
      return;
    }

    _statusPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshLatestResult(showMessage: false, showLoading: false);
    });
  }

  Future<void> _pickAudio() async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null) {
      return;
    }
    setState(() {
      _selectedFile = PickedUpload(name: file.name, bytes: file.bytes!);
    });
  }

  Future<void> _submit() async {
    if (!widget.controller.isLoggedIn) {
      _showMessage('Sign in first so uploads can be saved to your workspace.');
      return;
    }
    if (_selectedFile == null) {
      _showMessage('Pick an audio file first.');
      return;
    }

    setState(() => _loading = true);
    _statusPollTimer?.cancel();
    try {
      final result = await widget.controller.api.processAudio(
        title: _titleController.text.trim(),
        courseName: _courseController.text.trim(),
        audio: _selectedFile!,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
      });
      widget.controller.markLectureUpdated(result.lecture.id);
      _syncStatusPolling();
      _showMessage(
        'Upload received. StudyService will keep checking until your transcript and summary are ready.',
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshLatestResult({
    bool showMessage = true,
    bool showLoading = true,
  }) async {
    final lectureId = _result?.lecture.id;
    if (lectureId == null || lectureId.isEmpty || _refreshInFlight) {
      return;
    }

    final previousStatus = _result?.lecture.status;
    _refreshInFlight = true;
    if (showLoading && mounted) {
      setState(() => _loading = true);
    }
    try {
      final detail = await widget.controller.api.getLecture(lectureId);
      if (!mounted) {
        return;
      }
      setState(() {
        _result = ProcessLectureResult(
          lecture: detail.lecture,
          quizzes: detail.quizzes,
        );
      });
      widget.controller.markLectureUpdated(detail.lecture.id);
      _syncStatusPolling();
      if (showMessage) {
        _showMessage('Latest processing status loaded.');
      } else if (previousStatus != detail.lecture.status &&
          detail.lecture.status == 'ready') {
        _showMessage('Transcript and summaries are ready.');
      } else if (previousStatus != detail.lecture.status &&
          detail.lecture.status == 'failed') {
        final errorMessage = detail.lecture.errorMessage;
        _showMessage(
          (errorMessage != null && errorMessage.isNotEmpty)
              ? errorMessage
              : 'Lecture processing failed.',
        );
      }
    } on ApiException catch (error) {
      if (showMessage) {
        _showMessage(error.message);
      }
    } catch (error) {
      if (showMessage) {
        _showMessage(error.toString());
      }
    } finally {
      _refreshInFlight = false;
      if (showLoading && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isWideLayout = MediaQuery.sizeOf(context).width >= 1100;
    final uploadForm = _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BannerCard(
            icon: Icons.cloud_upload_outlined,
            title: 'Upload a lecture recording',
            body:
                'Name the lecture clearly, choose the course, and upload the audio file. Once it starts processing, StudyService will keep the transcript, notes, and quizzes together for you.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Lecture title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _courseController,
            decoration: const InputDecoration(labelText: 'Course name'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _pickAudio,
                  icon: const Icon(Icons.audio_file_outlined),
                  label: Text(_selectedFile?.name ?? 'Choose audio file'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? 'Uploading...' : 'Start processing'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StatsRow(
            children: [
              _MetricCard(
                label: 'Account',
                value: widget.controller.isLoggedIn
                    ? 'Ready'
                    : 'Login required',
                tint: widget.controller.isLoggedIn
                    ? const Color(0xFF0F766E)
                    : const Color(0xFFB45309),
              ),
              _MetricCard(
                label: 'Selected file',
                value: _selectedFile?.name ?? 'None yet',
              ),
              _MetricCard(
                label: 'After upload',
                value: 'Transcript, notes, quizzes',
              ),
            ],
          ),
        ],
      ),
    );
    final lectureStatus = _result?.lecture.status;
    final isProcessing = _isProcessingStatus(lectureStatus);
    final resultPanel = _result == null
        ? const _EmptyStateCard(
            icon: Icons.library_music_outlined,
            title: 'Your latest lecture will appear here',
            body:
                'After the upload begins, this panel will show progress and open the generated study material as soon as it is ready.',
          )
        : _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LectureMeta(lecture: _result!.lecture),
                const SizedBox(height: 16),
                _StatsRow(
                  children: [
                    _MetricCard(
                      label: 'Generated quizzes',
                      value: '${_result!.quizzes.length}',
                    ),
                    _MetricCard(
                      label: 'Status',
                      value: _result!.lecture.status,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _LectureProgressCard(lecture: _result!.lecture),
                const SizedBox(height: 16),
                if (isProcessing) ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonal(
                        onPressed: _loading ? null : _refreshLatestResult,
                        child: const Text('Check progress'),
                      ),
                      OutlinedButton(
                        onPressed: () => widget.onSelectFeature(2),
                        child: const Text('Open library'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (_hasStudyNotes(_result!.lecture)) ...[
                  _LectureStudyNotesSection(lecture: _result!.lecture),
                  const SizedBox(height: 16),
                ],
                if ((_result!.lecture.transcript ?? '').isNotEmpty) ...[
                  const Text(
                    'Transcript',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(_result!.lecture.transcript!),
                  const SizedBox(height: 16),
                ],
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonal(
                      onPressed: () => widget.onSelectFeature(2),
                      child: const Text('Open notes'),
                    ),
                    OutlinedButton(
                      onPressed: () => widget.onSelectFeature(3),
                      child: const Text('Open quizzes'),
                    ),
                  ],
                ),
              ],
            ),
          );

    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Lecture upload',
            subtitle:
                'Turn a lecture recording into notes, summaries, and quiz-ready review material.',
          ),
          if (_loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],
          if (isWideLayout)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: uploadForm),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(
                        title: 'Latest upload',
                        subtitle:
                            'Keep an eye on progress here, then jump straight into the generated material.',
                      ),
                      resultPanel,
                    ],
                  ),
                ),
              ],
            )
          else ...[
            uploadForm,
            const SizedBox(height: 24),
            const _SectionHeader(
              title: 'Latest upload',
              subtitle:
                  'Keep an eye on progress here, then jump straight into the generated material.',
            ),
            resultPanel,
          ],
        ],
      ),
    );
  }
}

class AISummaryScreen extends StatefulWidget {
  const AISummaryScreen({
    super.key,
    required this.controller,
    required this.onSelectFeature,
  });

  final AppController controller;
  final ValueChanged<int> onSelectFeature;

  @override
  State<AISummaryScreen> createState() => _AISummaryScreenState();
}

class _AISummaryScreenState extends State<AISummaryScreen> {
  bool _loading = false;
  bool _refreshInFlight = false;
  int _lastHandledRevision = -1;
  List<Lecture> _lectures = const [];
  LectureDetail? _selectedDetail;
  Timer? _statusPollTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromController(force: true);
    });
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    widget.controller.removeListener(_handleControllerUpdate);
    super.dispose();
  }

  bool _isProcessingStatus(String? status) {
    return switch (status) {
      'uploaded' || 'transcribing' || 'summarizing' || 'generating_quiz' =>
        true,
      _ => false,
    };
  }

  void _handleControllerUpdate() {
    _syncFromController();
  }

  Future<void> _syncFromController({bool force = false}) async {
    if (!mounted || !widget.controller.isLoggedIn) {
      return;
    }
    final revision = widget.controller.lectureLibraryRevision;
    if (!force && revision == _lastHandledRevision) {
      return;
    }
    _lastHandledRevision = revision;
    await _refreshLectures(
      preferredLectureId: widget.controller.latestLectureId,
      showMessageOnLoginRequired: false,
    );
  }

  void _syncStatusPolling() {
    _statusPollTimer?.cancel();
    final lectureId = _selectedDetail?.lecture.id;
    if (lectureId == null || !_isProcessingStatus(_selectedDetail?.lecture.status)) {
      return;
    }

    _statusPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshLectures(
        preferredLectureId: lectureId,
        showLoading: false,
        showMessageOnLoginRequired: false,
      );
    });
  }

  Future<void> _refreshLectures({
    String? preferredLectureId,
    bool showLoading = true,
    bool showMessageOnLoginRequired = true,
  }) async {
    if (!widget.controller.isLoggedIn) {
      if (showMessageOnLoginRequired) {
        _showMessage('Login first to list your lectures.');
      }
      return;
    }
    if (_refreshInFlight) {
      return;
    }
    _refreshInFlight = true;
    if (showLoading) {
      setState(() => _loading = true);
    }
    try {
      final lectures = await widget.controller.api.listLectures();
      final targetLectureId = _pickTargetLectureId(
        lectures: lectures,
        preferredLectureId: preferredLectureId,
      );
      LectureDetail? detail;
      if (targetLectureId != null) {
        detail = await widget.controller.api.getLecture(targetLectureId);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _lectures = lectures;
        _selectedDetail = detail;
      });
      _syncStatusPolling();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      _refreshInFlight = false;
      if (showLoading && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _pickTargetLectureId({
    required List<Lecture> lectures,
    String? preferredLectureId,
  }) {
    if (lectures.isEmpty) {
      return null;
    }
    if (preferredLectureId != null &&
        preferredLectureId.isNotEmpty &&
        lectures.any((lecture) => lecture.id == preferredLectureId)) {
      return preferredLectureId;
    }
    final currentId = _selectedDetail?.lecture.id;
    if (currentId != null &&
        currentId.isNotEmpty &&
        lectures.any((lecture) => lecture.id == currentId)) {
      return currentId;
    }
    return lectures.first.id;
  }

  Future<void> _loadDetail(String lectureId, {bool showLoading = true}) async {
    if (_refreshInFlight) {
      return;
    }
    _refreshInFlight = true;
    if (showLoading) {
      setState(() => _loading = true);
    }
    try {
      final detail = await widget.controller.api.getLecture(lectureId);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedDetail = detail;
      });
      _syncStatusPolling();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      _refreshInFlight = false;
      if (showLoading && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isWideLayout = MediaQuery.sizeOf(context).width >= 1100;
    final libraryList = _lectures.isEmpty
        ? _EmptyStateCard(
            icon: Icons.menu_book_outlined,
            title: 'No saved lectures yet',
            body:
                'Upload your first lecture to start building transcripts, summaries, and quizzes you can come back to later.',
            action: FilledButton.tonal(
              onPressed: () => widget.onSelectFeature(1),
              child: const Text('Upload a lecture'),
            ),
          )
        : Column(
            children: [
              for (final lecture in _lectures)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: _loading ? null : () => _loadDetail(lecture.id),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _selectedDetail?.lecture.id == lecture.id
                              ? const Color(0xFF0F766E)
                              : const Color(0xFFE2E8F0),
                          width: _selectedDetail?.lecture.id == lecture.id
                              ? 1.5
                              : 1,
                        ),
                      ),
                      child: _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    lecture.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _StatusPill(label: lecture.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Course: ${lecture.courseName}'),
                            Text(
                              'Updated: ${_prettyDateTime(lecture.updatedAt)}',
                            ),
                            if ((lecture.progressMessage ?? '').isNotEmpty ||
                                lecture.progressPercent > 0) ...[
                              const SizedBox(height: 12),
                              _CompactLectureProgress(lecture: lecture),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
    final detailPanel = _selectedDetail == null
        ? const _EmptyStateCard(
            icon: Icons.auto_stories_outlined,
            title: 'Choose a lecture to inspect',
            body:
                'Select a lecture to open its transcript, summaries, key concepts, and related quizzes.',
          )
        : _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LectureMeta(lecture: _selectedDetail!.lecture),
                const SizedBox(height: 16),
                _StatsRow(
                  children: [
                    _MetricCard(
                      label: 'Quiz count',
                      value: '${_selectedDetail!.quizzes.length}',
                    ),
                    _MetricCard(
                      label: 'Key terms',
                      value: '${_selectedDetail!.lecture.keyTerms.length}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _LectureProgressCard(lecture: _selectedDetail!.lecture),
                const SizedBox(height: 16),
                if (_hasStudyNotes(_selectedDetail!.lecture)) ...[
                  _LectureStudyNotesSection(lecture: _selectedDetail!.lecture),
                  const SizedBox(height: 16),
                ],
                if ((_selectedDetail!.lecture.transcript ?? '').isNotEmpty) ...[
                  const Text(
                    'Transcript',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(_selectedDetail!.lecture.transcript!),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonal(
                      onPressed: () => widget.onSelectFeature(3),
                      child: const Text('Open quizzes'),
                    ),
                    OutlinedButton(
                      onPressed: () => widget.onSelectFeature(4),
                      child: const Text('Build a plan'),
                    ),
                  ],
                ),
              ],
            ),
          );

    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Lecture library',
            subtitle:
                'Open finished lectures and move between transcript, notes, and quizzes without losing context.',
          ),
          _SectionCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.controller.isLoggedIn
                        ? 'Signed in as ${widget.controller.currentUser?.email ?? 'your account'}'
                        : 'Sign in to load your saved lectures.',
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _loading
                      ? null
                      : () => _refreshLectures(
                          preferredLectureId: widget.controller.latestLectureId,
                        ),
                  child: const Text('Refresh library'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],
          if (isWideLayout)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(
                        title: 'Saved lectures',
                        subtitle:
                            'Choose a lecture to open the material generated from it.',
                      ),
                      libraryList,
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(
                        title: 'Lecture detail',
                        subtitle:
                            'Summary, key concepts, transcript, and next actions stay together here.',
                      ),
                      detailPanel,
                    ],
                  ),
                ),
              ],
            )
          else ...[
            libraryList,
            const SizedBox(height: 24),
            const _SectionHeader(
              title: 'Lecture detail',
              subtitle:
                  'Summary, key concepts, transcript, and next actions stay together here.',
            ),
            detailPanel,
          ],
        ],
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.controller,
    required this.onSelectFeature,
  });

  final AppController controller;
  final ValueChanged<int> onSelectFeature;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool _loading = false;
  List<Lecture> _lectures = const [];
  final Set<String> _selectedLectureIds = <String>{};
  final Random _random = Random();
  List<LectureQuiz> _quizPool = const [];
  List<LectureQuiz> _quizzes = const [];
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String> _answers = {};
  String _quizLanguage = 'en';
  bool _showOnlyMissed = false;
  Set<String> _focusedQuizIds = <String>{};
  QuizAttemptResult? _result;

  @override
  void initState() {
    super.initState();
    _quizLanguage = _normalizeQuizLanguage(widget.controller.localeCode);
  }

  @override
  void dispose() {
    _disposeAnswerControllers();
    super.dispose();
  }

  List<LectureQuiz> get _visibleQuizzes {
    if (!_showOnlyMissed || _focusedQuizIds.isEmpty) {
      return _quizzes;
    }
    return _quizzes.where((quiz) => _focusedQuizIds.contains(quiz.id)).toList();
  }

  List<Lecture> get _selectedLectures {
    return _lectures
        .where((lecture) => _selectedLectureIds.contains(lecture.id))
        .toList();
  }

  Map<String, Lecture> get _lectureById {
    return {for (final lecture in _lectures) lecture.id: lecture};
  }

  String? _quizSourceLabel(LectureQuiz quiz) {
    final lecture = _lectureById[quiz.lectureId];
    if (lecture == null) {
      return null;
    }
    return '${lecture.title} · ${lecture.courseName}';
  }

  QuizQuestionResult? _resultForQuiz(String quizId) {
    final result = _result;
    if (result == null) {
      return null;
    }
    for (final questionResult in result.questionResults) {
      if (questionResult.quizId == quizId) {
        return questionResult;
      }
    }
    return null;
  }

  void _disposeAnswerControllers() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
  }

  void _resetQuizAttemptState() {
    _disposeAnswerControllers();
    _answers.clear();
    _result = null;
    _showOnlyMissed = false;
    _focusedQuizIds = <String>{};
  }

  void _resetQuizWorkspace() {
    _resetQuizAttemptState();
    _quizPool = const [];
    _quizzes = const [];
  }

  List<LectureQuiz> _buildQuizSet(List<LectureQuiz> source) {
    final pool = List<LectureQuiz>.of(source);
    pool.shuffle(_random);
    return pool.take(min(10, pool.length)).toList();
  }

  void _applyQuizPool(List<LectureQuiz> quizzes) {
    _resetQuizAttemptState();
    _quizPool = quizzes;
    _quizzes = _buildQuizSet(quizzes);
  }

  String _normalizeQuizLanguage(String? code) {
    final normalized = (code ?? '').trim().toLowerCase();
    if (const {'en', 'ko', 'ru', 'zh'}.contains(normalized)) {
      return normalized;
    }
    return 'en';
  }

  String _quizLanguageLabel(String code) {
    return switch (code) {
      'en' => 'English',
      'ko' => 'Korean',
      'ru' => 'Russian',
      'zh' => 'Chinese',
      _ => code.toUpperCase(),
    };
  }

  QuizLocalization? _localizedQuizContent(
    LectureQuiz quiz, [
    String? preferredLanguage,
  ]) {
    final language = _normalizeQuizLanguage(preferredLanguage ?? _quizLanguage);
    return quiz.localizedContent[language] ?? quiz.localizedContent['en'];
  }

  String _quizQuestionText(LectureQuiz quiz) {
    final localized = _localizedQuizContent(quiz);
    return (localized?.question ?? '').trim().isNotEmpty
        ? localized!.question.trim()
        : quiz.question;
  }

  List<String> _quizOptionTexts(LectureQuiz quiz) {
    final localized = _localizedQuizContent(quiz);
    if (localized != null && localized.options.isNotEmpty) {
      return localized.options;
    }
    return quiz.options;
  }

  String? _quizSkillTagText(LectureQuiz quiz) {
    final localized = _localizedQuizContent(quiz);
    final value = (localized?.skillTag ?? quiz.skillTag ?? '').trim();
    return value.isEmpty ? null : value;
  }

  List<String> _quizConceptRefTexts(LectureQuiz quiz) {
    final localized = _localizedQuizContent(quiz);
    if (localized != null && localized.conceptRefs.isNotEmpty) {
      return localized.conceptRefs;
    }
    return quiz.conceptRefs;
  }

  Future<void> _loadLectures() async {
    if (!widget.controller.isLoggedIn) {
      _showMessage('Login first to access quizzes.');
      return;
    }
    setState(() => _loading = true);
    try {
      final lectures = await widget.controller.api.listLectures();
      if (!mounted) {
        return;
      }
      setState(() {
        _lectures = lectures
            .where((lecture) => lecture.status == 'ready')
            .toList();
        if (_lectures.isEmpty) {
          _resetQuizWorkspace();
        } else {
          if (_selectedLectureIds.isEmpty) {
            _selectedLectureIds.add(_lectures.first.id);
          } else {
            _selectedLectureIds.removeWhere(
              (lectureId) => !_lectures.any((lecture) => lecture.id == lectureId),
            );
            if (_selectedLectureIds.isEmpty && _lectures.isNotEmpty) {
              _selectedLectureIds.add(_lectures.first.id);
            }
          }
        }
        _resetQuizWorkspace();
      });
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _toggleLectureSelection(String lectureId, bool selected) {
    setState(() {
      if (selected) {
        _selectedLectureIds.add(lectureId);
      } else {
        _selectedLectureIds.remove(lectureId);
      }
      _resetQuizWorkspace();
    });
  }

  Future<void> _loadQuizzes({bool regenerate = false}) async {
    if (_selectedLectureIds.isEmpty) {
      _showMessage('Choose at least one ready lecture first.');
      return;
    }
    setState(() => _loading = true);
    try {
      final lectureIds = _selectedLectureIds.toList();
      final quizzes = regenerate
          ? await widget.controller.api.regenerateLectureQuizzes(
              lectureIds: lectureIds,
              questionCount: 10,
            )
          : (await Future.wait(
              lectureIds.map(widget.controller.api.listLectureQuizzes),
            ))
                .expand((items) => items)
                .toList();
      if (!mounted) {
        return;
      }
      final deduped = <String, LectureQuiz>{};
      for (final quiz in quizzes) {
        deduped[quiz.id] = quiz;
      }
      setState(() {
        _applyQuizPool(deduped.values.toList());
      });
      _showMessage(
        regenerate
            ? 'A fresh 10-question quiz set is ready.'
            : 'Quiz set loaded.',
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _createNewQuizSet() {
    if (_quizPool.isEmpty) {
      _showMessage('Load quizzes first.');
      return;
    }
    setState(() {
      _resetQuizAttemptState();
      _quizzes = _buildQuizSet(_quizPool);
    });
    _showMessage('A new 10-question quiz set is ready.');
  }

  QuizAttemptResult _mergeQuizResults(
    List<QuizAttemptResult> results,
    List<LectureQuiz> gradedQuizzes,
  ) {
    final order = <String, int>{};
    for (var index = 0; index < gradedQuizzes.length; index += 1) {
      order[gradedQuizzes[index].id] = index;
    }

    var correct = 0;
    var total = 0;
    final questionResults = <QuizQuestionResult>[];
    final weakConceptCounts = <String, int>{};
    final weakConceptHints = <String, String>{};
    final recommendedActions = <String>{};
    final attemptIds = <String>[];

    for (final result in results) {
      if (result.attemptId.isNotEmpty) {
        attemptIds.add(result.attemptId);
      }
      correct += result.correct;
      total += result.total;
      questionResults.addAll(result.questionResults);
      for (final concept in result.weakConcepts) {
        final label = concept.label.trim();
        if (label.isEmpty) {
          continue;
        }
        weakConceptCounts[label] =
            (weakConceptCounts[label] ?? 0) + concept.misses;
        final hint = (concept.reviewHint ?? '').trim();
        if (hint.isNotEmpty && !weakConceptHints.containsKey(label)) {
          weakConceptHints[label] = hint;
        }
      }
      recommendedActions.addAll(
        result.recommendedActions
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty),
      );
    }

    questionResults.sort(
      (left, right) =>
          (order[left.quizId] ?? 9999).compareTo(order[right.quizId] ?? 9999),
    );
    final weakConcepts = weakConceptCounts.entries
        .map(
          (entry) => WeakConcept(
            label: entry.key,
            misses: entry.value,
            reviewHint: weakConceptHints[entry.key],
          ),
        )
        .toList()
      ..sort((left, right) {
        final misses = right.misses.compareTo(left.misses);
        if (misses != 0) {
          return misses;
        }
        return left.label.toLowerCase().compareTo(right.label.toLowerCase());
      });

    return QuizAttemptResult(
      attemptId: attemptIds.join(','),
      correct: correct,
      total: total,
      score: total == 0 ? 0 : ((correct / total) * 100).round(),
      mode: 'practice',
      language: _quizLanguage,
      questionResults: questionResults,
      weakConcepts: weakConcepts,
      recommendedActions: recommendedActions.toList(),
    );
  }

  Future<void> _submitAnswers() async {
    if (_selectedLectureIds.isEmpty) {
      _showMessage('Choose at least one lecture first.');
      return;
    }
    if (_quizzes.isEmpty) {
      _showMessage('Load quizzes first.');
      return;
    }
    final unanswered = _visibleQuizzes
        .where((quiz) => (_answers[quiz.id] ?? '').trim().isEmpty)
        .length;
    if (unanswered > 0) {
      _showMessage('Answer the remaining $unanswered question(s) before submitting.');
      return;
    }
    setState(() => _loading = true);
    try {
      final groupedQuizzes = <String, List<LectureQuiz>>{};
      for (final quiz in _visibleQuizzes) {
        groupedQuizzes.putIfAbsent(quiz.lectureId, () => <LectureQuiz>[]).add(quiz);
      }
      final results = await Future.wait(
        groupedQuizzes.entries.map(
          (entry) => widget.controller.api.submitQuizAnswers(
            lectureId: entry.key,
            answers: {
              for (final quiz in entry.value)
                quiz.id: (_answers[quiz.id] ?? '').trim(),
            },
            quizIds: entry.value.map((quiz) => quiz.id).toList(),
            mode: 'practice',
            language: _quizLanguage,
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = _mergeQuizResults(results, _visibleQuizzes);
        _showOnlyMissed = false;
        _focusedQuizIds = <String>{};
      });
      _showMessage('Guided review is ready.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  TextEditingController _controllerForQuiz(String quizId) {
    return _textControllers.putIfAbsent(quizId, TextEditingController.new);
  }

  void _retryMissedQuestions() {
    final result = _result;
    if (result == null) {
      return;
    }
    final missedIds = result.questionResults
        .where((item) => !item.isCorrect)
        .map((item) => item.quizId)
        .toSet();
    if (missedIds.isEmpty) {
      _showMessage('There are no missed questions to retry.');
      return;
    }
    for (final quizId in missedIds) {
      _answers.remove(quizId);
      _textControllers[quizId]?.clear();
    }
    setState(() {
      _result = null;
      _showOnlyMissed = true;
      _focusedQuizIds = missedIds;
    });
    _showMessage('The next review set is focused on the questions you missed.');
  }

  void _showAllQuestions() {
    setState(() {
      _showOnlyMissed = false;
      _focusedQuizIds = <String>{};
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Review quiz',
            subtitle:
                'Build a focused 10-question review set from one or more finished lectures.',
          ),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BannerCard(
                  icon: Icons.quiz_outlined,
                  title: 'Build a quiz from your saved lectures',
                  body:
                      'Choose finished lectures, pull in their saved question pool, and create a fresh 10-question set whenever you want a new round.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 220,
                      child: FilledButton(
                        onPressed: _loading ? null : _loadLectures,
                        child: const Text('Refresh lectures'),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: OutlinedButton(
                        onPressed: _loading ? null : () => _loadQuizzes(),
                        child: const Text('Use saved questions'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () => _loadQuizzes(regenerate: true),
                        child: const Text('Make fresh questions'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Choose lectures',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                if (_lectures.isEmpty)
                  const Text(
                    'Refresh your ready lectures first, then choose the ones you want in this quiz.',
                    style: TextStyle(color: Color(0xFF475569), height: 1.45),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _lectures
                        .map(
                          (lecture) => FilterChip(
                            label: Text('${lecture.title} · ${lecture.courseName}'),
                            selected: _selectedLectureIds.contains(lecture.id),
                            onSelected: _loading
                                ? null
                                : (selected) =>
                                      _toggleLectureSelection(lecture.id, selected),
                          ),
                        )
                        .toList(),
                  ),
                if (_selectedLectureIds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${_selectedLectureIds.length} lecture${_selectedLectureIds.length == 1 ? '' : 's'} selected. StudyService will mix their saved questions into one 10-question review set.',
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _quizLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Quiz language',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'ko', child: Text('Korean')),
                    DropdownMenuItem(value: 'ru', child: Text('Russian')),
                    DropdownMenuItem(value: 'zh', child: Text('Chinese')),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _quizLanguage = _normalizeQuizLanguage(value);
                            _resetQuizWorkspace();
                          });
                        },
                ),
                const SizedBox(height: 10),
                Text(
                  'Questions, answer choices, and feedback will follow the language selected here.',
                  style: const TextStyle(color: Color(0xFF475569), height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],
          if (_lectures.isEmpty)
            _EmptyStateCard(
              icon: Icons.fact_check_outlined,
              title: 'No ready lectures to quiz yet',
              body:
                  'Upload and finish a lecture first. Once it is ready, you can turn it into a quiz set here.',
              action: FilledButton.tonal(
                onPressed: () => widget.onSelectFeature(1),
                child: const Text('Upload a lecture'),
              ),
            )
          else if (_quizzes.isEmpty)
            const _EmptyStateCard(
              icon: Icons.rule_folder_outlined,
              title: 'Load or create a quiz set to begin',
              body:
                  'Choose one or more ready lectures above, then use saved questions or make a fresh 10-question set.',
            )
          else ...[
            const SizedBox(height: 8),
            if (_selectedLectures.isNotEmpty) ...[
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Built from lectures',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedLectures
                          .map(
                            (lecture) => _QuizConceptChip(
                              label: '${lecture.title} - ${lecture.courseName}',
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    _StatsRow(
                      children: [
                        _MetricCard(
                          label: 'Lectures selected',
                          value: '${_selectedLectures.length}',
                        ),
                        _MetricCard(
                          label: 'Questions in set',
                          value: '${_quizzes.length}',
                        ),
                        _MetricCard(
                          label: 'Quiz language',
                          value: _quizLanguageLabel(_quizLanguage),
                        ),
                        _MetricCard(
                          label: 'Pool size',
                          value: '${_quizPool.length}',
                        ),
                        _MetricCard(
                          label: 'Current view',
                          value: _showOnlyMissed && _focusedQuizIds.isNotEmpty
                              ? 'Missed only'
                              : '10-question set',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_showOnlyMissed && _focusedQuizIds.isNotEmpty) ...[
              _SectionCard(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'You are retrying only the questions missed on the previous attempt.',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _showAllQuestions,
                      child: const Text('Show all questions'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            ..._visibleQuizzes.asMap().entries.map((entry) {
              final index = entry.key;
              final quiz = entry.value;
              final questionResult = _resultForQuiz(quiz.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Question ${index + 1}',
                              style: const TextStyle(
                                color: Color(0xFF0F766E),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (questionResult != null)
                            _StatusPill(
                              label: questionResult.isCorrect
                                  ? 'correct'
                                  : 'needs review',
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _QuizMetaChip(label: _quizKindLabel(quiz.type)),
                          _QuizMetaChip(
                            label:
                                'Difficulty: ${_quizDifficultyLabel(quiz.difficulty)}',
                          ),
                          if ((_quizSkillTagText(quiz) ?? '').trim().isNotEmpty)
                            _QuizMetaChip(label: _quizSkillTagText(quiz)!),
                          if ((_quizSourceLabel(quiz) ?? '').trim().isNotEmpty)
                            _QuizMetaChip(label: _quizSourceLabel(quiz)!),
                        ],
                      ),
                      if (_quizConceptRefTexts(quiz).isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _quizConceptRefTexts(quiz)
                              .map((concept) => _QuizConceptChip(label: concept))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _quizQuestionText(quiz),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Language: ${_quizLanguageLabel(_quizLanguage)}',
                      ),
                      const SizedBox(height: 12),
                      if (_quizOptionTexts(quiz).isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _answers[quiz.id],
                          decoration: const InputDecoration(
                            labelText: 'Choose an answer',
                          ),
                          items: _quizOptionTexts(quiz)
                              .map(
                                (option) => DropdownMenuItem<String>(
                                  value: option,
                                  child: Text(option),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              if (value == null) {
                                _answers.remove(quiz.id);
                              } else {
                                _answers[quiz.id] = value;
                              }
                            });
                          },
                        )
                      else
                        TextField(
                          controller: _controllerForQuiz(quiz.id),
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Your answer',
                          ),
                          onChanged: (value) =>
                              _answers[quiz.id] = value.trim(),
                        ),
                      if (questionResult != null) ...[
                        const SizedBox(height: 12),
                        _QuizFeedbackPanel(
                          result: questionResult,
                          mode: _result!.mode,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: _loading ? null : _submitAnswers,
                  child: const Text('Submit guided review'),
                ),
                OutlinedButton(
                  onPressed: _loading ? null : _createNewQuizSet,
                  child: const Text('Create new quiz set'),
                ),
                OutlinedButton(
                  onPressed: _loading ? null : () => _loadQuizzes(),
                  child: const Text('Reload quiz pool'),
                ),
              ],
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 24),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attempt result',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _StatsRow(
                    children: [
                      _MetricCard(
                        label: 'Correct answers',
                        value: '${_result!.correct}/${_result!.total}',
                      ),
                      _MetricCard(label: 'Score', value: '${_result!.score}%'),
                      _MetricCard(
                        label: 'Language',
                        value: _quizLanguageLabel(_result!.language),
                      ),
                      _MetricCard(
                        label: 'Lectures used',
                        value: '${_selectedLectureIds.length}',
                      ),
                    ],
                  ),
                  if (_result!.weakConcepts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Weak concepts to revisit',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    ..._result!.weakConcepts.map(
                      (concept) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                concept.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Missed in ${concept.misses} question(s)',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                ),
                              ),
                              if ((concept.reviewHint ?? '').trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    concept.reviewHint!.trim(),
                                    style: const TextStyle(height: 1.45),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_result!.recommendedActions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Recommended next actions',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    ..._result!.recommendedActions.map(_BulletLine.new),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (_result!.correct < _result!.total)
                        FilledButton.tonal(
                          onPressed: _retryMissedQuestions,
                          child: const Text('Retry missed questions'),
                        ),
                      FilledButton.tonal(
                        onPressed: _createNewQuizSet,
                        child: const Text('Start a fresh attempt'),
                      ),
                      if (_showOnlyMissed && _focusedQuizIds.isNotEmpty)
                        OutlinedButton(
                          onPressed: _showAllQuestions,
                          child: const Text('Show full quiz set'),
                        ),
                      OutlinedButton(
                        onPressed: () => widget.onSelectFeature(4),
                        child: const Text('Build a plan'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _quizKindLabel(String type) {
    return switch (type) {
      'multiple_choice' => 'Multiple choice',
      'short_answer' => 'Short answer',
      'blank' => 'Fill in the blank',
      _ => type.replaceAll('_', ' ').trim(),
    };
  }

  String _quizDifficultyLabel(String difficulty) {
    return switch (difficulty) {
      'easy' => 'Easy',
      'medium' => 'Medium',
      'hard' => 'Hard',
      _ => difficulty,
    };
  }
}

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _scopeController = TextEditingController();
  bool _loading = false;
  bool _loadingLectures = false;
  DateTime? _examDate;
  DateTime? _startDate;
  late String _language;
  int _studyDaysPerWeek = 5;
  int _sessionMinutes = 90;
  List<Lecture> _availableLectures = const [];
  final Set<String> _selectedLectureIds = <String>{};
  StudyPlanResult? _result;

  @override
  void initState() {
    super.initState();
    final localeCode = widget.controller.localeCode.toLowerCase();
    _language = switch (localeCode) {
      'ko' || 'ru' || 'zh' || 'en' => localeCode,
      _ => 'en',
    };
    if (widget.controller.isLoggedIn) {
      unawaited(_loadLectures());
    }
  }

  @override
  void dispose() {
    _courseController.dispose();
    _scopeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  Future<void> _submit() async {
    if (_selectedLectureIds.isEmpty && _courseController.text.trim().isEmpty) {
      _showMessage('Enter the course you are preparing for.');
      return;
    }
    if (_selectedLectureIds.isEmpty && _scopeController.text.trim().isEmpty) {
      _showMessage('Describe the scope you need to cover.');
      return;
    }
    if (_examDate == null) {
      _showMessage('Pick an exam date.');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await widget.controller.api.createStudyPlan(
        course: _courseController.text.trim(),
        examDate: _dateOnly(_examDate!),
        scope: _scopeController.text.trim(),
        startDate: _startDate == null ? null : _dateOnly(_startDate!),
        language: _language,
        studyDaysPerWeek: _studyDaysPerWeek,
        sessionMinutes: _sessionMinutes,
        lectureIds: _selectedLectureIds.toList(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
      });
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadLectures() async {
    if (!widget.controller.isLoggedIn) {
      return;
    }
    setState(() => _loadingLectures = true);
    try {
      final lectures = await widget.controller.api.listLectures();
      if (!mounted) {
        return;
      }
      setState(() {
        _availableLectures = lectures
            .where((lecture) => lecture.status == 'ready')
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _selectedLectureIds.removeWhere(
          (lectureId) => !_availableLectures.any((lecture) => lecture.id == lectureId),
        );
      });
      _syncPlannerContextFromSelection();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingLectures = false);
      }
    }
  }

  void _toggleLectureSelection(String lectureId, bool selected) {
    setState(() {
      if (selected) {
        _selectedLectureIds.add(lectureId);
      } else {
        _selectedLectureIds.remove(lectureId);
      }
    });
    _syncPlannerContextFromSelection();
  }

  void _syncPlannerContextFromSelection() {
    if (_selectedLectureIds.isEmpty) {
      return;
    }
    final selectedLectures = _availableLectures
        .where((lecture) => _selectedLectureIds.contains(lecture.id))
        .toList();
    if (selectedLectures.isEmpty) {
      return;
    }

    final courseNames = <String>[];
    final scopeParts = <String>[];
    for (final lecture in selectedLectures) {
      if (!courseNames.contains(lecture.courseName) &&
          lecture.courseName.trim().isNotEmpty) {
        courseNames.add(lecture.courseName.trim());
      }
      if (lecture.title.trim().isNotEmpty) {
        scopeParts.add(lecture.title.trim());
      }
      for (final term in lecture.keyTerms.take(3)) {
        if (term.term.trim().isNotEmpty) {
          scopeParts.add(term.term.trim());
        }
      }
    }

    final nextCourse = courseNames.isEmpty
        ? _courseController.text.trim()
        : courseNames.length == 1
        ? courseNames.first
        : courseNames.take(3).join(' / ');
    final dedupedScope = <String>[];
    for (final part in scopeParts) {
      if (!dedupedScope.contains(part)) {
        dedupedScope.add(part);
      }
    }
    final nextScope = dedupedScope.take(8).join(', ');

    if (nextCourse.isNotEmpty) {
      _courseController.text = nextCourse;
    }
    if (nextScope.isNotEmpty) {
      _scopeController.text = nextScope;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Study planner',
            subtitle:
                'Turn your exam window and lecture library into a realistic plan you can actually follow.',
          ),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BannerCard(
                  icon: Icons.event_note_outlined,
                  title: 'Build a plan around real lecture material',
                  body:
                      'Set the course, scope, workload, and target language. StudyService will shape that into a schedule with checkpoints, review goals, and daily missions.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _courseController,
                  decoration: const InputDecoration(
                    labelText: 'Course',
                    hintText: 'Example: Computer Architecture',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _scopeController,
                  decoration: const InputDecoration(
                    labelText: 'Scope',
                    hintText:
                        'Example: chapter 1 ~ 6, IEEE 754, addressing modes, MIPS registers',
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                if (widget.controller.isLoggedIn) ...[
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Use saved lectures as the planning source',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadingLectures ? null : _loadLectures,
                        child: Text(
                          _loadingLectures ? 'Loading...' : 'Refresh lectures',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_availableLectures.isEmpty)
                    const _InfoBlock(
                      title: 'No ready lectures yet',
                      body:
                          'Upload and finish processing lectures first, then you can select one or more of them to build a plan from their content.',
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _availableLectures.map((lecture) {
                        final selected = _selectedLectureIds.contains(lecture.id);
                        return FilterChip(
                          selected: selected,
                          label: Text('${lecture.title} · ${lecture.courseName}'),
                          onSelected: (value) =>
                              _toggleLectureSelection(lecture.id, value),
                        );
                      }).toList(),
                    ),
                  if (_selectedLectureIds.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${_selectedLectureIds.length} lecture${_selectedLectureIds.length == 1 ? '' : 's'} selected. StudyService will use their summaries, key terms, and weak quiz areas when it builds the plan.',
                      style: const TextStyle(color: Color(0xFF475569)),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  decoration: const InputDecoration(
                    labelText: 'Output language',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'ko', child: Text('Korean')),
                    DropdownMenuItem(value: 'ru', child: Text('Russian')),
                    DropdownMenuItem(value: 'zh', child: Text('Chinese')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _language = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _studyDaysPerWeek,
                        decoration: const InputDecoration(
                          labelText: 'Study days per week',
                        ),
                        items: List.generate(
                          7,
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text('${index + 1} day${index == 0 ? '' : 's'}'),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _studyDaysPerWeek = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _sessionMinutes,
                        decoration: const InputDecoration(
                          labelText: 'Session length',
                        ),
                        items: const [
                          DropdownMenuItem(value: 45, child: Text('45 min')),
                          DropdownMenuItem(value: 60, child: Text('60 min')),
                          DropdownMenuItem(value: 90, child: Text('90 min')),
                          DropdownMenuItem(value: 120, child: Text('120 min')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _sessionMinutes = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () => _pickDate(
                                current: _startDate,
                                onSelected: (value) =>
                                    setState(() => _startDate = value),
                              ),
                        child: Text(
                          _startDate == null
                              ? 'Pick start date'
                              : 'Start: ${_dateOnly(_startDate!)}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: _loading
                            ? null
                            : () => _pickDate(
                                current: _examDate,
                                onSelected: (value) =>
                                    setState(() => _examDate = value),
                              ),
                        child: Text(
                          _examDate == null
                              ? 'Pick exam date'
                              : 'Exam: ${_dateOnly(_examDate!)}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(_loading ? 'Building...' : 'Build plan'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],
          if (_result == null)
            const _EmptyStateCard(
              icon: Icons.calendar_month_outlined,
              title: 'Your study plan will appear here',
              body:
                  'Once ready, your plan will show the rhythm, checkpoints, and daily study blocks you can follow day by day.',
            )
          else ...[
            const SizedBox(height: 8),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_result!.course} · Exam ${_result!.examDate}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(_result!.overview),
                  const SizedBox(height: 12),
                  Text(
                    _result!.scope,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  if (_result!.selectedLectureTitles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Built from lectures',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _result!.selectedLectureTitles
                          .map((title) => _QuizConceptChip(label: title))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _StatsRow(
                    children: [
                      _MetricCard(
                        label: 'Timeline',
                        value: '${_result!.startDate} -> ${_result!.examDate}',
                      ),
                      _MetricCard(
                        label: 'Study blocks',
                        value: '${_result!.studyDays}',
                      ),
                      _MetricCard(
                        label: 'Session length',
                        value: '${_result!.dailyMinutes} min',
                      ),
                      _MetricCard(
                        label: 'Language',
                        value: _languageLabel(_result!.language),
                      ),
                    ],
                  ),
                  if ((_result!.personalizationNote ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _BannerCard(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Planning note',
                      body: _result!.personalizationNote!,
                    ),
                  ],
                  if (_result!.weakConcepts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Areas to watch',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _result!.weakConcepts
                          .map((concept) => _QuizConceptChip(label: concept))
                          .toList(),
                    ),
                  ],
                  if (_result!.checkpoints.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Checkpoints',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    ..._result!.checkpoints.map(
                      (checkpoint) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Icon(
                                Icons.adjust_rounded,
                                size: 14,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(checkpoint)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ..._result!.plan.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PlannerDayCard(item: item),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MailTranslateScreen extends StatefulWidget {
  const MailTranslateScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<MailTranslateScreen> createState() => _MailTranslateScreenState();
}

class _MailTranslateScreenState extends State<MailTranslateScreen> {
  final TextEditingController _textController = TextEditingController();
  final Set<String> _languages = {'zh', 'ko', 'ru'};
  bool _loading = false;
  Map<String, String> _translations = const {};

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final translations = await widget.controller.api.translateEmail(
        text: _textController.text.trim(),
        languages: _languages.toList(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _translations = translations;
      });
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Email translation',
            subtitle:
                'Translate email drafts into the languages your users or classmates actually need.',
          ),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BannerCard(
                  icon: Icons.translate_outlined,
                  title: 'Translate one message into multiple languages',
                  body:
                      'Paste the source email once, pick the target languages, and keep every translated version together below.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _textController,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(labelText: 'Email text'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ['zh', 'ko', 'ru']
                      .map(
                        (language) => FilterChip(
                          label: Text(_languageLabel(language)),
                          selected: _languages.contains(language),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _languages.add(language);
                              } else if (_languages.length > 1) {
                                _languages.remove(language);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(_loading ? 'Translating...' : 'Translate'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],
          if (_translations.isEmpty)
            const _EmptyStateCard(
              icon: Icons.mark_email_read_outlined,
              title: 'Translated versions will appear here',
              body:
                  'After translation, each selected language will be shown in its own card so you can review the message quickly.',
            )
          else ...[
            const SizedBox(height: 24),
            ..._translations.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SectionCard(
                  child: _InfoBlock(
                    title: _languageLabel(entry.key),
                    body: entry.value,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SolverScreen extends StatefulWidget {
  const SolverScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SolverScreen> createState() => _SolverScreenState();
}

class _SolverScreenState extends State<SolverScreen> {
  final TextEditingController _problemController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  bool _loading = false;
  String _problemType = 'auto';
  SolveSessionState? _session;

  @override
  void dispose() {
    _problemController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() => _loading = true);
    try {
      final session = await widget.controller.api.createSolveSession(
        problem: _problemController.text.trim(),
        problemType: _problemType,
        language: widget.controller.localeCode,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _session = session;
      });
      _answerController.clear();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshSession() async {
    final sessionId = _session?.sessionId;
    if (sessionId == null) {
      return;
    }
    setState(() => _loading = true);
    try {
      final session = await widget.controller.api.getSolveSession(sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _session = session;
      });
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitAnswer() async {
    final sessionId = _session?.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      _showMessage('Start a session first.');
      return;
    }
    setState(() => _loading = true);
    try {
      final session = await widget.controller.api.submitSolveAnswer(
        sessionId: sessionId,
        answer: _answerController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _session = session;
      });
      _answerController.clear();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Guided problem solving',
            subtitle:
                'Work through a problem step by step with prompts, hints, and feedback that stay in one place.',
          ),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BannerCard(
                  icon: Icons.psychology_outlined,
                  title: 'Open a guided solving session',
                  body:
                      'Paste the full problem statement, choose the closest problem type, and let the assistant walk the learner through each step.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _problemController,
                  minLines: 5,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Problem statement',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _problemType,
                  decoration: const InputDecoration(labelText: 'Problem type'),
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('auto')),
                    DropdownMenuItem(value: 'math', child: Text('math')),
                    DropdownMenuItem(value: 'coding', child: Text('coding')),
                    DropdownMenuItem(value: 'theory', child: Text('theory')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _problemType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _loading ? null : _startSession,
                        child: Text(_loading ? 'Starting...' : 'Start session'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loading ? null : _refreshSession,
                        child: const Text('Refresh state'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],
          if (_session == null)
            const _EmptyStateCard(
              icon: Icons.route_outlined,
              title: 'The guided session will appear here',
              body:
                  'Once you start, the current step, prompt, feedback, and hints will stay in this panel until the problem is complete.',
            )
          else ...[
            const SizedBox(height: 24),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _session!.stepTitle ?? 'Session state',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StatsRow(
                    children: [
                      _MetricCard(
                        label: 'Current step',
                        value:
                            '${_session!.stepIndex + (_session!.isFinished ? 0 : 1)} / ${_session!.totalSteps}',
                      ),
                      _MetricCard(
                        label: 'Attempts',
                        value: '${_session!.attempts}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(_session!.prompt),
                  if ((_session!.feedback ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _InfoBlock(title: 'Feedback', body: _session!.feedback!),
                  ],
                  if ((_session!.hint ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _InfoBlock(title: 'Hint', body: _session!.hint!),
                  ],
                  if (!_session!.isFinished) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _answerController,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Your answer for this step',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: _loading ? null : _submitAnswer,
                      child: const Text('Submit step answer'),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    const _InfoBlock(
                      title: 'Session complete',
                      body:
                          'You reached the end of this guided solution. Start a new session anytime with another problem.',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.onSelectFeature, required this.isLoggedIn});

  final ValueChanged<int> onSelectFeature;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    final isWideLayout = MediaQuery.sizeOf(context).width >= 900;
    final summaryCards = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: const [
        _HeroStatCard(label: 'Summaries', value: '4 languages'),
        _HeroStatCard(label: 'Quiz rounds', value: '10 questions'),
        _HeroStatCard(label: 'Study plans', value: 'Lecture-based'),
      ],
    );
    final shortcuts = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _FeatureShortcutCard(
          icon: Icons.upload_file_outlined,
          title: 'Add a lecture',
          description:
              'Bring in a recording and let StudyService turn it into notes and review material.',
          onPressed: () => onSelectFeature(1),
        ),
        _FeatureShortcutCard(
          icon: Icons.menu_book_outlined,
          title: 'Open your library',
          description:
              'Browse transcripts, key concepts, and lecture summaries in one place.',
          onPressed: () => onSelectFeature(2),
        ),
        _FeatureShortcutCard(
          icon: Icons.event_note_outlined,
          title: 'Build a study plan',
          description:
              'Turn saved lectures into a realistic revision plan you can actually follow.',
          onPressed: () => onSelectFeature(4),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF134E4A), Color(0xFF0F766E)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260F172A),
            blurRadius: 32,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: isWideLayout
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _HeroPanelCopy(isLoggedIn: isLoggedIn)),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      summaryCards,
                      const SizedBox(height: 18),
                      shortcuts,
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroPanelCopy(isLoggedIn: isLoggedIn),
                const SizedBox(height: 18),
                summaryCards,
                const SizedBox(height: 18),
                shortcuts,
              ],
            ),
    );
  }
}

class _HeroPanelCopy extends StatelessWidget {
  const _HeroPanelCopy({required this.isLoggedIn});

  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LaunchBadge(label: 'Built for real study sessions'),
        const SizedBox(height: 16),
        const Text(
          'Turn lecture recordings into study material you can actually use.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Upload a lecture once, then move through summaries, keyword notes, quizzes, and study plans without hopping between tools.',
          style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 15, height: 1.6),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _OutlineChip(
              label: isLoggedIn
                  ? 'Signed in and ready to save progress'
                  : 'Sign in when you want to keep your library',
            ),
            const _OutlineChip(
              label: 'Summaries, quizzes, and plans stay connected',
            ),
            const _OutlineChip(
              label: 'Works comfortably on desktop and tablet',
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroStatCard extends StatelessWidget {
  const _HeroStatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureShortcutCard extends StatelessWidget {
  const _FeatureShortcutCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(color: Color(0xFFE2E8F0), height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineChip extends StatelessWidget {
  const _OutlineChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12.5),
      ),
    );
  }
}

class _SidebarAccountCard extends StatelessWidget {
  const _SidebarAccountCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            controller.currentUser?.email ??
                'Sign in to keep your lectures and progress in one place.',
            style: const TextStyle(color: Color(0xFF475569), height: 1.45),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniTag(
                label: controller.isLoggedIn ? 'Signed in' : 'Guest',
                tint: controller.isLoggedIn
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF64748B),
              ),
              _MiniTag(
                label: controller.localeCode.toUpperCase(),
                tint: const Color(0xFF2563EB),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountSnapshotCard extends StatelessWidget {
  const _AccountSnapshotCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your account at a glance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            controller.currentUser?.email ?? 'No account connected yet.',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            controller.isLoggedIn
                ? 'Uploads, lecture notes, quizzes, and plans will stay attached to this account.'
                : 'Create an account or sign in when you want your study library to persist between sessions.',
            style: const TextStyle(color: Color(0xFF475569), height: 1.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniTag(
                label: controller.isLoggedIn ? 'Ready to save progress' : 'Guest',
                tint: controller.isLoggedIn
                    ? const Color(0xFF0F766E)
                    : const Color(0xFFB45309),
              ),
              _MiniTag(
                label: 'Language ${controller.localeCode.toUpperCase()}',
                tint: const Color(0xFF2563EB),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStartCard extends StatelessWidget {
  const _QuickStartCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'A simple way to begin',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12),
          _ChecklistLine(
            step: '1',
            title: 'Connect once',
            body: 'Keep the default API URL unless your backend lives on another machine.',
          ),
          SizedBox(height: 12),
          _ChecklistLine(
            step: '2',
            title: 'Sign in',
            body: 'Use one account so every lecture, quiz result, and study plan stays together.',
          ),
          SizedBox(height: 12),
          _ChecklistLine(
            step: '3',
            title: 'Start with one lecture',
            body: 'Upload a recording first, then move into summaries, quizzes, and planning from there.',
          ),
        ],
      ),
    );
  }
}

class _ChecklistLine extends StatelessWidget {
  const _ChecklistLine({
    required this.step,
    required this.title,
    required this.body,
  });

  final String step;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFE6FFFA),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: Color(0xFF0F766E),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(color: Color(0xFF475569), height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: Icon(Icons.circle, size: 8, color: Color(0xFF0F766E)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF334155), height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _LaunchBadge extends StatelessWidget {
  const _LaunchBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFCCFBF1).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAFBF7), Color(0xFFF7FAFC), Color(0xFFEFFBFF)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1360),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    );
  }
}

class _UserSummary extends StatelessWidget {
  const _UserSummary({required this.user, required this.isLoggedIn});

  final UserProfile? user;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'No account connected yet. You can still browse the interface, but your study library will not be saved until you sign in.',
          style: TextStyle(color: Color(0xFF475569), height: 1.5),
        ),
      );
    }
    if (user == null) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'You are signed in, and your account details are still syncing.',
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user!.email,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            user!.isActive
                ? 'Your account is active and ready to save lectures, quizzes, and plans.'
                : 'Your account is signed in, but it still needs to be activated.',
            style: const TextStyle(color: Color(0xFF475569), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'ready' => const Color(0xFF047857),
      'failed' => const Color(0xFFB91C1C),
      'correct' => const Color(0xFF047857),
      'needs review' => const Color(0xFFB45309),
      _ => const Color(0xFF475569),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _HeaderStatusChip extends StatelessWidget {
  const _HeaderStatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFCCFBF1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0F766E)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF134E4A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.label,
    this.tint = const Color(0xFF0F766E),
  });

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: TextStyle(color: tint, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: const Color(0xFF0F766E)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF475569), height: 1.5),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 12, runSpacing: 12, children: children);
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.tint = const Color(0xFF0F766E),
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 156),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6FFFC), Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDEAEF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE6FFFA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF0F766E)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    height: 1.45,
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

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SelectableText(body),
          ],
        ),
      ),
    );
  }
}

class _PlannerDayCard extends StatelessWidget {
  const _PlannerDayCard({required this.item});

  final StudyPlanItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  item.date,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                _QuizMetaChip(label: item.phase),
                _QuizMetaChip(label: item.title),
                _QuizConceptChip(
                  label:
                      '${_plannerEffortLabel(item.effort)} · ${item.sessionMinutes} min',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.mission,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.task,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            if ((item.focusBoost ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Text(
                  item.focusBoost!,
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _InfoBlock(title: 'Focus', body: item.focus),
            const SizedBox(height: 10),
            _InfoBlock(title: 'Review goal', body: item.review),
            const SizedBox(height: 10),
            _InfoBlock(title: 'Expected output', body: item.expectedOutput),
            const SizedBox(height: 10),
            _InfoBlock(title: 'Why now', body: item.whyThisMatters),
          ],
        ),
      ),
    );
  }
}

class _QuizMetaChip extends StatelessWidget {
  const _QuizMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFCCFBF1)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF134E4A),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _QuizConceptChip extends StatelessWidget {
  const _QuizConceptChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF334155),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _QuizFeedbackPanel extends StatelessWidget {
  const _QuizFeedbackPanel({required this.result, required this.mode});

  final QuizQuestionResult result;
  final String mode;

  @override
  Widget build(BuildContext context) {
    final accentColor = result.isCorrect
        ? const Color(0xFF047857)
        : const Color(0xFFB45309);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.isCorrect ? 'Answer review' : 'Review this answer',
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _FeedbackRow(
            label: 'Your answer',
            value: result.submittedAnswer.trim().isEmpty
                ? 'No answer submitted'
                : result.submittedAnswer.trim(),
          ),
          const SizedBox(height: 8),
          _FeedbackRow(label: 'Correct answer', value: result.correctAnswer),
          const SizedBox(height: 10),
          Text(
            result.explanation,
            style: const TextStyle(height: 1.45),
          ),
          if ((result.reviewHint ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _FeedbackRow(
              label: mode == 'practice' ? 'Review hint' : 'Suggested review',
              value: result.reviewHint!.trim(),
            ),
          ],
          if (result.conceptRefs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.conceptRefs
                  .map((concept) => _QuizConceptChip(label: concept))
                  .toList(),
            ),
          ],
          if ((result.followUpPrompt ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _FeedbackRow(
              label: 'Next step',
              value: result.followUpPrompt!.trim(),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(value),
      ],
    );
  }
}

bool _hasStudyNotes(Lecture lecture) {
  return _summaryTranslationsForLecture(lecture).isNotEmpty ||
      lecture.keyTerms.isNotEmpty;
}

Map<String, String> _summaryTranslationsForLecture(Lecture lecture) {
  final translations = <String, String>{};
  for (final entry in lecture.summaryTranslations.entries) {
    final value = entry.value.trim();
    if (value.isNotEmpty) {
      translations[entry.key] = value;
    }
  }
  final legacyOriginal = (lecture.summaryOriginal ?? '').trim();
  if (legacyOriginal.isNotEmpty) {
    translations.putIfAbsent('en', () => legacyOriginal);
  }
  final legacyRussian = (lecture.summaryRussian ?? '').trim();
  if (legacyRussian.isNotEmpty) {
    translations.putIfAbsent('ru', () => legacyRussian);
  }
  return translations;
}

String _summaryLanguageLabel(String code) {
  return switch (code) {
    'en' => 'English',
    'ko' => 'Korean',
    'ru' => 'Russian',
    'zh' => 'Chinese',
    _ => code.toUpperCase(),
  };
}

Map<String, String> _cleanLocalizedValues(Map<String, String> values) {
  final cleaned = <String, String>{};
  for (final entry in values.entries) {
    final value = entry.value.trim();
    if (value.isNotEmpty) {
      cleaned[entry.key] = value;
    }
  }
  return cleaned;
}

class _LectureStudyNotesSection extends StatelessWidget {
  const _LectureStudyNotesSection({required this.lecture});

  final Lecture lecture;

  @override
  Widget build(BuildContext context) {
    final summaryTranslations = _summaryTranslationsForLecture(lecture);
    const summaryOrder = ['en', 'ko', 'ru', 'zh'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Study notes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Review the four-language summaries first, then work through each key concept and its supporting notes.',
          style: TextStyle(color: Color(0xFF475569), height: 1.45),
        ),
        if (summaryTranslations.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Summaries',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...summaryOrder.where(summaryTranslations.containsKey).map(
            (languageCode) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StructuredStudyBlock(
                title: '${_summaryLanguageLabel(languageCode)} summary',
                body: summaryTranslations[languageCode]!,
                icon: Icons.auto_stories_outlined,
              ),
            ),
          ),
        ],
        if (lecture.keyTerms.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Main keywords',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...lecture.keyTerms.map(
            (term) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _KeyTermStudyCard(term: term),
            ),
          ),
        ],
      ],
    );
  }
}

class _StructuredStudyBlock extends StatelessWidget {
  const _StructuredStudyBlock({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF0F766E)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            body.trim(),
            style: const TextStyle(
              color: Color(0xFF0F172A),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyTermStudyCard extends StatelessWidget {
  const _KeyTermStudyCard({required this.term});

  final KeyTerm term;

  @override
  Widget build(BuildContext context) {
    final explanations = _cleanLocalizedValues(term.explanations);
    if (explanations.isEmpty) {
      if (term.originalExplanation.trim().isNotEmpty) {
        explanations['ko'] = term.originalExplanation.trim();
      }
      if (term.russianExplanation.trim().isNotEmpty) {
        explanations['ru'] = term.russianExplanation.trim();
      }
    }
    final additionalNotes = _cleanLocalizedValues(term.additionalNotes);
    if (additionalNotes.isEmpty && term.additionalContext.trim().isNotEmpty) {
      additionalNotes['ko'] = term.additionalContext.trim();
    }
    const languageOrder = ['en', 'ko', 'ru', 'zh'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE7F3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            term.term,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Text(
            'Detailed explanations',
            style: TextStyle(
              color: Color(0xFF0F766E),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ...languageOrder.where(explanations.containsKey).map(
            (languageCode) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StudyNoteLine(
                label: _summaryLanguageLabel(languageCode),
                value: explanations[languageCode]!,
              ),
            ),
          ),
          if (additionalNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Additional notes',
              style: TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            ...languageOrder.where(additionalNotes.containsKey).map(
              (languageCode) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StudyNoteLine(
                  label: _summaryLanguageLabel(languageCode),
                  value: additionalNotes[languageCode]!,
                  tint: const Color(0xFF2563EB),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StudyNoteLine extends StatelessWidget {
  const _StudyNoteLine({
    required this.label,
    required this.value,
    this.tint = const Color(0xFF0F766E),
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: tint,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(
          value.trim(),
          style: const TextStyle(
            color: Color(0xFF0F172A),
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _CompactLectureProgress extends StatelessWidget {
  const _CompactLectureProgress({required this.lecture});

  final Lecture lecture;

  @override
  Widget build(BuildContext context) {
    final progressPercent = lecture.progressPercent.clamp(0, 100).toInt();
    final progressText =
        lecture.progressMessage ?? _defaultLectureProgressMessage(lecture);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$progressPercent% complete',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        if (progressText.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            progressText,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
        ],
      ],
    );
  }
}

class _LectureProgressCard extends StatelessWidget {
  const _LectureProgressCard({required this.lecture});

  final Lecture lecture;

  @override
  Widget build(BuildContext context) {
    final progressPercent = lecture.progressPercent.clamp(0, 100).toInt();
    final progressValue = progressPercent / 100;
    final progressText =
        lecture.progressMessage ?? _defaultLectureProgressMessage(lecture);
    final chunkLabel =
        lecture.progressCurrent != null && lecture.progressTotal != null
        ? 'Chunk ${lecture.progressCurrent} of ${lecture.progressTotal}'
        : null;
    final progressColor = switch (lecture.status) {
      'failed' => const Color(0xFFB91C1C),
      'ready' => const Color(0xFF0F766E),
      _ => const Color(0xFF2563EB),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Processing progress',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '$progressPercent%',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: progressColor,
                  ),
                ),
              ],
            ),
            if (progressText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                progressText,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 10,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            if (chunkLabel != null) ...[
              const SizedBox(height: 10),
              Text(
                chunkLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LectureMeta extends StatelessWidget {
  const _LectureMeta({required this.lecture});

  final Lecture lecture;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                lecture.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _StatusPill(label: lecture.status),
          ],
        ),
        const SizedBox(height: 8),
        Text('Course: ${lecture.courseName}'),
        Text('Created: ${_prettyDateTime(lecture.createdAt)}'),
        Text('Updated: ${_prettyDateTime(lecture.updatedAt)}'),
        if ((lecture.errorMessage ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          _InfoBlock(title: 'Error', body: lecture.errorMessage!),
        ],
      ],
    );
  }
}

String _prettyDateTime(String value) {
  return value.replaceFirst('T', ' ').replaceFirst('Z', '');
}

String _defaultLectureProgressMessage(Lecture lecture) {
  return switch (lecture.status) {
    'uploaded' => 'Upload received and waiting to start.',
    'transcribing' => 'Turning the audio into text.',
    'summarizing' => 'Generating summaries and key terms.',
    'generating_quiz' => 'Building quiz questions from the lecture.',
    'ready' => 'Everything is ready to review.',
    'failed' => 'Processing stopped before completion.',
    _ => '',
  };
}

String _languageLabel(String code) {
  return switch (code) {
    'en' => 'English',
    'zh' => 'Chinese',
    'ko' => 'Korean',
    'ru' => 'Russian',
    _ => code.toUpperCase(),
  };
}

String _plannerEffortLabel(String effort) {
  return switch (effort) {
    'light' => 'Light',
    'deep' => 'Deep focus',
    _ => 'Steady',
  };
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
