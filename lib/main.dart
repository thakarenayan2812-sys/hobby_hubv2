// ============================================================================
// HobbyHub AI - main.dart (v3, build-fixed)
// ----------------------------------------------------------------------------
// Fixes in this version:
//   * `const` removed everywhere it was combined with C.violet / C.coral /
//     C.marigold / C.magenta (theme-driven getters can never be const).
//   * _catColor is now a getter instead of a const map.
//   * fl_chart chart widgets no longer rely on const constructors.
//   * Firebase init is awaited by the splash screen (no race with Circles).
//
// pubspec.yaml must contain (fl_chart was the missing one):
//   fl_chart: ^0.69.0
//   firebase_core, firebase_auth, cloud_firestore, google_sign_in,
//   flutter_animate, google_fonts, shared_preferences, image_picker, image,
//   google_mlkit_image_labeling, android_intent_plus
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'firebase_circles.dart';

/// Completes when Firebase has finished initialising (errors are swallowed so
/// the app still opens offline; Circles will just show an error state).
Future<void> bootFuture = Future<void>.value();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bootFuture = Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).then<void>((_) {}).catchError((Object _) {});
  await app.load();
  runApp(const HobbyHubApp());
}

// ============================================================================
// THEMES - 5 switchable palettes
// ============================================================================

class AppTheme {
  final String name;
  final IconData icon;
  final Color seed, a, b, c, d;
  const AppTheme(this.name, this.icon, this.seed, this.a, this.b, this.c, this.d);
}

const themes = <AppTheme>[
  AppTheme('Violet Pop', Icons.auto_awesome_rounded, Color(0xFF6C4CFF), Color(0xFF6C4CFF), Color(0xFFB04CFF), Color(0xFFFF5C7A), Color(0xFFFFB020)),
  AppTheme('Ocean', Icons.waves_rounded, Color(0xFF0F7AE5), Color(0xFF0F7AE5), Color(0xFF17C3A6), Color(0xFF3DA5FF), Color(0xFF00C2CB)),
  AppTheme('Forest', Icons.eco_rounded, Color(0xFF2E8B57), Color(0xFF2E8B57), Color(0xFF6FBE44), Color(0xFFB7C93E), Color(0xFFE0A62E)),
  AppTheme('Sunset', Icons.wb_twilight_rounded, Color(0xFFE5574F), Color(0xFFE5574F), Color(0xFFF08A3C), Color(0xFFFFB020), Color(0xFFB04CFF)),
  AppTheme('Mono', Icons.contrast_rounded, Color(0xFF2B2B35), Color(0xFF2B2B35), Color(0xFF5A5670), Color(0xFF8B8CFF), Color(0xFFB8B4D6)),
];

// ============================================================================
// COLOR TOKENS (derived from the active theme at build time)
// NOTE: violet / magenta / coral / marigold are GETTERS, so they can never be
// used inside a `const` expression. mint / sky / ink / lilac / mute are const.
// ============================================================================

class C {
  static AppTheme t = themes[0];
  static Color get violet => t.a;
  static Color get magenta => t.b;
  static Color get coral => t.c;
  static Color get marigold => t.d;
  static const mint = Color(0xFF17C3A6);
  static const sky = Color(0xFF3DA5FF);
  static const ink = Color(0xFF16123A);
  static const lilac = Color(0xFFF4F1FF);
  static const mute = Color(0xFF6E6A8C);
  static const nightBg = Color(0xFF0E0B22);
  static const nightCard = Color(0xFF1B1737);
}

extension Ctx on BuildContext {
  bool get dark => Theme.of(this).brightness == Brightness.dark;
  Color get cardColor => dark ? C.nightCard : Colors.white;
  Color get textMute => dark ? const Color(0xFFA29EC4) : C.mute;
  Color get accent => dark ? Color.lerp(C.violet, Colors.white, 0.25)! : C.violet;
}

ThemeData buildTheme(Brightness b, AppTheme at) {
  C.t = at;
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: at.seed, brightness: b).copyWith(
    primary: dark ? Color.lerp(at.a, Colors.white, 0.25)! : at.a,
    surface: dark ? C.nightBg : C.lilac,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  const sizes = TextTheme(
    displayLarge: TextStyle(fontSize: 52), displayMedium: TextStyle(fontSize: 41), displaySmall: TextStyle(fontSize: 33),
    headlineLarge: TextStyle(fontSize: 29), headlineMedium: TextStyle(fontSize: 26), headlineSmall: TextStyle(fontSize: 22),
    titleLarge: TextStyle(fontSize: 20), titleMedium: TextStyle(fontSize: 15), titleSmall: TextStyle(fontSize: 13),
    bodyLarge: TextStyle(fontSize: 15), bodyMedium: TextStyle(fontSize: 13), bodySmall: TextStyle(fontSize: 11.5),
    labelLarge: TextStyle(fontSize: 13), labelMedium: TextStyle(fontSize: 11.5), labelSmall: TextStyle(fontSize: 10.5),
  );
  final text = GoogleFonts.plusJakartaSansTextTheme(sizes).apply(bodyColor: dark ? Colors.white : C.ink, displayColor: dark ? Colors.white : C.ink);
  return base.copyWith(
    scaffoldBackgroundColor: dark ? C.nightBg : C.lilac,
    textTheme: text,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? C.nightCard : Colors.white, indicatorColor: scheme.primary.withOpacity(0.16),
      elevation: 0, height: 66, labelTextStyle: WidgetStatePropertyAll(text.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13), textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700))),
    chipTheme: ChipThemeData(shape: const StadiumBorder(), side: BorderSide.none, backgroundColor: dark ? C.nightCard : Colors.white, selectedColor: scheme.primary.withOpacity(0.2), labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600), showCheckmark: false),
  );
}

// ============================================================================
// HOBBY CATALOGUE + QUERY + FILTER/SCORE LOGIC
// ============================================================================

class Hobby {
  final String name;
  final IconData icon;
  final Color Function() color;
  final int minMinutes, costInr, beginner, groupSize;
  final Set<String> locations, tags, bestTime;
  final List<String> equipment;
  final bool physical, indoor, outdoor, skillGrowth;
  const Hobby(this.name, this.icon, this.color, {required this.minMinutes, required this.costInr, required this.beginner, required this.locations, required this.tags, required this.bestTime, this.equipment = const [], this.physical = false, this.groupSize = 1, this.indoor = true, this.outdoor = false, this.skillGrowth = true});
}

