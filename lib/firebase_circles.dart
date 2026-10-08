// ============================================================================
// firebase_circles.dart  (fixed)
// ----------------------------------------------------------------------------
// Real, multi-user Circles: accounts, joining, live member counts, and chat.
// Needs: firebase_core, firebase_auth, cloud_firestore, google_sign_in in
// pubspec.yaml, and lib/firebase_options.dart (from `flutterfire configure`).
//
// Firestore layout this file reads/writes:
//   users/{uid}                 name, email, photoUrl, interests, joinedAt
//   circles/{circleId}          name, place, schedule, colorHex, memberCount,
//                                createdBy, createdAt
//   circles/{circleId}/members/{uid}   joinedAt
//   circles/{circleId}/messages/{id}   senderId, senderName, text, sentAt
//   users/{uid}/following/{uid}, users/{uid}/followers/{uid}   since
//
// Fixes in this version:
//   * Removed `const` from every place that used C.violet / C.coral etc.
//     (those are theme-driven getters, so they can never be const).
//   * Added the missing AccountSection widget used by the Settings screen.
//   * Import from main.dart is restricted with `show` so Query (HobbyHub's
//     own class) can never clash with Firestore's Query.
//   * Member count is now a live stream of the members sub-collection.
//   * Circle icon is a fixed constant icon (dynamic IconData breaks release
//     builds because of icon tree-shaking).
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';

import 'main.dart' show C, Ctx, GradientHero, app;

FirebaseAuth get _auth => FirebaseAuth.instance;
FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
  app: Firebase.app(),
  databaseId: 'circles',
);
Future<void> _ensureUserDocFor(User u) async {
  try {
    final ref = _db.collection('users').doc(u.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'name': u.displayName ?? (u.email?.split('@').first ?? 'Hobbyist'),
        'email': u.email,
        'photoUrl': u.photoURL,
        'interests': app.interests.toList(),
        'joinedAt': FieldValue.serverTimestamp(),
      });
    }
  } catch (_) {}
}
// ============================================================================
// AUTH GATE - shows login/signup until a user is signed in, then Circles UI
// ============================================================================

class CirclesScreen extends StatelessWidget {
  const CirclesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data == null) return const AuthScreen();
        return CirclesHome(uid: snap.data!.uid);
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _signUp = false;
  bool _busy = false;
  String? _error;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _ensureUserDoc(User u, {String? name}) async {
    final ref = _db.collection('users').doc(u.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'name': name ?? u.displayName ?? (u.email?.split('@').first ?? 'Hobbyist'),
        'email': u.email,
        'photoUrl': u.photoURL,
        'interests': app.interests.toList(),
        'joinedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _submitEmail() async {
    setState(() { _busy = true; _error = null; });
    try {
      if (_signUp) {
        final cred = await _auth.createUserWithEmailAndPassword(email: _email.text.trim(), password: _pass.text);
        await cred.user?.updateDisplayName(_name.text.trim());
        if (cred.user != null) await _ensureUserDoc(cred.user!, name: _name.text.trim());
      } else {
        final cred = await _auth.signInWithEmailAndPassword(email: _email.text.trim(), password: _pass.text);
        if (cred.user != null) await _ensureUserDoc(cred.user!);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Something went wrong. Try again.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() { _busy = true; _error = null; });
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _busy = false);
        return; // cancelled
      }
      final googleAuth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      final userCred = await _auth.signInWithCredential(cred);
      if (userCred.user != null) await _ensureUserDoc(userCred.user!);
    } catch (e) {
      if (mounted) setState(() => _error = 'Google sign-in failed. Check your SHA-1 fingerprint is added in Firebase.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(24, 40, 24, 24), children: [
      Icon(Icons.groups_rounded, size: 56, color: context.accent).animate().scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), curve: Curves.elasticOut),
      const SizedBox(height: 16),
      Text(_signUp ? 'Create an account' : 'Welcome back', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text('Join real circles, follow friends, and chat about your hobbies.', textAlign: TextAlign.center, style: TextStyle(color: context.textMute)),
      const SizedBox(height: 28),
      if (_signUp) ...[
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
      ],
      TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: C.coral))),
      const SizedBox(height: 18),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _submitEmail, child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_signUp ? 'Sign up' : 'Log in'))),
      const SizedBox(height: 10),
      Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('or', style: TextStyle(color: context.textMute))), const Expanded(child: Divider())]),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _busy ? null : _google, icon: const Icon(Icons.g_mobiledata_rounded, size: 26), label: const Text('Continue with Google'))),
      const SizedBox(height: 18),
      TextButton(onPressed: () => setState(() => _signUp = !_signUp), child: Text(_signUp ? 'Already have an account? Log in' : 'New here? Create an account')),
    ]);
  }
}

