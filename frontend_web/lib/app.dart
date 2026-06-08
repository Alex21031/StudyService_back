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
    required String fullName,
    required String schoolName,
    required String major,
    required String academicYear,
    required String preferredLanguage,
  }) async {
    final user = await api.register(
      email: email,
      password: password,
      fullName: fullName,
      schoolName: schoolName,
      major: major,
      academicYear: academicYear,
      preferredLanguage: preferredLanguage,
    );
    currentUser = user;
    if (user.preferredLanguage.trim().isNotEmpty) {
      localeCode = user.preferredLanguage.trim().toLowerCase();
    }
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
    if (user.preferredLanguage.trim().isNotEmpty) {
      localeCode = user.preferredLanguage.trim().toLowerCase();
    }
    notifyListeners();
    return user;
  }

  Future<UserProfile> refreshMe() async {
    final user = await api.me();
    currentUser = user;
    if (user.preferredLanguage.trim().isNotEmpty) {
      localeCode = user.preferredLanguage.trim().toLowerCase();
    }
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
  bool _showAuthPage = false;
  HomeAuthMode _authPageMode = HomeAuthMode.signIn;

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
          onOpenAuthPage: (mode) => setState(() {
            _authPageMode = mode;
            _showAuthPage = true;
          }),
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
    ];
    final isWideLayout = MediaQuery.sizeOf(context).width >= 1080;
    final content = _showAuthPage
        ? AuthWorkspaceScreen(
            controller: widget.controller,
            initialMode: _authPageMode,
            onBack: () => setState(() => _showAuthPage = false),
            onAuthenticated: () => setState(() => _showAuthPage = false),
          )
        : destinations[_selectedIndex].page;
    final isPublicPreloginShell =
        !widget.controller.isLoggedIn && (_selectedIndex == 0 || _showAuthPage);

    if (isPublicPreloginShell) {
      return Scaffold(body: content);
    }

    return Scaffold(
      drawer: isWideLayout
          ? null
          : Drawer(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.waves_rounded,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'WaveStudy',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
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
        automaticallyImplyLeading: !isWideLayout,
        toolbarHeight: 68,
        titleSpacing: 8,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _showAuthPage
                  ? null
                  : () => setState(() => _selectedIndex = 1),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Upload lecture'),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: isWideLayout ? 20 : 12),
            child: Center(
              child: _HeaderAccountPill(
                email: widget.controller.currentUser?.email ?? 'Guest session',
              ),
            ),
          ),
          if (!isWideLayout)
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
          const SizedBox.shrink(),
          /*
              PopupMenuItem(value: 'zh', child: Text('中文')),
              PopupMenuItem(value: 'ko', child: Text('한국어')),
              PopupMenuItem(value: 'ru', child: Text('Русский')),
            ],
            icon: const Icon(Icons.language),
          ),
          */
        ],
      ),
      body: isWideLayout
          ? Row(
              children: [
                Container(
                  width: 292,
                  margin: const EdgeInsets.fromLTRB(20, 12, 0, 20),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x080F172A),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.waves_rounded,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'WaveStudy',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    userEmail ?? 'Signed in',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: destinations.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final destination = destinations[index];
                            return _SidebarNavButton(
                              icon: destination.icon,
                              label: destination.label,
                              selected: index == _selectedIndex,
                              onTap: () => setState(() => _selectedIndex = index),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SidebarAccountCard(controller: widget.controller),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 20, 20),
                    child: content,
                  ),
                ),
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
    required this.onOpenAuthPage,
  });

  final AppController controller;
  final ValueChanged<int> onSelectFeature;
  final ValueChanged<HomeAuthMode> onOpenAuthPage;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum HomeAuthMode { signIn, register }

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    if (widget.controller.isLoggedIn) {
      return _LoggedInHomeDashboard(
        controller: widget.controller,
        onSelectFeature: widget.onSelectFeature,
      );
    }

    return Stack(
      children: [
        const Positioned(
          top: -120,
          right: -60,
          child: _AmbientGlow(
            size: 260,
            colors: [Color(0x332563EB), Color(0x00000000)],
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LandingTopBar(
                    isLoggedIn: widget.controller.isLoggedIn,
                    onOpenLibrary: () => widget.onSelectFeature(2),
                    onOpenSignIn: () => widget.onOpenAuthPage(HomeAuthMode.signIn),
                    onOpenRegister: () => widget.onOpenAuthPage(HomeAuthMode.register),
                  ),
          _HeroPanel(
            onSelectFeature: widget.onSelectFeature,
          ),
                  const _LandingProcessSection(),
                  _LandingFeaturesSection(
                    onOpenQuiz: () => widget.onSelectFeature(3),
                    onOpenPlanner: () => widget.onSelectFeature(4),
                    onOpenSummary: () => widget.onSelectFeature(2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

}

class _LoggedInHomeDashboard extends StatelessWidget {
  const _LoggedInHomeDashboard({
    required this.controller,
    required this.onSelectFeature,
  });

  final AppController controller;
  final ValueChanged<int> onSelectFeature;

  @override
  Widget build(BuildContext context) {
    final firstName = _dashboardGreetingName(controller.currentUser);

    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1040;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstName == null ? 'Welcome back!' : '안녕하세요, $firstName님!',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start a new upload or jump back into your latest study materials.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _DashboardUploadCard(
                          onTap: () => onSelectFeature(1),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _DashboardRecentCard(
                              onTap: () => onSelectFeature(2),
                            ),
                            const SizedBox(height: 20),
                            _DashboardQuizCard(
                              onTap: () => onSelectFeature(3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  _DashboardUploadCard(onTap: () => onSelectFeature(1)),
                  const SizedBox(height: 20),
                  _DashboardRecentCard(onTap: () => onSelectFeature(2)),
                  const SizedBox(height: 20),
                  _DashboardQuizCard(onTap: () => onSelectFeature(3)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

String? _dashboardGreetingName(UserProfile? user) {
  if (user == null) {
    return null;
  }
  final fullName = user.fullName.trim();
  if (fullName.isEmpty) {
    return null;
  }
  return fullName.split(RegExp(r'\s+')).first;
}

class AuthWorkspaceScreen extends StatefulWidget {
  const AuthWorkspaceScreen({
    super.key,
    required this.controller,
    required this.initialMode,
    required this.onBack,
    required this.onAuthenticated,
  });

  final AppController controller;
  final HomeAuthMode initialMode;
  final VoidCallback onBack;
  final VoidCallback onAuthenticated;

  @override
  State<AuthWorkspaceScreen> createState() => _AuthWorkspaceScreenState();
}

class _AuthWorkspaceScreenState extends State<AuthWorkspaceScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  late HomeAuthMode _mode;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _majorController = TextEditingController();
  bool _loading = false;
  String _academicYear = '1st year';
  String _preferredLanguage = 'ko';

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _preferredLanguage = widget.controller.localeCode;
    if (!const {'en', 'ko', 'ru', 'zh'}.contains(_preferredLanguage)) {
      _preferredLanguage = 'ko';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _schoolController.dispose();
    _majorController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _authInputDecoration(String label) {
    const borderColor = Color(0xFFD1D5DB);
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.6),
      ),
    );
  }

  bool _validateInputs() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !_emailPattern.hasMatch(email)) {
      _showMessage('Enter a valid email address.');
      return false;
    }
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return false;
    }
    if (_mode == HomeAuthMode.register) {
      if (_confirmPasswordController.text != password) {
        _showMessage('Password confirmation does not match.');
        return false;
      }
      if (_fullNameController.text.trim().isEmpty) {
        _showMessage('Enter your name.');
        return false;
      }
      if (_schoolController.text.trim().isEmpty) {
        _showMessage('Enter your school or university.');
        return false;
      }
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validateInputs()) {
      return;
    }
    setState(() => _loading = true);
    try {
      if (_mode == HomeAuthMode.signIn) {
        final user = await widget.controller.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (!mounted) {
          return;
        }
        _showMessage('Signed in as ${user.email}.');
        widget.onAuthenticated();
        return;
      }

      final user = await widget.controller.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        schoolName: _schoolController.text.trim(),
        major: _majorController.text.trim(),
        academicYear: _academicYear,
        preferredLanguage: _preferredLanguage,
      );
      if (!mounted) {
        return;
      }
      _showMessage('Account created for ${user.email}.');
      widget.onAuthenticated();
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

  @override
  Widget build(BuildContext context) {
    final cardTitle = _mode == HomeAuthMode.signIn ? '로그인' : '계정 만들기';

    final authCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            cardTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _authInputDecoration('Email address'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: _authInputDecoration(
              _mode == HomeAuthMode.signIn ? 'Password' : 'Create password',
            ),
          ),
          if (_mode == HomeAuthMode.register) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: _authInputDecoration('Confirm password'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _fullNameController,
              decoration: _authInputDecoration('Full name'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _schoolController,
              decoration: _authInputDecoration('School or university'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _majorController,
              decoration: _authInputDecoration('Major or department'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _academicYear,
              decoration: _authInputDecoration('Academic year'),
              items: const [
                DropdownMenuItem(value: '1st year', child: Text('1st year')),
                DropdownMenuItem(value: '2nd year', child: Text('2nd year')),
                DropdownMenuItem(value: '3rd year', child: Text('3rd year')),
                DropdownMenuItem(value: '4th year', child: Text('4th year')),
                DropdownMenuItem(value: 'Graduate', child: Text('Graduate')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _academicYear = value);
                }
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _preferredLanguage,
              decoration: _authInputDecoration('Preferred language'),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'ko', child: Text('Korean')),
                DropdownMenuItem(value: 'ru', child: Text('Russian')),
                DropdownMenuItem(value: 'zh', child: Text('Chinese')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _preferredLanguage = value);
                }
              },
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _loading
                    ? (_mode == HomeAuthMode.signIn
                          ? 'Signing in...'
                          : 'Creating account...')
                    : (_mode == HomeAuthMode.signIn ? 'Sign in' : 'Create account'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: _loading
                  ? null
                  : () {
                      setState(() {
                        _mode = _mode == HomeAuthMode.signIn
                            ? HomeAuthMode.register
                            : HomeAuthMode.signIn;
                      });
                    },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                  children: _mode == HomeAuthMode.signIn
                      ? const [
                          TextSpan(text: 'Need a new account? '),
                          TextSpan(
                            text: 'Create one',
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ]
                      : const [
                          TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Sign in',
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final minimumHeight = max(
          constraints.maxHeight,
          _mode == HomeAuthMode.signIn ? 700.0 : 920.0,
        );

        return DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: SizedBox(
                height: minimumHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: widget.onBack,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Back to home'),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: authCard,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
          const Text(
            'Lecture details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 18),
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
          if (_selectedFile != null) ...[
            _InlineSummaryTile(
              icon: Icons.audio_file_outlined,
              title: _selectedFile!.name,
              subtitle:
                  'Selected and ready. Start processing when the lecture details look right.',
            ),
            const SizedBox(height: 14),
          ],
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
                const Text(
                  'Latest upload',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
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
          _PageHeader(
            title: '강의 업로드',
            subtitle: '녹음 파일을 업로드하여 학습 자료를 생성하세요.',
          ),
          const SizedBox(height: 18),
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
                    children: [resultPanel],
                  ),
                ),
              ],
            )
          else ...[
            uploadForm,
            const SizedBox(height: 20),
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
              for (var i = 0; i < _lectures.length; i++) ...[
                _LectureListRow(
                  lecture: _lectures[i],
                  selected: _selectedDetail?.lecture.id == _lectures[i].id,
                  onTap: _loading ? null : () => _loadDetail(_lectures[i].id),
                ),
                if (i != _lectures.length - 1)
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
              ],
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
                const Text(
                  'Lecture detail',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
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
          _PageHeader(
            title: 'AI 요약',
            subtitle: '저장된 강의를 열어 요약, 핵심 개념, 전사 내용을 확인하세요.',
            action: FilledButton(
              onPressed: _loading
                  ? null
                  : () => _refreshLectures(
                      preferredLectureId: widget.controller.latestLectureId,
                    ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Refresh'),
            ),
          ),
          const SizedBox(height: 18),
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
                  child: _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Saved lectures',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        libraryList,
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 6,
                  child: detailPanel,
                ),
              ],
            )
          else ...[
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saved lectures',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  libraryList,
                ],
              ),
            ),
            const SizedBox(height: 20),
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
  static const List<int> _quizQuestionCountOptions = [5, 10, 15];

  bool _loading = false;
  List<Lecture> _lectures = const [];
  final Set<String> _selectedLectureIds = <String>{};
  final Random _random = Random();
  List<LectureQuiz> _quizPool = const [];
  List<LectureQuiz> _quizzes = const [];
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String> _answers = {};
  String _quizLanguage = 'en';
  int _quizQuestionCount = 5;
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
    return pool.take(min(_quizQuestionCount, pool.length)).toList();
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

  void _updateQuizQuestionCount(int value) {
    setState(() {
      _quizQuestionCount = value;
      _resetQuizAttemptState();
      _quizzes = _quizPool.isEmpty ? const [] : _buildQuizSet(_quizPool);
    });
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
              questionCount: _quizQuestionCount,
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
            ? 'A fresh ${_quizzes.length}-question quiz set is ready.'
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
    _showMessage('A new ${_quizzes.length}-question quiz set is ready.');
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
    final isWideLayout = MediaQuery.sizeOf(context).width >= 1100;
    return _PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeader(
            title: '복습 퀴즈',
            subtitle: '강의를 선택하고 바로 퀴즈 세트를 만들어 복습을 시작하세요.',
          ),
          const SizedBox(height: 18),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quiz setup',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '1. Choose lectures  2. Pick a language  3. Load saved questions or make a fresh set.',
                  style: TextStyle(color: Color(0xFF64748B), height: 1.45),
                ),
                const SizedBox(height: 16),
                if (isWideLayout)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _QuizSetupBlock(
                          title: 'Lecture sources',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_lectures.isEmpty)
                                const Text(
                                  'Refresh your ready lectures first, then choose the ones you want in this quiz.',
                                  style: TextStyle(
                                    color: Color(0xFF475569),
                                    height: 1.45,
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: _lectures
                                      .map(
                                        (lecture) => FilterChip(
                                          label: Text(
                                            '${lecture.title} · ${lecture.courseName}',
                                          ),
                                          selected: _selectedLectureIds.contains(
                                            lecture.id,
                                          ),
                                          onSelected: _loading
                                              ? null
                                              : (selected) => _toggleLectureSelection(
                                                    lecture.id,
                                                    selected,
                                                  ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              if (_selectedLectureIds.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  '${_selectedLectureIds.length} lecture${_selectedLectureIds.length == 1 ? '' : 's'} selected.',
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: _QuizSetupBlock(
                          title: 'Quiz setup',
                          child: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _quizLanguage,
                                decoration: const InputDecoration(
                                  labelText: 'Quiz language',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'en',
                                    child: Text('English'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'ko',
                                    child: Text('Korean'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'ru',
                                    child: Text('Russian'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'zh',
                                    child: Text('Chinese'),
                                  ),
                                ],
                                onChanged: _loading
                                    ? null
                                    : (value) {
                                        if (value == null) {
                                          return;
                                        }
                                        setState(() {
                                          _quizLanguage =
                                              _normalizeQuizLanguage(value);
                                          _resetQuizWorkspace();
                                        });
                                      },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                initialValue: _quizQuestionCount,
                                decoration: const InputDecoration(
                                  labelText: 'Question count',
                                ),
                                items: _quizQuestionCountOptions
                                    .map(
                                      (count) => DropdownMenuItem<int>(
                                        value: count,
                                        child: Text('$count questions'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _loading
                                    ? null
                                    : (value) {
                                        if (value == null) {
                                          return;
                                        }
                                        _updateQuizQuestionCount(value);
                                      },
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _loading ? null : _loadLectures,
                                  child: const Text('Refresh lectures'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _loading ? null : () => _loadQuizzes(),
                                  child: const Text('Use saved questions'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _loading
                                      ? null
                                      : () => _loadQuizzes(regenerate: true),
                                  child: const Text('Make fresh questions'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
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
                              label: Text(
                                '${lecture.title} · ${lecture.courseName}',
                              ),
                              selected: _selectedLectureIds.contains(lecture.id),
                              onSelected: _loading
                                  ? null
                                  : (selected) =>
                                        _toggleLectureSelection(lecture.id, selected),
                            ),
                          )
                          .toList(),
                    ),
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _quizQuestionCount,
                    decoration: const InputDecoration(
                      labelText: 'Question count',
                    ),
                    items: _quizQuestionCountOptions
                        .map(
                          (count) => DropdownMenuItem<int>(
                            value: count,
                            child: Text('$count questions'),
                          ),
                        )
                        .toList(),
                    onChanged: _loading
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            _updateQuizQuestionCount(value);
                          },
                  ),
                ],
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
                  'Choose one or more ready lectures above, then use saved questions or make a fresh quiz set.',
            )
          else ...[
            const SizedBox(height: 8),
            if (_selectedLectures.isNotEmpty) ...[
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current quiz set',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
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
                          label: 'Target size',
                          value: '$_quizQuestionCount',
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
                              : '${_quizzes.length}-question set',
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
                    'Review result',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
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
          const _PageHeader(
            title: '학습 계획',
            subtitle: '시험 일정과 선택한 강의를 기준으로 현실적인 학습 계획을 만드세요.',
          ),
          const SizedBox(height: 18),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Plan setup',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '1. Set the course scope  2. Choose lectures  3. Pick your weekly study rhythm.',
                  style: TextStyle(color: Color(0xFF64748B), height: 1.45),
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
                  const Text(
                    'Plan result',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
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
          _WorkspaceIntroCard(
            icon: Icons.translate_outlined,
            eyebrow: 'Mail translation',
            title: 'Translate one message into the languages your audience actually needs.',
            body:
                'Paste the original email once, choose the target languages, and keep every translated version together for quick review.',
            metrics: [
              _MetricCard(label: 'Target languages', value: '${_languages.length}'),
            ],
          ),
          const SizedBox(height: 18),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelHeader(
                  title: 'Translation setup',
                  subtitle:
                      'Choose the languages you need and keep the source message short and clean for the best result.',
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
          const _WorkspaceIntroCard(
            icon: Icons.psychology_outlined,
            eyebrow: 'Problem solving',
            title: 'Open one guided solving session and keep every step in the same place.',
            body:
                'Paste the problem, choose the closest type, and let the assistant walk the learner through prompts, hints, and feedback without losing the thread.',
          ),
          const SizedBox(height: 18),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelHeader(
                  title: 'Session setup',
                  subtitle:
                      'Start with the full problem statement so the assistant can keep the session coherent from the first step.',
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

class _LandingTopBar extends StatelessWidget {
  const _LandingTopBar({
    required this.isLoggedIn,
    required this.onOpenLibrary,
    required this.onOpenSignIn,
    required this.onOpenRegister,
  });

  final bool isLoggedIn;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenSignIn;
  final VoidCallback onOpenRegister;

  @override
  Widget build(BuildContext context) {
    final isWideLayout = MediaQuery.sizeOf(context).width >= 960;

    return Container(
      color: Colors.white,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: _LandingContainer(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: isWideLayout
                ? Row(
                    children: [
                      const Text(
                        'WaveStudy',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton(
                            onPressed: isLoggedIn ? onOpenLibrary : onOpenSignIn,
                            child: Text(isLoggedIn ? '내 라이브러리' : '로그인'),
                          ),
                          FilledButton(
                            onPressed: isLoggedIn ? onOpenLibrary : onOpenRegister,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(isLoggedIn ? '학습 이어가기' : '무료로 시작하기'),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'WaveStudy',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: isLoggedIn ? onOpenLibrary : onOpenRegister,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(isLoggedIn ? '이어가기' : '무료 시작'),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.onSelectFeature,
  });

  final ValueChanged<int> onSelectFeature;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: _LandingContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 72),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _LaunchBadge(label: 'Built for real study sessions'),
              const SizedBox(height: 22),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: const Text(
                  'Turn lecture recordings into study material.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: const Text(
                  'Upload once. Review notes, practice quizzes, and build a plan from the same lecture.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 17,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                // Development note: this CTA should route directly into the core
                // upload/workspace flow without a login or signup wall.
                onPressed: () => onSelectFeature(1),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                ),
                child: const Text('시작하기'),
              ),
              const SizedBox(height: 28),
              const Text(
                'Trusted by students from top universities',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  _UniversityBadge(label: 'KHU'),
                  _UniversityBadge(label: 'SNU'),
                  _UniversityBadge(label: 'KU'),
                  _UniversityBadge(label: 'PKNU'),
                  _UniversityBadge(label: 'SKKU'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingProcessSection extends StatelessWidget {
  const _LandingProcessSection();

  @override
  Widget build(BuildContext context) {
    final isWideLayout = MediaQuery.sizeOf(context).width >= 980;

    final steps = const [
      _ProcessStepCard(
        icon: Icons.mic_none_rounded,
        title: '1단계: 강의 녹음 업로드',
      ),
      _ProcessStepCard(
        icon: Icons.auto_awesome_outlined,
        title: '2단계: AI 분석 및 요약',
      ),
      _ProcessStepCard(
        icon: Icons.note_alt_outlined,
        title: '3단계: 나만의 학습 세트 완성',
      ),
    ];

    return Container(
      width: double.infinity,
      color: const Color(0xFFF9FAFB),
      child: _LandingContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _CenteredSectionHeader(
                title: 'Process flow',
                subtitle: 'Upload once, then move through the study loop in order.',
              ),
              const SizedBox(height: 32),
              if (isWideLayout)
                Row(
                  children: [
                    Expanded(child: steps[0]),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF94A3B8)),
                    ),
                    Expanded(child: steps[1]),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF94A3B8)),
                    ),
                    Expanded(child: steps[2]),
                  ],
                )
              else
                Column(
                  children: const [
                    _ProcessStepCard(
                      icon: Icons.mic_none_rounded,
                      title: '1단계: 강의 녹음 업로드',
                    ),
                    SizedBox(height: 10),
                    Icon(Icons.arrow_downward_rounded, color: Color(0xFF94A3B8)),
                    SizedBox(height: 10),
                    _ProcessStepCard(
                      icon: Icons.auto_awesome_outlined,
                      title: '2단계: AI 분석 및 요약',
                    ),
                    SizedBox(height: 10),
                    Icon(Icons.arrow_downward_rounded, color: Color(0xFF94A3B8)),
                    SizedBox(height: 10),
                    _ProcessStepCard(
                      icon: Icons.note_alt_outlined,
                      title: '3단계: 나만의 학습 세트 완성',
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingFeaturesSection extends StatelessWidget {
  const _LandingFeaturesSection({
    required this.onOpenQuiz,
    required this.onOpenPlanner,
    required this.onOpenSummary,
  });

  final VoidCallback onOpenQuiz;
  final VoidCallback onOpenPlanner;
  final VoidCallback onOpenSummary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: _LandingContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _CenteredSectionHeader(
                title: 'Features',
                subtitle: 'Three tools that turn one lecture into a usable study workflow.',
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 980 ? 3 : 1;
                  final children = [
                    _FeatureInfoCard(
                      icon: Icons.description_outlined,
                      title: '요약 노트',
                      body: 'Multi-language summaries and a clean structure view from the same lecture.',
                      actionLabel: 'Open summary',
                      onTap: onOpenSummary,
                    ),
                    _FeatureInfoCard(
                      icon: Icons.quiz_outlined,
                      title: '퀴즈 생성',
                      body: 'Automated quiz sets built directly from lecture content and saved notes.',
                      actionLabel: 'Open quizzes',
                      onTap: onOpenQuiz,
                    ),
                    _FeatureInfoCard(
                      icon: Icons.calendar_month_outlined,
                      title: '스터디 플랜',
                      body: 'Personalized schedules built from selected lectures and review goals.',
                      actionLabel: 'Open planner',
                      onTap: onOpenPlanner,
                    ),
                  ];

                  if (columns == 1) {
                    return Column(
                      children: [
                        for (var i = 0; i < children.length; i++) ...[
                          children[i],
                          if (i != children.length - 1) const SizedBox(height: 14),
                        ],
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: children[0]),
                      const SizedBox(width: 14),
                      Expanded(child: children[1]),
                      const SizedBox(width: 14),
                      Expanded(child: children[2]),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UniversityBadge extends StatelessWidget {
  const _UniversityBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProcessStepCard extends StatelessWidget {
  const _ProcessStepCard({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureInfoCard extends StatelessWidget {
  const _FeatureInfoCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: const Color(0xFF2563EB),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _DashboardUploadCard extends StatelessWidget {
  const _DashboardUploadCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedCardPainter(
          color: const Color(0xFFBFDBFE),
          radius: 28,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.cloud_upload_rounded,
                  color: Color(0xFF2563EB),
                  size: 30,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Upload a new lecture',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Drop in a recording and turn it into summaries, quizzes, and a study plan.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text(
                      'Start upload',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardRecentCard extends StatelessWidget {
  const _DashboardRecentCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const recentItems = ['Lecture 1 summary', 'Lecture 2 summary', 'Lecture 3 summary'];

    return _DashboardPanel(
      title: 'Recent summaries',
      subtitle: 'Open a recent lecture and keep reviewing from the library.',
      child: Column(
        children: [
          for (final item in recentItems) ...[
            _DashboardListRow(
              icon: Icons.description_outlined,
              title: item,
            ),
            if (item != recentItems.last) const SizedBox(height: 12),
          ],
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                padding: EdgeInsets.zero,
              ),
              child: const Text('Open library'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardQuizCard extends StatelessWidget {
  const _DashboardQuizCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      title: 'Quick quiz',
      subtitle: 'Continue your last quiz or jump into a new review set.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Continue your last quiz',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Resume your review flow and check your weak concepts.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Open quizzes'),
          ),
        ],
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _DashboardListRow extends StatelessWidget {
  const _DashboardListRow({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }
}

class _LectureListRow extends StatelessWidget {
  const _LectureListRow({
    required this.lecture,
    required this.selected,
    required this.onTap,
  });

  final Lecture lecture;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFCBD5E1),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lecture.title,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      _StatusPill(label: lecture.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lecture.courseName,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _prettyDateTime(lecture.updatedAt),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12.5,
                    ),
                  ),
                  if ((lecture.progressMessage ?? '').isNotEmpty ||
                      lecture.progressPercent > 0) ...[
                    const SizedBox(height: 10),
                    _CompactLectureProgress(lecture: lecture),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAccountPill extends StatelessWidget {
  const _HeaderAccountPill({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final initial = email.isEmpty ? 'S' : email.substring(0, 1).toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFEFF6FF),
            child: Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            email,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedCardPainter extends CustomPainter {
  const _DashedCardPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = min(distance + 8, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += 14;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCardPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _LandingContainer extends StatelessWidget {
  const _LandingContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
    );
  }
}

class _CenteredSectionHeader extends StatelessWidget {
  const _CenteredSectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF475569),
              height: 1.55,
            ),
          ),
        ),
      ],
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

class _SidebarNavButton extends StatelessWidget {
  const _SidebarNavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = selected ? const Color(0xFF2563EB) : const Color(0xFF475569);
    return Material(
      color: selected ? const Color(0xFFEFF6FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: tint),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? const Color(0xFF0F172A) : tint,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizSetupBlock extends StatelessWidget {
  const _QuizSetupBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        child,
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
        color: const Color(0xFFE6FFFA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFCCFBF1)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF115E59),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
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
      decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
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

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    if (isWide && action != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _PageHeaderText(title: title, subtitle: subtitle)),
          const SizedBox(width: 16),
          action!,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeaderText(title: title, subtitle: subtitle),
        if (action != null) ...[
          const SizedBox(height: 16),
          action!,
        ],
      ],
    );
  }
}

class _PageHeaderText extends StatelessWidget {
  const _PageHeaderText({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF64748B),
            height: 1.45,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _WorkspaceIntroCard extends StatelessWidget {
  const _WorkspaceIntroCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    this.metrics = const [],
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final List<Widget> metrics;

  @override
  Widget build(BuildContext context) {
    final isWideLayout = MediaQuery.sizeOf(context).width >= 1024;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFE6FFFA),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: const Color(0xFF0F766E)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: const TextStyle(
                      color: Color(0xFF0F766E),
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      letterSpacing: 0.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 31,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      height: 1.04,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Text(
                      body,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        height: 1.55,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isWideLayout && metrics.isNotEmpty) ...[
          const SizedBox(height: 18),
          Wrap(spacing: 12, runSpacing: 12, children: metrics),
        ],
      ],
    );

    return _SectionCard(
      child: isWideLayout
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: details),
                const SizedBox(width: 22),
                Container(
                  width: 1,
                  height: 172,
                  color: const Color(0xFFE2E8F0),
                ),
                const SizedBox(width: 22),
                Expanded(
                  flex: 5,
                  child: metrics.isEmpty
                      ? const SizedBox.shrink()
                      : Wrap(spacing: 12, runSpacing: 12, children: metrics),
                ),
              ],
            )
          : details,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF475569),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(22), child: child),
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
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    const tint = Color(0xFF2563EB);
    return Container(
      constraints: const BoxConstraints(minWidth: 148),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 6),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBFEFE), Color(0xFFF7FBFC)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3EDF1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE6FFFA),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: const Color(0xFF0F766E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    height: 1.45,
                    fontSize: 13.5,
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

class _InlineSummaryTile extends StatelessWidget {
  const _InlineSummaryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE6FFFA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF0F766E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    height: 1.4,
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