List<Hobby> get catalogue => [
  Hobby('Sketching', Icons.draw_rounded, () => C.coral, minMinutes: 15, costInr: 300, beginner: 5, locations: {'home', 'college', 'outdoor'}, tags: {'creative', 'calm'}, bestTime: {'evening', 'night', 'weekend'}, equipment: ['sketchbook', 'pencils'], outdoor: true),
  Hobby('Ukulele', Icons.music_note_rounded, () => C.magenta, minMinutes: 30, costInr: 2500, beginner: 3, locations: {'home'}, tags: {'music', 'creative'}, bestTime: {'evening', 'weekend'}, equipment: ['ukulele']),
  Hobby('Running', Icons.directions_run_rounded, () => C.mint, minMinutes: 20, costInr: 1500, beginner: 5, locations: {'outdoor'}, tags: {'fitness', 'outdoor'}, bestTime: {'morning', 'evening'}, equipment: ['running shoes'], physical: true, indoor: false, outdoor: true),
  Hobby('Cooking new recipes', Icons.soup_kitchen_rounded, () => C.marigold, minMinutes: 45, costInr: 500, beginner: 4, locations: {'home'}, tags: {'food', 'creative'}, bestTime: {'evening', 'weekend'}),
  Hobby('Stargazing', Icons.nightlight_round, () => C.violet, minMinutes: 30, costInr: 0, beginner: 5, locations: {'outdoor'}, tags: {'astronomy', 'outdoor', 'calm'}, bestTime: {'night'}, indoor: false, outdoor: true),
  Hobby('Chess', Icons.extension_rounded, () => C.sky, minMinutes: 15, costInr: 0, beginner: 4, locations: {'home', 'college', 'office'}, tags: {'strategy', 'social'}, bestTime: {'afternoon', 'evening', 'night'}, groupSize: 2),
  Hobby('Journaling', Icons.edit_note_rounded, () => C.coral, minMinutes: 10, costInr: 150, beginner: 5, locations: {'home', 'college', 'office'}, tags: {'calm', 'writing'}, bestTime: {'morning', 'night'}, equipment: ['notebook']),
  Hobby('Cycling', Icons.pedal_bike_rounded, () => C.mint, minMinutes: 40, costInr: 6000, beginner: 4, locations: {'outdoor'}, tags: {'fitness', 'outdoor', 'social'}, bestTime: {'morning', 'evening', 'weekend'}, equipment: ['bicycle'], physical: true, indoor: false, outdoor: true),
  Hobby('Photo walk', Icons.photo_camera_rounded, () => C.sky, minMinutes: 45, costInr: 0, beginner: 4, locations: {'outdoor'}, tags: {'creative', 'outdoor'}, bestTime: {'morning', 'evening', 'weekend'}, physical: true, indoor: false, outdoor: true),
  Hobby('Learn a language', Icons.translate_rounded, () => C.marigold, minMinutes: 15, costInr: 0, beginner: 4, locations: {'home', 'college', 'office'}, tags: {'learning'}, bestTime: {'morning', 'afternoon', 'night'}),
  Hobby('Yoga', Icons.self_improvement_rounded, () => C.mint, minMinutes: 15, costInr: 500, beginner: 5, locations: {'home', 'outdoor'}, tags: {'fitness', 'calm'}, bestTime: {'morning', 'night'}, physical: true, outdoor: true),
  Hobby('Pottery', Icons.coffee_rounded, () => C.coral, minMinutes: 60, costInr: 1800, beginner: 2, locations: {'home'}, tags: {'creative'}, bestTime: {'weekend'}, equipment: ['clay', 'wheel']),
  Hobby('Calligraphy', Icons.draw_outlined, () => C.violet, minMinutes: 15, costInr: 400, beginner: 4, locations: {'home', 'college'}, tags: {'creative', 'calm', 'writing'}, bestTime: {'evening', 'night'}, equipment: ['pens']),
  Hobby('Gardening', Icons.eco_rounded, () => C.mint, minMinutes: 20, costInr: 600, beginner: 5, locations: {'outdoor', 'home'}, tags: {'calm', 'outdoor'}, bestTime: {'morning', 'weekend'}, physical: true, outdoor: true),
  Hobby('Badminton', Icons.sports_tennis_rounded, () => C.sky, minMinutes: 30, costInr: 1200, beginner: 4, locations: {'outdoor', 'college'}, tags: {'fitness', 'social'}, bestTime: {'evening', 'weekend'}, equipment: ['racket'], physical: true, groupSize: 2, outdoor: true),
  Hobby('Board games', Icons.casino_rounded, () => C.marigold, minMinutes: 30, costInr: 0, beginner: 5, locations: {'home', 'college'}, tags: {'strategy', 'social'}, bestTime: {'evening', 'weekend'}, groupSize: 3),
  Hobby('Podcasting / voice notes', Icons.mic_rounded, () => C.coral, minMinutes: 20, costInr: 0, beginner: 3, locations: {'home'}, tags: {'creative', 'writing'}, bestTime: {'night'}),
  Hobby('Short-film making', Icons.videocam_rounded, () => C.magenta, minMinutes: 60, costInr: 0, beginner: 2, locations: {'outdoor', 'home'}, tags: {'creative', 'outdoor'}, bestTime: {'weekend'}, outdoor: true),
  Hobby('Origami', Icons.change_history_rounded, () => C.violet, minMinutes: 10, costInr: 100, beginner: 5, locations: {'home', 'college', 'office'}, tags: {'creative', 'calm'}, bestTime: {'afternoon', 'night'}),
  Hobby('Meditation', Icons.spa_rounded, () => C.mint, minMinutes: 10, costInr: 0, beginner: 5, locations: {'home', 'office', 'outdoor'}, tags: {'calm'}, bestTime: {'morning', 'night'}),
  Hobby("Rubik's cube", Icons.view_in_ar_rounded, () => C.sky, minMinutes: 10, costInr: 250, beginner: 4, locations: {'home', 'college', 'office'}, tags: {'strategy', 'learning'}, bestTime: {'afternoon', 'night'}),
  Hobby('Thrift / upcycling crafts', Icons.checkroom_rounded, () => C.marigold, minMinutes: 30, costInr: 500, beginner: 3, locations: {'home'}, tags: {'creative'}, bestTime: {'weekend'}),
  Hobby('Dance (freestyle)', Icons.nightlife_rounded, () => C.magenta, minMinutes: 20, costInr: 0, beginner: 4, locations: {'home', 'outdoor'}, tags: {'fitness', 'music', 'creative'}, bestTime: {'evening', 'weekend'}, physical: true, outdoor: true),
  Hobby('Volunteering nearby', Icons.volunteer_activism_rounded, () => C.coral, minMinutes: 60, costInr: 0, beginner: 3, locations: {'outdoor'}, tags: {'social', 'calm'}, bestTime: {'weekend'}, groupSize: 3, outdoor: true, indoor: false),
];

class Query {
  int minutes; String location, timeOfDay; Set<String> interests; int budget; int groupSize; bool? indoorOnly; bool skillGrowthOnly;
  Query({this.minutes = 60, this.location = 'home', this.timeOfDay = 'evening', Set<String>? interests, this.budget = 10000, this.groupSize = 1, this.indoorOnly, this.skillGrowthOnly = false}) : interests = interests ?? {};
}

double score(Hobby h, Query q) {
  if (!h.locations.contains(q.location) || h.minMinutes > q.minutes) return -1;
  if (q.budget < 10000 && h.costInr > q.budget) return -1;
  if (q.groupSize > 1 && h.groupSize < q.groupSize) return -1;
  if (q.indoorOnly == true && !h.indoor) return -1;
  if (q.indoorOnly == false && !h.outdoor) return -1;
  if (q.skillGrowthOnly && !h.skillGrowth) return -1;
  var s = 1.0 + h.beginner * 0.3;
  s += 2.0 * h.tags.where(q.interests.contains).length;
  if (h.bestTime.contains(q.timeOfDay)) s += 1.5;
  s += (h.minMinutes / q.minutes).clamp(0, 1) * 0.5;
  return s;
}

List<Hobby> recommend(Query q, {int k = 8}) {
  final scored = [for (final h in catalogue) (h, score(h, q))]..sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final e in scored) if (e.$2 > 0) e.$1].take(k).toList();
}

String catalogueContext() => [for (final h in catalogue) '${h.name}: about Rs ${h.costInr}, ${h.minMinutes}+ min, needs ${h.equipment.isEmpty ? "nothing" : h.equipment.join(", ")}, places: ${h.locations.join("/")}, beginner ${h.beginner}/5'].join('\n');

// ============================================================================
// USAGE SERVICE
// ============================================================================

class AppUsageEntry {
  final String name, pkg, category;
  final double minutesPerDay;
  AppUsageEntry(this.name, this.pkg, this.category, this.minutesPerDay);
}