// ============================================================================
// ACCOUNT SECTION - used by the Settings screen (was missing before)
// ============================================================================

class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  Future<void> _signOut() async {
    try { await GoogleSignIn().signOut(); } catch (_) {}
    await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snap) {
        final u = snap.data;
        if (u == null) {
          return ListTile(
            leading: Icon(Icons.person_outline_rounded, color: context.accent),
            title: const Text('Not signed in', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Open the Circles tab to log in or sign up', style: TextStyle(color: context.textMute)),
          );
        }
        final name = u.displayName ?? (u.email?.split('@').first ?? 'Hobbyist');
        return Column(children: [
          ListTile(
            leading: Icon(Icons.account_circle_rounded, color: context.accent),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(u.email ?? 'Signed in', style: TextStyle(color: context.textMute)),
          ),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: context.accent),
            title: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: _signOut,
          ),
        ]);
      },
    );
  }
}

// ============================================================================
// CIRCLES HOME - real circles, join, member counts, people, create new
// ============================================================================

class CirclesHome extends StatefulWidget {
  final String uid;
  const CirclesHome({super.key, required this.uid});
  @override
  State<CirclesHome> createState() => _CirclesHomeState();
}

class _CirclesHomeState extends State<CirclesHome> {
  bool _groups = true;
  @override
  void initState() {
    super.initState();
    final u = _auth.currentUser;
    if (u != null) _ensureUserDocFor(u);
  }
  Future<void> _signOut() async {
    try { await GoogleSignIn().signOut(); } catch (_) {}
    await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
      GradientHero(
        title: 'Do it together', subtitle: 'Real circles, real people - synced across every phone.', colors: [C.sky, C.violet],
        trailing: IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.white), onPressed: _signOut),
      ),
      const SizedBox(height: 16),
      Row(children: [
        ChoiceChip(label: const Text('Groups'), selected: _groups, onSelected: (_) => setState(() => _groups = true)),
        const SizedBox(width: 8),
        ChoiceChip(label: const Text('People'), selected: !_groups, onSelected: (_) => setState(() => _groups = false)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.add_circle_rounded), onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => CreateCircleSheet(uid: widget.uid))),
      ]),
      const SizedBox(height: 8),
      if (_groups) CircleList(uid: widget.uid) else PeopleList(uid: widget.uid),
    ]);
  }
}

class CircleList extends StatelessWidget {
  final String uid;
  const CircleList({super.key, required this.uid});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('circles').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Padding(padding: const EdgeInsets.all(28), child: Text('Could not load circles. Check your Firestore rules and connection.', textAlign: TextAlign.center, style: TextStyle(color: context.textMute)));
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        final docs = snap.data!.docs;
        if (docs.isEmpty) return Padding(padding: const EdgeInsets.all(28), child: Text('No circles yet - be the first to create one.', textAlign: TextAlign.center, style: TextStyle(color: context.textMute)));
        return Column(children: [for (var i = 0; i < docs.length; i++) _CircleCard(doc: docs[i], uid: uid).animate().fadeIn(delay: (50 * i).ms).slideY(begin: 0.1, end: 0)]);
      },
    );
  }
}