class UsageResult {
  final List<AppUsageEntry> apps;
  final Map<String, double> byCategory;
  UsageResult(this.apps, this.byCategory);
}

class UsageService {
  static const _ch = MethodChannel('hobbyhub/usage');
  static const _cats = <String, List<String>>{
    'Social media': ['instagram', 'facebook', 'snapchat', 'twitter', 'reddit', 'pinterest', 'sharechat', 'moj', 'tiktok', 'linkedin', 'discord', 'telegram', 'whatsapp'],
    'Video': ['youtube', 'netflix', 'hotstar', 'amazon.avod', 'jio.media', 'mxtech', 'sonyliv', 'zee5', 'twitch', 'primevideo'],
    'Games': ['game', 'supercell', 'king.candy', 'pubg', 'krafton', 'garena', 'roblox', 'epicgames', 'tencent', 'miniclip', 'ludo'],
    'News': ['inshorts', 'dailyhunt', 'news', 'flipboard'],
    'Shopping': ['amazon.mshop', 'flipkart', 'myntra', 'meesho', 'ajio'],
    'Productive': ['docs', 'sheets', 'office', 'notion', 'drive', 'calendar', 'mail', 'gmail', 'outlook', 'chrome', 'slack'],
  };

  static String category(String pkg) {
    final p = pkg.toLowerCase();
    for (final e in _cats.entries) {
      if (e.value.any(p.contains)) return e.key;
    }
    return 'Other';
  }

  static Future<void> openSettings() async {
    if (!Platform.isAndroid) return;
    await const AndroidIntent(action: 'android.settings.USAGE_ACCESS_SETTINGS').launch();
  }

  static Future<UsageResult?> weeklyAverage() async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('usage', {'days': 7});
      if (raw == null || raw.isEmpty) return null;
      final apps = <AppUsageEntry>[];
      final byCat = <String, double>{};
      for (final e in raw) {
        final m = Map<String, dynamic>.from(e as Map);
        final pkg = m['pkg'] as String;
        final name = (m['name'] as String?) ?? pkg;
        final minutes = (m['ms'] as num).toDouble() / 60000.0 / 7.0;
        if (minutes < 1) continue;
        final cat = category(pkg);
        apps.add(AppUsageEntry(name, pkg, cat, minutes));
        byCat[cat] = (byCat[cat] ?? 0) + minutes;
      }
      apps.sort((a, b) => b.minutesPerDay.compareTo(a.minutesPerDay));
      return UsageResult(apps, byCat);
    } catch (_) {
      return null;
    }
  }

  static String suggestionFor(AppUsageEntry e) {
    if (e.minutesPerDay >= 90) return 'Set a ${(e.minutesPerDay * 0.5).round()} min/day limit in your phone\'s app timer - reclaim about ${(e.minutesPerDay * 0.5 * 7 / 60).toStringAsFixed(1)} h/week.';
    if (e.minutesPerDay >= 45) return 'Try checking it only twice a day instead of on every notification.';
    if (e.minutesPerDay >= 20) return 'Turn off non-essential notifications to cut unplanned opens.';
    return 'Already a light habit - no action needed.';
  }
}

// ============================================================================
// PROOF SERVICE
// ============================================================================

class ProofResult {
  final bool ok; final String message; final int? hash; final String? matched; final bool checked;
  const ProofResult.ok(this.hash, this.matched, this.checked) : ok = true, message = '';
  const ProofResult.fail(this.message) : ok = false, hash = null, matched = null, checked = true;
}

int? _dhash(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final small = img.copyResize(img.grayscale(decoded), width: 9, height: 8, interpolation: img.Interpolation.average);
  var h = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final a = small.getPixel(x, y).luminance;
      final b = small.getPixel(x + 1, y).luminance;
      h = (h << 1) | (a > b ? 1 : 0);
    }
  }
  return h;
}

int _hamming(int a, int b) { var x = a ^ b, c = 0; while (x != 0) { c += x & 1; x = x >>> 1; } return c; }

class ProofService {
  static const _kw = <String, List<String>>{
    'Sketching': ['draw', 'sketch', 'paper', 'pencil', 'art', 'illustration', 'notebook', 'paint', 'pen'],
    'Ukulele': ['guitar', 'ukulele', 'string', 'instrument', 'music'],
    'Running': ['shoe', 'footwear', 'sport', 'running', 'jog', 'sneaker', 'track', 'exercise'],
    'Cooking new recipes': ['food', 'dish', 'cook', 'kitchen', 'meal', 'recipe', 'bowl', 'pan', 'plate'],
    'Stargazing': ['sky', 'night', 'star', 'astronom', 'space', 'moon', 'dark', 'telescope'],
    'Chess': ['chess', 'board game', 'game', 'table'],
    'Journaling': ['handwriting', 'paper', 'notebook', 'pen', 'writing', 'book', 'diary'],
    'Cycling': ['bicycle', 'bike', 'wheel', 'cycl', 'tire', 'helmet'],
    'Photo walk': ['camera', 'photo', 'street', 'tree', 'plant', 'building', 'city', 'nature', 'sky'],
    'Learn a language': ['book', 'text', 'paper', 'notebook', 'screen', 'laptop', 'phone', 'document'],
    'Yoga': ['mat', 'exercise', 'person', 'stretch', 'fitness'],
    'Pottery': ['clay', 'pottery', 'craft', 'hand'],
    'Calligraphy': ['pen', 'handwriting', 'paper', 'ink', 'writing'],
    'Gardening': ['plant', 'leaf', 'soil', 'flower', 'garden', 'pot'],
    'Badminton': ['racket', 'sport', 'shuttle', 'court'],
    'Board games': ['board game', 'game', 'dice', 'card'],
    'Podcasting / voice notes': ['microphone', 'audio', 'room'],
    'Short-film making': ['camera', 'phone', 'video', 'outdoor'],
    'Origami': ['paper', 'craft', 'hand'],
    'Meditation': ['person', 'calm', 'room', 'mat'],
    "Rubik's cube": ['cube', 'puzzle', 'toy'],
    'Thrift / upcycling crafts': ['fabric', 'cloth', 'craft'],
    'Dance (freestyle)': ['person', 'room', 'movement'],
    'Volunteering nearby': ['people', 'outdoor', 'group'],
  };

  static Future<ProofResult> verify(String path, String hobby) async {
    final bytes = await File(path).readAsBytes();
    final hash = await Isolate.run(() => _dhash(bytes));
    if (hash == null) return const ProofResult.fail('We could not read that image. Try another photo.');
    for (final old in app.hashes) {
      if (_hamming(hash, old) <= 8) return const ProofResult.fail('This photo (or one almost identical) was already used. Take a fresh one today.');
    }
    String? matched; var checked = true;
    try {
      final labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.4));
      final labels = await labeler.processImage(InputImage.fromFilePath(path));
      await labeler.close();
      final words = _kw[hobby] ?? const <String>[];
      for (final l in labels) {
        final t = l.label.toLowerCase();
        if (words.any(t.contains)) { matched = l.label; break; }
      }
      if (matched == null) return ProofResult.fail("We could not spot $hobby in this photo. Show what you are doing, with your gear in frame.");
    } catch (_) { checked = false; }
    return ProofResult.ok(hash, matched, checked);
  }
}

// ============================================================================
// OFFLINE COACH
// ============================================================================

abstract class Coach { Stream<String> reply(String message); }

class OfflineCoach implements Coach {
  @override
  Stream<String> reply(String message) async* {
    final m = message.toLowerCase();
    int? budget;
    final b1 = RegExp(r'(?:₹|rs\.?\s*|inr\s*)\s*([\d,]+)').firstMatch(m);
    final b2 = RegExp(r'([\d,]+)\s*(?:rs|rupees)').firstMatch(m);
    final bm = b1 ?? b2;
    if (bm != null) budget = int.tryParse(bm.group(1)!.replaceAll(',', ''));
    var minutes = 60;
    final h = RegExp(r'(\d+)\s*(?:hour|hr|h)\b').firstMatch(m);
    final mn = RegExp(r'(\d+)\s*min').firstMatch(m);
    if (h != null) { minutes = int.parse(h.group(1)!) * 60; } else if (mn != null) { minutes = int.parse(mn.group(1)!); }
    final tod = ['morning', 'afternoon', 'evening', 'night', 'weekend'].firstWhere(m.contains, orElse: () => 'evening');
    final outdoor = m.contains('outdoor') || m.contains('outside');
    final picks = recommend(Query(minutes: minutes, budget: budget ?? 10000, timeOfDay: tod, location: outdoor ? 'outdoor' : 'home'), k: 3);
    final buf = StringBuffer();
    if (picks.isEmpty) {
      buf.write('Nothing fits that budget and time yet. Try a bit more time or a slightly higher budget.');
    } else {
      buf.writeln('Here is what fits ${budget != null ? "₹$budget and " : ""}$minutes minutes:\n');
      for (var i = 0; i < picks.length; i++) {
        final p = picks[i];
        buf.writeln('${i + 1}. ${p.name}: ${p.equipment.isEmpty ? "no equipment" : "you need ${p.equipment.join(", ")}"}. ${p.costInr == 0 ? "Free" : "About ₹${p.costInr}"}, ${p.minMinutes}+ min per session.');
      }
      buf.write('\nStart with ${picks.first.name} this $tod, then verify it with a photo to keep your streak.');
    }
    for (final w in buf.toString().split(' ')) { await Future.delayed(const Duration(milliseconds: 22)); yield '$w '; }
  }
}

// ============================================================================
// APP STATE
// ============================================================================

String _key(DateTime d) => d.toIso8601String().substring(0, 10);

class AppState extends ChangeNotifier {
  SharedPreferences? _p;
  int themeIndex = 0;
  ThemeMode mode = ThemeMode.system;

  bool usageGranted = false;
  List<AppUsageEntry> usageApps = [];
  Map<String, double> usage = {'Social media': 110, 'Video': 90, 'Games': 30, 'News': 20};
  double reduction = 30;

  int points = 0, streak = 0;
  DateTime? last;
  final Set<String> badges = {};
  final List<int> hashes = [];
  final List<String> days = [];

  final Set<String> interests = {};

  double get totalMinutes => usageGranted ? usageApps.fold(0.0, (a, b) => a + b.minutesPerDay) : usage.values.fold(0.0, (a, b) => a + b);
  double get recoverableMinutesPerDay => totalMinutes * reduction / 100;
  double get recoverableHoursPerWeek => recoverableMinutesPerDay * 7 / 60;

  Map<String, double> get categoryBreakdown => usageGranted ? usageApps.fold<Map<String, double>>({}, (m, e) { m[e.category] = (m[e.category] ?? 0) + e.minutesPerDay; return m; }) : usage;

  static const _levels = [(0, 'Curious'), (100, 'Explorer'), (300, 'Enthusiast'), (700, 'Regular'), (1500, 'Maestro')];
  String get level => _levels.lastWhere((l) => points >= l.$1).$2;
  int get nextLevelAt => _levels.firstWhere((l) => l.$1 > points, orElse: () => _levels.last).$1;

  DateTime get _today { final t = DateTime.now(); return DateTime(t.year, t.month, t.day); }
  bool get doneToday => last != null && last == _today;
  int get liveStreak => (last == null || _today.difference(last!).inDays > 1) ? 0 : streak;
  bool doneOn(DateTime d) => days.contains(_key(d));
  int get weekCount => [for (var i = 0; i < 7; i++) if (doneOn(_today.subtract(Duration(days: i)))) 1].length;

  Future<void> load() async {
    final p = _p = await SharedPreferences.getInstance();
    themeIndex = (p.getInt('themeIndex') ?? 0).clamp(0, themes.length - 1);
    final mi = (p.getInt('themeMode') ?? 0).clamp(0, ThemeMode.values.length - 1);
    mode = ThemeMode.values[mi];
    points = p.getInt('points') ?? 0;
    streak = p.getInt('streak') ?? 0;
    final l = p.getString('last');
    last = l == null ? null : DateTime.tryParse(l);
    badges..clear()..addAll(p.getStringList('badges') ?? []);
    hashes..clear()..addAll((p.getStringList('hashes') ?? []).map(int.parse));
    days..clear()..addAll(p.getStringList('days') ?? []);
    interests..clear()..addAll(p.getStringList('interests') ?? []);
  }

  void _save() {
    final p = _p; if (p == null) return;
    p.setInt('themeIndex', themeIndex);
    p.setInt('themeMode', mode.index);
    p.setInt('points', points);
    p.setInt('streak', streak);
    if (last != null) p.setString('last', last!.toIso8601String()); else p.remove('last');
    p.setStringList('badges', badges.toList());
    p.setStringList('hashes', hashes.map((e) => e.toString()).toList());
    p.setStringList('days', days);
    p.setStringList('interests', interests.toList());
  }

  void setTheme(int i) { themeIndex = i; _save(); notifyListeners(); }
  void setMode(ThemeMode m) { mode = m; _save(); notifyListeners(); }

  Future<void> refreshUsage() async {
    final r = await UsageService.weeklyAverage();
    if (r == null) { usageGranted = false; } else { usageGranted = true; usageApps = r.apps; }
    notifyListeners();
  }

  void setUsage(String k, double v) { usage[k] = v; notifyListeners(); }
  void setReduction(double v) { reduction = v; notifyListeners(); }
  void toggleInterest(String t) { interests.contains(t) ? interests.remove(t) : interests.add(t); _save(); notifyListeners(); }

  int recordVerifiedSession(int minutes, int hash) {
    final d = _today;
    if (last != d) { streak = (last != null && d.difference(last!).inDays == 1) ? streak + 1 : 1; last = d; }
    if (!days.contains(_key(d))) days.add(_key(d));
    final gained = 10 + minutes ~/ 10 + (streak > 7 ? 7 : streak) * 2;
    points += gained;
    hashes.add(hash);
    if (hashes.length > 200) hashes.removeAt(0);
    badges.add('First proof');
    if (streak >= 3) badges.add('3-day streak');
    if (streak >= 7) badges.add('7-day streak');
    if (points >= 100) badges.add('First 100');
    _save();
    notifyListeners();
    return gained;
  }

  Future<void> resetProgress() async {
    points = 0; streak = 0; last = null; badges.clear(); hashes.clear(); days.clear();
    _save();
    notifyListeners();
  }
}

final app = AppState();

// ============================================================================
// SHARED WIDGETS
// ============================================================================

class TimeRing extends StatelessWidget {
  final double value; final double size; final Widget? center;
  const TimeRing({super.key, required this.value, this.size = 200, this.center});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()), duration: const Duration(milliseconds: 1100), curve: Curves.easeOutCubic,
      builder: (_, t, __) => SizedBox(width: size, height: size, child: CustomPaint(painter: _RingPainter(t, context.dark ? Colors.white12 : Colors.black.withOpacity(0.06)), child: Center(child: center))),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double t; final Color track;
  _RingPainter(this.t, this.track);
  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width / 2 - 12; final c = s.center(Offset.zero);
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 18..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, p..color = track);
    p.shader = SweepGradient(startAngle: 0, endAngle: 2 * math.pi, colors: [C.marigold, C.coral], transform: const GradientRotation(-math.pi / 2)).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * t, false, p);
  }
  @override
  bool shouldRepaint(_RingPainter o) => o.t != t || o.track != track;
}