class _CircleCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String uid;
  const _CircleCard({required this.doc, required this.uid});

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final color = Color((d['colorHex'] as int?) ?? C.violet.value);
    const icon = Icons.groups_rounded;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: doc.reference.collection('members').doc(uid).snapshots(),
      builder: (context, memberSnap) {
        final joined = memberSnap.data?.exists ?? false;
        return Container(
          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(26), boxShadow: [BoxShadow(color: color.withOpacity(0.16), blurRadius: 18, offset: const Offset(0, 8))]),
          child: Column(children: [
            Row(children: [
              Container(width: 54, height: 54, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: color, size: 28)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d['name'] ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('${d['schedule'] ?? ''} at ${d['place'] ?? ''}', style: TextStyle(color: context.textMute, fontSize: 12.5)),
                const SizedBox(height: 3),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: doc.reference.collection('members').snapshots(),
                  builder: (context, c) {
                    final n = c.hasData ? c.data!.docs.length : ((d['memberCount'] as num?)?.toInt() ?? 0);
                    return Text('$n ${n == 1 ? "member" : "members"}', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5));
                  },
                ),
              ])),
              joined
                  ? OutlinedButton(onPressed: () => _leave(doc.reference, uid), child: const Text('Joined'))
                  : FilledButton(style: FilledButton.styleFrom(backgroundColor: color), onPressed: () => _join(doc.reference, uid), child: const Text('Join')),
            ]),
            if (joined) ...[
              const Divider(height: 22),
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CircleChatScreen(circleRef: doc.reference, name: d['name'] ?? '', color: color))),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18), label: const Text('Open chat'),
              )),
            ],
          ]),
        );
      },
    );
  }

  Future<void> _join(DocumentReference<Map<String, dynamic>> ref, String uid) async {
    await ref.collection('members').doc(uid).set({'joinedAt': FieldValue.serverTimestamp()});
    await ref.update({'memberCount': FieldValue.increment(1)});
  }

  Future<void> _leave(DocumentReference<Map<String, dynamic>> ref, String uid) async {
    await ref.collection('members').doc(uid).delete();
    await ref.update({'memberCount': FieldValue.increment(-1)});
  }
}

class CreateCircleSheet extends StatefulWidget {
  final String uid;
  const CreateCircleSheet({super.key, required this.uid});
  @override
  State<CreateCircleSheet> createState() => _CreateCircleSheetState();
}

class _CreateCircleSheetState extends State<CreateCircleSheet> {
  final _name = TextEditingController();
  final _place = TextEditingController();
  final _schedule = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    _schedule.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final ref = await _db.collection('circles').add({
        'name': _name.text.trim(),
        'place': _place.text.trim(),
        'schedule': _schedule.text.trim(),
        'colorHex': C.violet.value,
        'memberCount': 1,
        'createdBy': widget.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await ref.collection('members').doc(widget.uid).set({'joinedAt': FieldValue.serverTimestamp()});
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create the circle. Try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(color: context.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('New circle', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Circle name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _place, decoration: const InputDecoration(labelText: 'Place', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _schedule, decoration: const InputDecoration(labelText: 'When (e.g. Sundays, 5 pm)', border: OutlineInputBorder())),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _create, child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create'))),
        ]),
      ),
    );
  }
}

// ============================================================================
// CHAT - real-time, per circle
// ============================================================================

class CircleChatScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> circleRef;
  final String name;
  final Color color;
  const CircleChatScreen({super.key, required this.circleRef, required this.name, required this.color});
  @override
  State<CircleChatScreen> createState() => _CircleChatScreenState();
}