class GradientHero extends StatelessWidget {
  final String title, subtitle; final List<Color> colors; final Widget? trailing;
  const GradientHero({super.key, required this.title, required this.subtitle, this.colors = const [], this.trailing});
  Widget _blob(double s, double a) => Container(width: s, height: s, decoration: BoxDecoration(color: Colors.white.withOpacity(a), shape: BoxShape.circle));
  @override
  Widget build(BuildContext context) {
    final cols = colors.isEmpty ? [C.violet, C.magenta] : colors;
    final t = Theme.of(context).textTheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(gradient: LinearGradient(colors: cols, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: cols.first.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))]),
      child: Stack(children: [
        Positioned(right: -30, top: -30, child: _blob(130, 0.14).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: -6, end: 8, duration: 2600.ms)),
        Positioned(left: -24, bottom: -44, child: _blob(110, 0.1).animate(onPlay: (c) => c.repeat(reverse: true)).moveX(begin: -6, end: 10, duration: 3200.ms)),
        Padding(padding: const EdgeInsets.all(22), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.15)),
            const SizedBox(height: 6),
            Text(subtitle, style: t.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.88), height: 1.35)),
          ])),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ])),
      ]),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 10), child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)));
}

Future<void> showProofSheet(BuildContext context, Hobby h) => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => ProofSheet(h));

enum _S { pick, checking, done, failed }

class ProofSheet extends StatefulWidget {
  final Hobby h;
  const ProofSheet(this.h, {super.key});
  @override
  State<ProofSheet> createState() => _ProofSheetState();
}

class _ProofSheetState extends State<ProofSheet> {
  _S s = _S.pick; String? path; String msg = ''; int gained = 0;

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 900, imageQuality: 80);
      if (x == null) return;
      setState(() { path = x.path; s = _S.checking; });
      final r = await ProofService.verify(x.path, widget.h.name);
      if (!mounted) return;
      if (r.ok) {
        final g = app.recordVerifiedSession(widget.h.minMinutes, r.hash!);
        setState(() { gained = g; msg = r.checked ? 'Spotted: ${r.matched}' : 'Photo accepted'; s = _S.done; });
      } else { setState(() { msg = r.message; s = _S.failed; }); }
    } catch (_) {
      if (!mounted) return;
      setState(() { msg = 'Could not open the camera or gallery. Check the app permissions and try again.'; s = _S.failed; });
    }
  }

  Widget _body(BuildContext context) {
    final t = Theme.of(context).textTheme;
    switch (s) {
      case _S.pick:
        return Column(key: const ValueKey('pick'), children: [
          Text('Show us your ${widget.h.name.toLowerCase()} session', textAlign: TextAlign.center, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Add a photo of you doing it. A verified photo keeps your streak alive and earns points.', textAlign: TextAlign.center, style: TextStyle(color: context.textMute, height: 1.4)),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_rounded), label: const Text('Camera'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton.tonalIcon(onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.image_rounded), label: const Text('Gallery'))),
          ]),
        ]);
      case _S.checking:
        return Column(key: const ValueKey('check'), children: [
          const SizedBox(height: 6), const CircularProgressIndicator(strokeWidth: 3), const SizedBox(height: 16),
          Text('Checking your photo', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 4),
          Text('Matching the activity and making sure it is a new photo', style: TextStyle(color: context.textMute)),
        ]);
      case _S.done:
        return Column(key: const ValueKey('done'), children: [
          Container(width: 64, height: 64, decoration: const BoxDecoration(color: C.mint, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 38)).animate().scale(begin: const Offset(0.4, 0.4), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 700.ms),
          const SizedBox(height: 14),
          Text('Verified  +$gained points', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('$msg. Streak: ${app.liveStreak} ${app.liveStreak == 1 ? "day" : "days"}', style: TextStyle(color: context.textMute)),
          const SizedBox(height: 18), FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ]);
      case _S.failed:
        return Column(key: const ValueKey('fail'), children: [
          // NOT const: C.coral is a getter.
          Container(width: 64, height: 64, decoration: BoxDecoration(color: C.coral, shape: BoxShape.circle), child: const Icon(Icons.priority_high_rounded, color: Colors.white, size: 36)).animate().shake(duration: 500.ms),
          const SizedBox(height: 14), Text('Not verified', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 6),
          Text(msg, textAlign: TextAlign.center, style: TextStyle(color: context.textMute, height: 1.4)), const SizedBox(height: 18),
          FilledButton(onPressed: () => setState(() => s = _S.pick), child: const Text('Try another photo')),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(color: context.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 42, height: 5, decoration: BoxDecoration(color: context.textMute.withOpacity(0.3), borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 18),
        if (path != null) ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(File(path!), height: 170, width: double.infinity, fit: BoxFit.cover)).animate().fadeIn(),
        if (path != null) const SizedBox(height: 16),
        AnimatedSwitcher(duration: const Duration(milliseconds: 280), child: _body(context)),
      ])),
    );
  }
}

// ============================================================================
// SPLASH SCREEN (waits for Firebase init + a minimum display time)
// ============================================================================

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.wait([bootFuture, Future<void>.delayed(const Duration(milliseconds: 1400))]).whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = themes[app.themeIndex];
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [t.a, t.b], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
              child: const Icon(Icons.explore_rounded, color: Colors.white, size: 50),
            ).animate().scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 700.ms).fadeIn(),
            const SizedBox(height: 20),
            Text('HobbyHub', style: GoogleFonts.plusJakartaSans(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 6),
            Text('Reclaim your time', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white70)).animate().fadeIn(delay: 350.ms),
          ]),
        ),
      ),
    );
  }
}

// ============================================================================
// ONBOARDING (shows on every launch, per request)
// ============================================================================

class Onboarding extends StatefulWidget {
  final VoidCallback onDone;
  const Onboarding({super.key, required this.onDone});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final _c = PageController();
  int _i = 0;
  static const _pages = [
    ('Find the hours you lose', 'See every app that eats your day, and how much you can win back.'),
    ('Pick a hobby that fits', 'Tell us your time, place, budget and mood. We suggest what you can start today.'),
    ('Prove it, keep the streak', 'Snap a photo of your session. A verified photo keeps your streak alive.'),
    ('See your real screen time', 'Allow usage access so HobbyHub can measure your time leaks. It stays on your phone.'),
  ];

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  Widget _art(int i) {
    if (i == 0) return TimeRing(value: 0.72, size: 200, center: Text('7 h', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)));
    final icons = [Icons.explore_rounded, Icons.photo_camera_rounded, Icons.shield_moon_rounded];
    final colors = [C.violet, C.coral, C.mint];
    final k = i - 1;
    return Container(
      width: 160, height: 160,
      decoration: BoxDecoration(gradient: LinearGradient(colors: [colors[k], Color.lerp(colors[k], Colors.white, 0.3)!], begin: Alignment.topLeft, end: Alignment.bottomRight), shape: BoxShape.circle, boxShadow: [BoxShadow(color: colors[k].withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 14))]),
      child: Icon(icons[k], size: 76, color: Colors.white),
    ).animate().scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), duration: 600.ms, curve: Curves.elasticOut).fadeIn();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _pages.length - 1;
    return Scaffold(
      body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(28, 12, 28, 28), child: Column(children: [
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: widget.onDone, child: const Text('Skip'))),
        Expanded(child: PageView.builder(
          controller: _c, itemCount: _pages.length, onPageChanged: (v) => setState(() => _i = v),
          itemBuilder: (_, i) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            _art(i), const SizedBox(height: 40),
            Text(_pages[i].$1, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)).animate().fadeIn(duration: 500.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 12),
            Text(_pages[i].$2, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: context.textMute, height: 1.45)).animate().fadeIn(delay: 150.ms, duration: 500.ms),
          ]),
        )),
        if (last) ...[
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () async { await UsageService.openSettings(); widget.onDone(); }, child: const Text('Allow usage access'))),
          TextButton(onPressed: widget.onDone, child: const Text('Maybe later')),
        ] else
          Row(children: [
            for (var k = 0; k < _pages.length; k++)
              AnimatedContainer(duration: const Duration(milliseconds: 250), margin: const EdgeInsets.only(right: 6), height: 8, width: k == _i ? 26 : 8, decoration: BoxDecoration(color: k == _i ? context.accent : context.textMute.withOpacity(0.3), borderRadius: BorderRadius.circular(8))),
            const Spacer(),
            FilledButton(onPressed: () => _c.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic), child: const Text('Next')),
          ]),
      ]))),
    );
  }
}

// ============================================================================
// SHELL
// ============================================================================

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _i = 1;
  static const _pages = [TimeScreen(), DiscoverScreen(), CirclesScreen(), CoachScreen(), RewardsScreen()];

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); app.refreshUsage(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) app.refreshUsage(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0,
        title: const Text('HobbyHub'),
        actions: [IconButton(icon: const Icon(Icons.settings_rounded), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())))],
      ),
      body: SafeArea(top: false, bottom: false, child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a), child: child)),
        child: KeyedSubtree(key: ValueKey(_i), child: _pages[_i]),
      )),
      bottomNavigationBar: Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 12), child: ClipRRect(borderRadius: BorderRadius.circular(28), child: NavigationBar(
        selectedIndex: _i, onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.hourglass_empty_rounded), selectedIcon: Icon(Icons.hourglass_bottom_rounded), label: 'Time'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_rounded), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'Circles'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome_rounded), label: 'Coach'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events_rounded), label: 'Rewards'),
        ],
      ))),
    );
  }
}

// ============================================================================
// TIME TAB - pie chart, bar chart, written advice
// ============================================================================

class TimeScreen extends StatelessWidget {
  const TimeScreen({super.key});

  // Getter (not const) because C.coral / C.violet / ... are theme getters.
  static Map<String, Color> get _catColor => {
    'Social media': C.coral, 'Video': C.violet, 'Games': C.sky, 'News': C.marigold,
    'Shopping': C.magenta, 'Productive': C.mint, 'Other': Colors.grey,
  };

  Widget _card(BuildContext context, Widget child) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(26)), child: child);

  List<String> _advice(BuildContext context) {
    final cat = app.categoryBreakdown;
    if (cat.values.every((v) => v == 0)) return ['No usage detected yet - advice will appear once there is data.'];
    final sorted = cat.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = cat.values.fold(0.0, (a, b) => a + b);
    final lines = <String>[];
    if (sorted.isNotEmpty) {
      final top = sorted.first;
      final share = (top.value / total * 100).round();
      lines.add('${top.key} is your single biggest leak at ${top.value.round()} min/day - that is $share% of all your tracked time.');
    }
    if (sorted.length > 1) {
      final combined = sorted.take(2).fold(0.0, (a, e) => a + e.value);
      lines.add('Your top 2 categories together add up to ${combined.round()} min/day. Cutting just those by half frees about ${(combined * 0.5 * 7 / 60).toStringAsFixed(1)} h/week.');
    }
    lines.add('At your current ${app.reduction.round()}% reduction target, you would free ${app.recoverableHoursPerWeek.toStringAsFixed(1)} h/week - roughly ${app.recoverableHoursPerWeek.toStringAsFixed(0)} hobby sessions of an hour each.');
    if (app.usageGranted && app.usageApps.isNotEmpty) {
      final worst = app.usageApps.first;
      lines.add('${worst.name} alone is ${worst.minutesPerDay.round()} min/day. ${UsageService.suggestionFor(worst)}');
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: app, builder: (context, _) {
      final colors = _catColor;
      final hours = app.recoverableHoursPerWeek;
      final cat = app.categoryBreakdown.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
      final apps = app.usageApps;
      final maxUse = apps.isEmpty ? 1.0 : apps.first.minutesPerDay;
      final total = cat.fold(0.0, (a, e) => a + e.value);
      final topApps = apps.take(6).toList();

      return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        GradientHero(title: 'Where your time goes', subtitle: app.usageGranted ? 'Full breakdown of this week\'s screen time.' : 'Connect your phone usage for a real, detailed report.', colors: [C.marigold, C.coral]),
        if (!app.usageGranted) ...[
          const SizedBox(height: 16),
          _card(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.shield_moon_rounded, color: C.violet), const SizedBox(width: 10), Text('Allow usage access', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))]),
            const SizedBox(height: 8),
            Text('HobbyHub reads how long you use each app (the same data as Digital Wellbeing). It is processed on your phone and never uploaded.', style: TextStyle(color: context.textMute, height: 1.4)),
            const SizedBox(height: 14), FilledButton(onPressed: UsageService.openSettings, child: const Text('Open settings')),
          ])).animate().fadeIn().slideY(begin: 0.1, end: 0),
        ],
        const SizedBox(height: 22),
        Center(child: TimeRing(value: hours / 14, center: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: hours), duration: const Duration(milliseconds: 900), builder: (_, v, __) => Text(v.toStringAsFixed(1), style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800))),
          Text('hours a week to win back', style: TextStyle(color: context.textMute)),
        ]))),

        const SectionTitle('Time by category'),
        if (cat.isEmpty)
          _card(context, Text('No data yet.', style: TextStyle(color: context.textMute)))
        else
          _card(context, Column(children: [
            SizedBox(height: 200, child: PieChart(PieChartData(
              sectionsSpace: 3, centerSpaceRadius: 44,
              sections: [for (final e in cat) PieChartSectionData(value: e.value, color: colors[e.key] ?? Colors.grey, radius: 54, title: '${(e.value / total * 100).round()}%', titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))],
            ))),
            const SizedBox(height: 16),
            Wrap(spacing: 14, runSpacing: 8, children: [for (final e in cat) Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[e.key] ?? Colors.grey, shape: BoxShape.circle)),
              const SizedBox(width: 6), Text('${e.key} (${e.value.round()}m)', style: Theme.of(context).textTheme.labelMedium),
            ])]),
          ])),

        if (app.usageGranted && apps.isNotEmpty) ...[
          const SectionTitle('Top apps'),
          _card(context, SizedBox(height: 220, child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxUse * 1.2,
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 38, getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= topApps.length) return const SizedBox();
                final name = topApps[i].name;
                return Padding(padding: const EdgeInsets.only(top: 6), child: Transform.rotate(angle: -0.5, child: Text(name.length > 8 ? '${name.substring(0, 8)}…' : name, style: const TextStyle(fontSize: 10))));
              })),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            barGroups: [for (var i = 0; i < topApps.length; i++) BarChartGroupData(x: i, barRods: [BarChartRodData(toY: topApps[i].minutesPerDay, color: colors[topApps[i].category] ?? C.violet, width: 20, borderRadius: BorderRadius.circular(6))])],
          )))),
          const SizedBox(height: 10),
          for (final e in apps) Container(
            margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[e.category] ?? Colors.grey, shape: BoxShape.circle)), const SizedBox(width: 8),
                Expanded(child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('${e.minutesPerDay.round()} min/day', style: TextStyle(color: context.textMute, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 3), Text(e.category, style: TextStyle(color: context.textMute, fontSize: 11.5)),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(8), child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: (e.minutesPerDay / maxUse).clamp(0.0, 1.0)), duration: const Duration(milliseconds: 700), builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 8, color: colors[e.category] ?? Colors.grey, backgroundColor: context.textMute.withOpacity(0.12)))),
              const SizedBox(height: 8), Text(UsageService.suggestionFor(e), style: TextStyle(color: context.textMute, fontSize: 12, height: 1.3)),
            ]),
          ),
        ] else if (!app.usageGranted) ...[
          const SectionTitle('Enter manually'),
          _card(context, Column(children: [for (final e in app.usage.entries) Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)), Text('${e.value.round()} min/day', style: TextStyle(color: context.textMute))]),
            Slider(value: e.value.clamp(0, 240).toDouble(), min: 0, max: 240, onChanged: (v) => app.setUsage(e.key, v)),
          ]))])),
        ],

        const SectionTitle('If you cut back'),
        _card(context, Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Reduce by', style: TextStyle(fontWeight: FontWeight.w700)), Text('${app.reduction.round()}%', style: TextStyle(color: context.accent, fontWeight: FontWeight.w800))]),
          Slider(value: app.reduction, min: 0, max: 100, onChanged: app.setReduction),
        ])),

        const SectionTitle('Advice'),
        _card(context, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final line in _advice(context)) Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.tips_and_updates_rounded, size: 18, color: C.marigold), const SizedBox(width: 8),
          Expanded(child: Text(line, style: TextStyle(color: context.textMute, height: 1.4))),
        ]))])),
      ]);
    });
  }
}