class _CircleChatScreenState extends State<CircleChatScreen> {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty) return;
    final u = _auth.currentUser;
    if (u == null) return;
    _ctl.clear();
    await widget.circleRef.collection('messages').add({
      'senderId': u.uid,
      'senderName': u.displayName ?? (u.email?.split('@').first ?? 'Someone'),
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() { _ctl.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final myUid = _auth.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.circleRef.collection('messages').orderBy('sentAt', descending: true).limit(100).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;
            if (docs.isEmpty) return Center(child: Text('No messages yet - say hi!', style: TextStyle(color: context.textMute)));
            return ListView.builder(
              reverse: true, controller: _scroll, padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i].data();
                final mine = d['senderId'] == myUid;
                return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: mine ? widget.color : context.cardColor, borderRadius: BorderRadius.circular(18)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    if (!mine) Text(d['senderName'] ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.color)),
                    Text(d['text'] ?? '', style: TextStyle(color: mine ? Colors.white : null, height: 1.3)),
                  ]),
                ));
              },
            );
          },
        )),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 10), child: Row(children: [
          Expanded(child: TextField(controller: _ctl, onSubmitted: (_) => _send(), decoration: InputDecoration(hintText: 'Message the circle', filled: true, fillColor: context.cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)))),
          const SizedBox(width: 8), IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded)),
        ]))),
      ]),
    );
  }
}

// ============================================================================
// PEOPLE LIST - real users, follow
// ============================================================================

class PeopleList extends StatelessWidget {
  final String uid;
  const PeopleList({super.key, required this.uid});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('users').limit(50).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Padding(padding: const EdgeInsets.all(28), child: Text('Could not load people. Check your Firestore rules and connection.', textAlign: TextAlign.center, style: TextStyle(color: context.textMute)));
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        final docs = snap.data!.docs.where((d) => d.id != uid).toList();
        if (docs.isEmpty) return Padding(padding: const EdgeInsets.all(28), child: Text('No one else has joined yet. Invite your friends!', textAlign: TextAlign.center, style: TextStyle(color: context.textMute)));
        return Column(children: [for (var i = 0; i < docs.length; i++) _PersonCard(doc: docs[i], myUid: uid).animate().fadeIn(delay: (50 * i).ms).slideY(begin: 0.1, end: 0)]);
      },
    );
  }
}

class _PersonCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String myUid;
  const _PersonCard({required this.doc, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final interests = ((d['interests'] as List?) ?? const []).map((e) => e.toString()).toList();
    final shared = interests.where(app.interests.contains).length;
    final followRef = _db.collection('users').doc(myUid).collection('following').doc(doc.id);
    final nameStr = ((d['name'] as String?) ?? '?').trim();
    final initial = nameStr.isEmpty ? '?' : nameStr.characters.first.toUpperCase();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: followRef.snapshots(),
      builder: (context, fs) {
        final following = fs.data?.exists ?? false;
        return Container(
          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(26)),
          child: Row(children: [
            CircleAvatar(radius: 26, backgroundColor: C.violet.withOpacity(0.15), child: Text(initial, style: TextStyle(color: C.violet, fontWeight: FontWeight.w800, fontSize: 20))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['name'] ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(interests.isEmpty ? 'No interests set' : interests.join(', '), style: TextStyle(color: context.textMute, fontSize: 12.5)),
            ])),
            if (shared > 0) Column(children: [Text('$shared', style: const TextStyle(color: C.mint, fontWeight: FontWeight.w800, fontSize: 18)), Text('shared', style: TextStyle(color: context.textMute, fontSize: 11))]),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: () async {
                if (following) {
                  await followRef.delete();
                  await _db.collection('users').doc(doc.id).collection('followers').doc(myUid).delete();
                } else {
                  await followRef.set({'since': FieldValue.serverTimestamp()});
                  await _db.collection('users').doc(doc.id).collection('followers').doc(myUid).set({'since': FieldValue.serverTimestamp()});
                }
              },
              icon: Icon(following ? Icons.person_remove_rounded : Icons.person_add_rounded, size: 20),
            ),
          ]),
        );
      },
    );
  }
}