// ============================================================================
// DISCOVER TAB
// ============================================================================

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final q = Query();
  int _version = 0;
  bool _moreFilters = false;

  void _change(VoidCallback f) => setState(() { f(); _version++; });

  Widget _group(String title, List<String> options, bool Function(String) sel, void Function(String) tap, {String Function(String)? label}) {
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.textMute, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final o in options) ChoiceChip(label: Text(label?.call(o) ?? o), selected: sel(o), onSelected: (_) => tap(o))]),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: app, builder: (context, _) {
      q.interests = app.interests;
      final results = recommend(q);
      return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        const GradientHero(title: 'Pick something you will love', subtitle: '24 hobbies, filtered to your time, place, budget and mood.'),
        const SizedBox(height: 22),
        _group('Time you have', ['15', '30', '60', '90'], (o) => q.minutes == int.parse(o), (o) => _change(() => q.minutes = int.parse(o)), label: (o) => '$o min'),
        _group('Where', ['home', 'college', 'office', 'outdoor'], (o) => q.location == o, (o) => _change(() => q.location = o)),
        _group('When', ['morning', 'afternoon', 'evening', 'night', 'weekend'], (o) => q.timeOfDay == o, (o) => _change(() => q.timeOfDay = o)),
        _group('Into', ['creative', 'fitness', 'calm', 'outdoor', 'music', 'learning', 'strategy', 'social', 'writing', 'food', 'astronomy'], (o) => app.interests.contains(o), (o) { _version++; app.toggleInterest(o); }),
        TextButton.icon(onPressed: () => setState(() => _moreFilters = !_moreFilters), icon: Icon(_moreFilters ? Icons.expand_less_rounded : Icons.tune_rounded), label: Text(_moreFilters ? 'Fewer filters' : 'More filters')),
        if (_moreFilters) ...[
          Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Budget', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.textMute, fontWeight: FontWeight.w600)), Text(q.budget >= 10000 ? 'Any' : '₹${q.budget}', style: TextStyle(color: context.accent, fontWeight: FontWeight.w700))]),
            Slider(value: q.budget.toDouble(), min: 0, max: 10000, divisions: 20, onChanged: (v) => _change(() => q.budget = v.round())),
          ])),
          _group('Group size', ['1', '2', '3'], (o) => q.groupSize == int.parse(o), (o) => _change(() => q.groupSize = int.parse(o)), label: (o) => o == '1' ? 'Any' : (o == '2' ? 'With a partner' : 'Group')),
          _group('Setting', ['either', 'indoor', 'outdoor'], (o) => (o == 'either' && q.indoorOnly == null) || (o == 'indoor' && q.indoorOnly == true) || (o == 'outdoor' && q.indoorOnly == false), (o) => _change(() => q.indoorOnly = o == 'either' ? null : o == 'indoor')),
          Padding(padding: const EdgeInsets.only(bottom: 6), child: SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Only hobbies that build a skill', style: TextStyle(fontWeight: FontWeight.w600)), value: q.skillGrowthOnly, onChanged: (v) => _change(() => q.skillGrowthOnly = v))),
        ],
        const SizedBox(height: 4),
        if (results.isEmpty)
          Padding(padding: const EdgeInsets.all(28), child: Text('Nothing fits yet. Try more time, a higher budget, or another place.', textAlign: TextAlign.center, style: TextStyle(color: context.textMute))).animate().fadeIn()
        else
          for (var i = 0; i < results.length; i++) _HobbyCard(results[i]).animate(key: ValueKey('${results[i].name}-$_version')).fadeIn(delay: (60 * i).ms, duration: 380.ms).slideY(begin: 0.12, end: 0, delay: (60 * i).ms, curve: Curves.easeOutCubic),
      ]);
    });
  }
}

class _HobbyCard extends StatelessWidget {
  final Hobby h;
  const _HobbyCard(this.h);
  Widget _pill(BuildContext c, String t, Color col) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: col.withOpacity(0.14), borderRadius: BorderRadius.circular(20)), child: Text(t, style: Theme.of(c).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)));

  @override
  Widget build(BuildContext context) {
    final col = h.color();
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(26), boxShadow: [BoxShadow(color: col.withOpacity(0.16), blurRadius: 18, offset: const Offset(0, 8))]),
      child: Row(children: [
        Container(width: 58, height: 58, decoration: BoxDecoration(gradient: LinearGradient(colors: [col, Color.lerp(col, Colors.white, 0.3)!], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(19)), child: Icon(h.icon, color: Colors.white, size: 28)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(h.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [_pill(context, '${h.minMinutes} min+', col), _pill(context, h.costInr == 0 ? 'Free' : '₹${h.costInr}', col), if (h.groupSize > 1) _pill(context, h.groupSize == 2 ? 'Pair' : 'Group', col), if (h.equipment.isNotEmpty) _pill(context, h.equipment.first, col)]),
        ])),
        const SizedBox(width: 8),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: col, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)), onPressed: () => showProofSheet(context, h), child: const Icon(Icons.photo_camera_rounded, size: 22)),
      ]),
    );
  }
}

// ============================================================================
// COACH TAB
// ============================================================================

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _Msg { final bool mine; String text; _Msg(this.mine, this.text); }

class _CoachScreenState extends State<CoachScreen> {
  final Coach coach = OfflineCoach();
  final _msgs = <_Msg>[];
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  static const _suggestions = ['₹2,000 and one free hour every evening', 'Something outdoor for the weekend', '30 minutes at night, no budget'];

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _busy) return;
    _ctl.clear();
    final reply = _Msg(false, '');
    setState(() { _busy = true; _msgs..add(_Msg(true, text))..add(reply); });
    await for (final chunk in coach.reply(text)) { if (!mounted) return; setState(() => reply.text += chunk); if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent); }
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() { _ctl.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: GradientHero(title: 'Your hobby coach', subtitle: 'Ask about time, budget or a first step. It answers on your phone.', colors: const [C.mint, C.sky])),
      Expanded(child: _msgs.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [for (final s in _suggestions) Padding(padding: const EdgeInsets.only(bottom: 8), child: ActionChip(label: Text(s), onPressed: () => _send(s)))]).animate().fadeIn(duration: 500.ms)))
          : ListView.builder(controller: _scroll, padding: const EdgeInsets.fromLTRB(18, 12, 18, 8), itemCount: _msgs.length, itemBuilder: (_, i) {
        final m = _msgs[i];
        return Align(alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(gradient: m.mine ? LinearGradient(colors: [C.violet, C.magenta]) : null, color: m.mine ? null : context.cardColor, borderRadius: BorderRadius.circular(20)),
          child: m.text.isEmpty ? const _Dots() : Text(m.text, style: TextStyle(color: m.mine ? Colors.white : null, height: 1.4)),
        ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1, end: 0));
      })),
      Padding(padding: const EdgeInsets.fromLTRB(14, 6, 14, 10), child: Row(children: [
        Expanded(child: TextField(controller: _ctl, onSubmitted: _send, decoration: InputDecoration(hintText: 'Ask about a hobby', filled: true, fillColor: context.cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)))),
        const SizedBox(width: 8), IconButton.filled(onPressed: _busy ? null : () => _send(_ctl.text), icon: const Icon(Icons.arrow_upward_rounded)),
      ])),
    ]);
  }
}

class _Dots extends StatelessWidget {
  const _Dots();
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < 3; i++) Container(margin: const EdgeInsets.symmetric(horizontal: 2), width: 7, height: 7, decoration: BoxDecoration(color: context.textMute, shape: BoxShape.circle)).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.25, end: 1, delay: (i * 160).ms, duration: 500.ms)]);
}

// ============================================================================
// REWARDS TAB
// ============================================================================

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});
  static const _all = [
    ('First proof', Icons.photo_camera_rounded, 'Verify your first session'),
    ('3-day streak', Icons.local_fire_department_rounded, 'Verify 3 days in a row'),
    ('7-day streak', Icons.whatshot_rounded, 'Verify 7 days in a row'),
    ('First 100', Icons.stars_rounded, 'Reach 100 points'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: app, builder: (context, _) {
      final t = Theme.of(context).textTheme;
      final progress = app.points == 0 ? 0.0 : (app.points / app.nextLevelAt).clamp(0.0, 1.0);
      final today = DateTime.now(); final base = DateTime(today.year, today.month, today.day);
      return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        GradientHero(title: app.level, subtitle: '${app.points} points. Next level at ${app.nextLevelAt}.', colors: [C.coral, C.marigold], trailing: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 46)),
        const SizedBox(height: 16),
        TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: progress), duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic, builder: (_, v, __) => ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: v, minHeight: 10, color: C.coral, backgroundColor: context.textMute.withOpacity(0.15)))),
        const SizedBox(height: 18),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(26)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.local_fire_department_rounded, color: C.coral, size: 42), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${app.liveStreak} day streak', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(app.doneToday ? 'Verified today. Nice work.' : 'Verify a session with a photo to keep it going.', style: TextStyle(color: context.textMute)),
          ]))]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (var i = 6; i >= 0; i--) Builder(builder: (_) {
            final d = base.subtract(Duration(days: i)); final on = app.doneOn(d); const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
            return Column(children: [
              AnimatedContainer(duration: const Duration(milliseconds: 400), width: 34, height: 34, decoration: BoxDecoration(gradient: on ? LinearGradient(colors: [C.coral, C.marigold]) : null, color: on ? null : context.textMute.withOpacity(0.14), shape: BoxShape.circle), child: on ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null),
              const SizedBox(height: 4), Text(names[d.weekday - 1], style: TextStyle(color: context.textMute, fontSize: 11)),
            ]);
          })]),
        ])).animate().fadeIn().slideY(begin: 0.1, end: 0),
        const SectionTitle('Badges'),
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.35, children: [for (final b in _all) Container(
          padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(22), border: app.badges.contains(b.$1) ? Border.all(color: C.marigold, width: 2) : null),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(b.$2, size: 30, color: app.badges.contains(b.$1) ? C.marigold : context.textMute.withOpacity(0.5)), const SizedBox(height: 8),
            Text(b.$1, style: const TextStyle(fontWeight: FontWeight.w800)), Text(b.$3, style: TextStyle(color: context.textMute, fontSize: 11.5)),
          ]),
        )]),
      ]);
    });
  }
}

// ============================================================================
// SETTINGS SCREEN
// ============================================================================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _tile(BuildContext context, {required IconData icon, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: context.accent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(color: context.textMute)),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded) : null),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(listenable: app, builder: (context, _) {
        return ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 10, 20, 6), child: Text('Appearance', style: TextStyle(fontWeight: FontWeight.w800))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < themes.length; i++) _ThemeSwatch(index: i, selected: app.themeIndex == i)])),
          const SizedBox(height: 6),
          _tile(context, icon: Icons.brightness_6_rounded, title: 'Display mode', subtitle: {ThemeMode.system: 'Match phone', ThemeMode.light: 'Light', ThemeMode.dark: 'Dark'}[app.mode],
              trailing: SegmentedButton<ThemeMode>(
                segments: const [ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded)), ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded)), ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded))],
                selected: {app.mode}, showSelectedIcon: false, onSelectionChanged: (s) => app.setMode(s.first),
              )),
          const Divider(height: 28),
          const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 6), child: Text('Data', style: TextStyle(fontWeight: FontWeight.w800))),
          _tile(context, icon: Icons.shield_moon_rounded, title: 'Usage access', subtitle: app.usageGranted ? 'Connected' : 'Not connected', onTap: UsageService.openSettings),
          _tile(context, icon: Icons.restart_alt_rounded, title: 'Reset local progress', subtitle: 'Clears points, streak and badges on this phone', onTap: () async {
            final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Reset progress?'), content: const Text('This clears your points, streak and badges on this phone. This cannot be undone.'), actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Reset')),
            ]));
            if (ok == true) await app.resetProgress();
          }),
          const Divider(height: 28),
          const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 6), child: Text('Account', style: TextStyle(fontWeight: FontWeight.w800))),
          const AccountSection(), // defined in firebase_circles.dart
          const Divider(height: 28),
          const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 6), child: Text('About', style: TextStyle(fontWeight: FontWeight.w800))),
          _tile(context, icon: Icons.info_outline_rounded, title: 'HobbyHub AI', subtitle: 'Version 1.0.0 - semester project, VIT Pune'),
        ]);
      }),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final int index; final bool selected;
  const _ThemeSwatch({required this.index, required this.selected});
  @override
  Widget build(BuildContext context) {
    final t = themes[index];
    return GestureDetector(
      onTap: () => app.setTheme(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), width: 78, padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(18), border: selected ? Border.all(color: t.a, width: 2.5) : null),
        child: Column(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(gradient: LinearGradient(colors: [t.a, t.b]), shape: BoxShape.circle), child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null),
          const SizedBox(height: 6), Text(t.name, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ============================================================================
// APP ROOT
// ============================================================================

enum _Stage { splash, onboarding, shell }

class HobbyHubApp extends StatefulWidget {
  const HobbyHubApp({super.key});
  @override
  State<HobbyHubApp> createState() => _HobbyHubAppState();
}

class _HobbyHubAppState extends State<HobbyHubApp> {
  _Stage stage = _Stage.splash;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: app, builder: (context, _) {
      final t = themes[app.themeIndex];
      return MaterialApp(
        title: 'HobbyHub',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light, t),
        darkTheme: buildTheme(Brightness.dark, t),
        themeMode: app.mode,
        home: AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: switch (stage) {
          _Stage.splash => SplashScreen(key: const ValueKey('splash'), onDone: () => setState(() => stage = _Stage.onboarding)),
          _Stage.onboarding => Onboarding(key: const ValueKey('onboarding'), onDone: () => setState(() => stage = _Stage.shell)),
          _Stage.shell => const Shell(key: ValueKey('shell')),
        }),
      );
    });
  }
}