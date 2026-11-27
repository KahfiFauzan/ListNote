import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'todo_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ListNoteApp());
}

// Authentication persists across application restarts via Firebase Auth.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        if (user == null) return const AuthPage();
        // Key prevents a signed-out user's subscriptions/state from leaking to
        // the next signed-in user on the same device.
        return ListNoteShell(key: ValueKey(user.uid), user: user);
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose(); _password.dispose(); _name.dispose(); super.dispose();
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final auth = FirebaseAuth.instance;
      if (_register) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _password.text,
        );
        final display = _name.text.trim();
        if (display.isNotEmpty) await credential.user?.updateDisplayName(display);
        if (credential.user != null) {
          final repository = CloudRepository(credential.user!.uid);
          await repository.ensureProfile(
            display.isEmpty ? 'ListNote User' : display,
            credential.user!.email,
          );
          // Update even if AuthGate created the profile first.
          if (display.isNotEmpty) await repository.saveName(display);
        }
      } else {
        await auth.signInWithEmailAndPassword(
          email: _email.text.trim(), password: _password.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _authMessage(e.code));
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal terhubung. Periksa internet dan konfigurasi Firebase.');
      debugPrint('Email authentication failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final address = _email.text.trim();
    if (!address.contains('@')) {
      setState(() => _error = 'Isi alamat email dahulu untuk reset password.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: address);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jika email terdaftar, instruksi reset akan dikirim.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Reset password belum berhasil. Coba lagi.');
    }
  }

  Future<void> _googleLogin() async {
    setState(() { _busy = true; _error = null; });
    try {
      UserCredential credential;
      if (kIsWeb) {
        credential = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        final signIn = GoogleSignIn.instance;
        await signIn.initialize();
        final account = await signIn.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) throw StateError('Google ID token tidak ditemukan');
        credential = await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }
      final user = credential.user;
      if (user != null) {
        await CloudRepository(user.uid).ensureProfile(user.displayName ?? 'ListNote User', user.email);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _authMessage(e.code));
    } catch (e) {
      if (mounted) setState(() => _error = 'Login Google gagal. Periksa provider Google, SHA-1/SHA-256, dan OAuth Firebase.');
      debugPrint('Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _authMessage(String code) => switch (code) {
    'email-already-in-use' => 'Email sudah terdaftar. Silakan login.',
    'invalid-email' => 'Format email tidak valid.',
    'weak-password' => 'Password terlalu lemah (minimal 6 karakter).',
    'invalid-credential' || 'wrong-password' || 'user-not-found' => 'Email atau password salah.',
    'network-request-failed' => 'Periksa koneksi internet kamu.',
    _ => 'Autentikasi gagal ($code).',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const CircleAvatar(radius: 32, backgroundColor: AppColors.pale,
              child: Icon(Icons.edit_note_rounded, size: 36, color: AppColors.blue)),
          const SizedBox(height: 20),
          const Text('ListNote.', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 6),
          Text(_register ? 'Buat akun untuk menyimpan ide di cloud.' : 'Masuk dan lanjutkan ide kamu di perangkat apa pun.',
              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 32),
          if (_register) ...[
            TextFormField(controller: _name, maxLength: 40, decoration: const InputDecoration(labelText: 'Nama tampilan'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Masukkan nama' : null),
            const SizedBox(height: 8),
          ],
          TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none, decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) => v == null || !v.contains('@') ? 'Masukkan email yang valid' : null),
          const SizedBox(height: 16),
          TextFormField(controller: _password, obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            validator: (v) => v == null || v.length < 6 ? 'Minimal 6 karakter' : null),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red)), const SizedBox(height: 12),
          ],
          FilledButton(onPressed: _busy ? null : _submitEmail,
            style: FilledButton.styleFrom(backgroundColor: AppColors.blue, padding: const EdgeInsets.all(16)),
            child: Text(_busy ? 'Memproses...' : (_register ? 'Buat Akun' : 'Masuk'))),
          if (!_register) Align(alignment: Alignment.centerRight,
            child: TextButton(onPressed: _busy ? null : _resetPassword,
              child: const Text('Lupa password?'))),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _busy ? null : _googleLogin,
            icon: const Icon(Icons.account_circle_outlined), label: const Text('Lanjutkan dengan Google')),
          TextButton(onPressed: _busy ? null : () => setState(() { _register = !_register; _error = null; }),
            child: Text(_register ? 'Sudah punya akun? Login' : 'Belum punya akun? Daftar')),
          const SizedBox(height: 12),
          const Text('Akun Google tidak membutuhkan password ListNote terpisah.',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
      )),
    ))),
  );
}

class CloudRepository {
  CloudRepository(this.uid);
  final String uid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get profile => _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> get notes => profile.collection('notes');
  CollectionReference<Map<String, dynamic>> get tasks => profile.collection('tasks');
  CollectionReference<Map<String, dynamic>> get noteCategories => profile.collection('note_categories');

  Future<void> ensureProfile(String name, String? email) async {
    final snapshot = await profile.get();
    if (!snapshot.exists) {
      await profile.set({'displayName': name, 'email': email ?? '',
        'createdAt': FieldValue.serverTimestamp()});
    }
  }
  Future<void> saveName(String name) => profile.set({'displayName': name}, SetOptions(merge: true));
}

class AppColors {
  static const background = Color(0xFFF5F8FF);
  static const navy = Color(0xFF142544);
  static const blue = Color(0xFF2563EB);
  static const muted = Color(0xFF62718A);
  static const pale = Color(0xFFDBEAFE);
  static const border = Color(0xFFE7EDFA);
}

class ListNoteApp extends StatelessWidget {
  const ListNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ListNote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontSize: 24, height: 1.3, fontWeight: FontWeight.w600, color: AppColors.navy),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.navy),
          titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.navy),
          bodyMedium: TextStyle(fontSize: 14, color: AppColors.muted),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class Note {
  Note({required this.id, required this.title, required this.body, required this.category, required this.updatedAt, this.pinned = false});
  final String id;
  String title;
  String body;
  String category;
  DateTime updatedAt;
  bool pinned;
}

class Todo {
  Todo(this.id, this.title, this.when, {this.done = false, this.status = 'pending'});
  final String id;
  String title;
  String when;
  bool done;
  String status;
}

class ListNoteShell extends StatefulWidget {
  const ListNoteShell({super.key, required this.user});
  final User user;
  @override
  State<ListNoteShell> createState() => _ListNoteShellState();
}

class _ListNoteShellState extends State<ListNoteShell> {
  late final CloudRepository repository;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tasksSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _noteCategoriesSub;
  final noteCategoryNames = <String>['Personal', 'Work'];
  final _customNoteCategories = <String>[];
  String userName = 'ListNote User';
  String? loadError;
  int tab = 0;
  String query = '';
  String category = 'All notes';
  final notes = <Note>[];
  final todos = <Todo>[];

  @override
  void initState() {
    super.initState();
    repository = CloudRepository(widget.user.uid);
    userName = widget.user.displayName?.trim().isNotEmpty == true
        ? widget.user.displayName!.trim() : 'ListNote User';
    _bindCloud();
  }

  void _bindCloud() {
    repository.ensureProfile(userName, widget.user.email).catchError((Object error) {
      if (mounted) setState(() => loadError = 'Tidak bisa memuat profil. Periksa Firestore Rules.');
    });
    _profileSub = repository.profile.snapshots().listen((snapshot) {
      final name = snapshot.data()?['displayName'];
      if (mounted && name is String && name.trim().isNotEmpty) setState(() => userName = name.trim());
    }, onError: (Object error) => _cloudError(error));
    _notesSub = repository.notes.snapshots().listen((snapshot) {
      final loaded = snapshot.docs.map((d) {
        final v = d.data();
        return Note(id: d.id, title: v['title'] as String? ?? '',
          body: v['body'] as String? ?? '', category: v['category'] as String? ?? 'Personal',
          pinned: v['pinned'] as bool? ?? false,
          updatedAt: (v['updatedAt'] is Timestamp) ? (v['updatedAt'] as Timestamp).toDate() : DateTime.now());
      }).toList();
      if (mounted) setState(() {
        notes..clear()..addAll(loaded);
        final names = <String>{'Personal', 'Work', ..._customNoteCategories, ...loaded.map((e) => e.category)}.toList()..sort();
        noteCategoryNames..clear()..addAll(names);
        loadError = null;
      });
    }, onError: (Object error) => _cloudError(error));
    _noteCategoriesSub = repository.noteCategories.snapshots().listen((snapshot) {
      final names = <String>{'Personal', 'Work'};
      for (final doc in snapshot.docs) {
        final value = doc.data()['name'];
        if (value is String && value.trim().isNotEmpty) names.add(value.trim());
      }
      _customNoteCategories..clear()..addAll(names.where((n) => n != 'Personal' && n != 'Work'));
      for (final note in notes) { names.add(note.category); }
      if (mounted) setState(() {
        noteCategoryNames..clear()..addAll(names.toList()..sort());
      });
    }, onError: (Object error) => _cloudError(error));
    _tasksSub = repository.tasks.snapshots().listen((snapshot) {
      final loaded = snapshot.docs.map((d) {
        final v = d.data();
        final status = v['status'] as String? ?? (v['done'] == true ? 'done' : 'pending');
        return Todo(d.id, v['title'] as String? ?? '', v['when'] as String? ?? 'Today',
          done: status == 'done', status: status);
      }).toList();
      if (mounted) setState(() { todos..clear()..addAll(loaded); loadError = null; });
    }, onError: (Object error) => _cloudError(error));
  }

  void _cloudError(Object error) {
    debugPrint('Firestore error: $error');
    if (mounted) setState(() => loadError = 'Cloud sync gagal. Periksa internet dan Firestore Rules.');
  }

  @override
  void dispose() {
    _profileSub?.cancel(); _notesSub?.cancel(); _tasksSub?.cancel(); _noteCategoriesSub?.cancel();
    super.dispose();
  }

  Future<bool> _updateUserName(String value) async {
    final name = value.trim();
    if (name.isEmpty || name.length > 40) return false;
    try {
      await repository.saveName(name);
      if (mounted) setState(() => userName = name);
      return true;
    } catch (e) { _cloudError(e); return false; }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => SettingsPage(userName: userName, email: widget.user.email ?? '',
          onSaveName: _updateUserName, onLogout: () async {
            await FirebaseAuth.instance.signOut();
            if (!kIsWeb) { try { await GoogleSignIn.instance.signOut(); } catch (_) {} }
          }),
    ));
  }

  Future<void> _write(Future<void> Function() work) async {
    try { await work(); }
    catch (e) {
      _cloudError(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan ke cloud. Cek koneksi dan izin Firestore.')));
    }
  }

  void showTab(int value) => setState(() { tab = value; query = ''; category = 'All notes'; });

  Future<void> editNote([Note? current]) async {
    final result = await Navigator.of(context).push<NoteDraft>(MaterialPageRoute(
      builder: (_) => NoteEditorPage(note: current, categories: noteCategoryNames),
    ));
    if (result == null || !mounted) return;
    await _write(() async {
      final payload = <String, dynamic>{
        'title': result.title, 'body': result.body, 'category': result.category,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (current == null) {
        await repository.notes.add({...payload, 'pinned': false});
      } else {
        await repository.notes.doc(current.id).update(payload);
      }
      if (mounted) setState(() => tab = 1);
    });
  }

  Future<void> addTask() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New task'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'What needs to be done?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Add task')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || value == null || value.isEmpty) return;
    await _write(() async { await repository.tasks.add({'title': value, 'when': 'Today', 'done': false, 'updatedAt': FieldValue.serverTimestamp()}); if (mounted) setState(() => tab = 2); });
  }

  Future<void> addNoteCategory() async {
    final controller = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tambah Kategori Notes'),
          content: TextField(
            controller: controller, autofocus: true, maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Contoh: Kuliah, Ide, Belanja'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Tambah')),
          ],
        ),
      );
      if (!mounted || name == null) return;
      if (name.isEmpty || noteCategoryNames.any((c) => c.toLowerCase() == name.toLowerCase())) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama kategori kosong atau sudah ada.')));
        return;
      }
      await _write(() => repository.noteCategories.add({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      }).then((_) {}));
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 350), controller.dispose);
    }
  }

  Future<void> renameNoteCategory(String oldName) async {
    if (oldName == 'Personal' || oldName == 'Work') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kategori bawaan Personal dan Work tidak dapat diganti namanya.')));
      return;
    }
    final controller = TextEditingController(text: oldName);
    try {
      final renamed = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Edit Kategori Notes'),
          content: TextField(controller: controller, maxLength: 40, autofocus: true,
              decoration: const InputDecoration(labelText: 'Nama baru')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Simpan')),
          ],
        ),
      );
      if (!mounted || renamed == null || renamed == oldName) return;
      if (renamed.isEmpty || noteCategoryNames.any((c) => c.toLowerCase() == renamed.toLowerCase())) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama kategori tidak valid atau sudah ada.')));
        return;
      }
      await _write(() async {
        final matching = await repository.noteCategories.where('name', isEqualTo: oldName).get();
        if (matching.docs.isEmpty) return;
        final noteDocs = await repository.notes.where('category', isEqualTo: oldName).get();
        // One batch is limited to 500 writes. Use individual writes to keep
        // this safe for categories with a large number of notes.
        await matching.docs.first.reference.update({'name': renamed});
        for (final doc in noteDocs.docs) {
          await doc.reference.update({'category': renamed, 'updatedAt': FieldValue.serverTimestamp()});
        }
        if (mounted && category == oldName) setState(() => category = renamed);
      });
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 350), controller.dispose);
    }
  }

  Future<void> deleteNoteCategory(String name) async {
    if (name == 'Personal' || name == 'Work') return;
    if (notes.any((note) => note.category == name)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pindahkan catatan dari kategori ini sebelum menghapusnya.')));
      return;
    }
    final approved = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus kategori?'),
      content: Text('Kategori "$name" akan dihapus.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
      ],
    ));
    if (approved != true) return;
    await _write(() async {
      final docs = await repository.noteCategories.where('name', isEqualTo: name).get();
      for (final doc in docs.docs) { await doc.reference.delete(); }
      if (mounted && category == name) setState(() => category = 'All notes');
    });
  }

  Future<void> manageNoteCategories() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: repository.noteCategories.snapshots(),
          builder: (context, snapshot) {
            final custom = snapshot.data?.docs ?? [];
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Expanded(child: Text('Kategori Notes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                IconButton(tooltip: 'Tambah kategori', onPressed: addNoteCategory, icon: const Icon(Icons.add_circle_outline)),
              ]),
              const ListTile(title: Text('Personal'), subtitle: Text('Kategori bawaan')),
              const ListTile(title: Text('Work'), subtitle: Text('Kategori bawaan')),
              SizedBox(height: 260, child: ListView(
                children: custom.map((doc) {
                  final name = doc.data()['name'] as String? ?? '';
                  return ListTile(
                    title: Text(name),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(tooltip: 'Edit', onPressed: () => renameNoteCategory(name), icon: const Icon(Icons.edit_outlined)),
                      IconButton(tooltip: 'Hapus', onPressed: () => deleteNoteCategory(name), icon: const Icon(Icons.delete_outline)),
                    ]),
                  );
                }).toList(),
              )),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: addNoteCategory, icon: const Icon(Icons.add), label: const Text('Tambah Kategori'),
              )),
            ]);
          },
        ),
      )),
    );
  }

  List<Note> get visibleNotes {
    final items = notes.where((n) =>
      (category == 'All notes' || n.category == category) &&
      (query.trim().isEmpty || '${n.title} ${n.body}'.toLowerCase().contains(query.trim().toLowerCase()))).toList();
    items.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (tab) {
      0 => homeContent(),
      1 => notesContent(),
      2 => const TodoPage(),
      _ => libraryContent(),
    };
    return Scaffold(
      body: SafeArea(child: Column(children: [
        if (loadError != null) MaterialBanner(content: Text(loadError!), actions: [TextButton(onPressed: () => setState(() => loadError = null), child: const Text('Tutup'))]),
        Expanded(child: content),
      ])),
      floatingActionButton: tab == 0 || tab == 1
          ? Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: FloatingActionButton(
                onPressed: () => editNote(),
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.add_rounded, size: 28),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.pale,
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? AppColors.blue : AppColors.muted,
          )),
        ),
        child: NavigationBar(
          height: 72,
          selectedIndex: tab,
          onDestinationSelected: showTab,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description_rounded), label: 'Notes'),
            NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle_rounded), label: 'Tasks'),
            NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder_rounded), label: 'Library'),
          ],
        ),
      ),
    );
  }

  Widget homeContent() {
    final done = todos.where((task) => task.done).length;
    final total = todos.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
      children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_todayLabel(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.muted)),
            const SizedBox(height: 6),
            Text('Good morning, $userName', style: Theme.of(context).textTheme.headlineSmall),
          ])),
          IconButton.filledTonal(onPressed: _openSettings, icon: const Icon(Icons.settings_outlined), style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.navy)),
        ]),
        const SizedBox(height: 20),
        InkWell(onTap: () => showTab(1), borderRadius: BorderRadius.circular(16), child: searchBox('Search your thoughts')),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('A LITTLE CLARITY, EVERY DAY', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(children: [
              const Expanded(child: Text('Make space for\nwhat matters.', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600, height: 1.14))),
              Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Text('$done of $total tasks complete', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              const Spacer(),
              SizedBox(width: 72, child: LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 4, borderRadius: BorderRadius.circular(10), color: const Color(0xFF75A4FF), backgroundColor: Colors.white24)),
            ]),
          ]),
        ),
        const SizedBox(height: 24),
        sectionHeading('Pinned for you', 'All notes', () => showTab(1)),
        const SizedBox(height: 14),
        if (notes.any((n) => n.pinned))
          noteCard(notes.firstWhere((n) => n.pinned))
        else
          const EmptyCard(message: 'Pin a note to see it here.'),
        const SizedBox(height: 24),
        sectionHeading('Your next small step', 'Tasks', () => showTab(2)),
        const SizedBox(height: 12),
        if (todos.any((t) => t.status == 'pending')) taskCard(todos.firstWhere((t) => t.status == 'pending'))
        else const EmptyCard(message: 'All tasks completed. Nice work!'),
      ],
    );
  }

  Widget sectionHeading(String title, String link, VoidCallback onTap) => Row(children: [
    Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
    TextButton(onPressed: onTap, child: Text(link, style: const TextStyle(color: AppColors.blue, fontSize: 12))),
  ]);

  Widget searchBox(String hint) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
    child: Row(children: [const Icon(Icons.search_rounded, size: 20, color: AppColors.muted), const SizedBox(width: 12), Text(hint, style: const TextStyle(color: AppColors.muted, fontSize: 14))]),
  );

  Widget noteCard(Note n) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppColors.border)),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => editNote(n),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppColors.pale, borderRadius: BorderRadius.circular(10)), child: Text(n.category, style: const TextStyle(fontSize: 11, color: AppColors.blue, fontWeight: FontWeight.w600))),
          const Spacer(),
          IconButton(visualDensity: VisualDensity.compact, constraints: const BoxConstraints(minWidth: 32, minHeight: 32), onPressed: () => _write(() => repository.notes.doc(n.id).update({'pinned': !n.pinned})), icon: Icon(n.pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 18, color: n.pinned ? AppColors.blue : AppColors.muted)),
        ]),
        const SizedBox(height: 8),
        Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.navy, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(n.body, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 8),
        Text('Edited ${formatTime(n.updatedAt)}', style: const TextStyle(color: AppColors.muted, fontSize: 10)),
      ])),
    ),
  );

  Widget taskCard(Todo todo) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
    child: ListTile(
      onTap: () => showTab(2),
      leading: Icon(todo.status == 'done' ? Icons.check_circle :
        todo.status == 'cancelled' ? Icons.cancel : Icons.remove_circle_outline,
        color: todo.status == 'done' ? const Color(0xFF059669) :
          todo.status == 'cancelled' ? const Color(0xFFDC2626) : AppColors.blue),
      title: Text(todo.title, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(todo.status == 'done' ? 'Selesai' : todo.status == 'cancelled' ? 'Dibatalkan' : 'Belum selesai',
        style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
    ),
  );

  Widget notesContent() => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('YOUR THOUGHTS, COLLECTED', style: TextStyle(fontSize: 10, letterSpacing: 1.4, color: AppColors.muted, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: Text('All notes', style: Theme.of(context).textTheme.headlineSmall)), Text('${notes.length} notes', style: const TextStyle(color: AppColors.muted))]),
      const SizedBox(height: 16),
      TextField(onChanged: (v) => setState(() => query = v), decoration: InputDecoration(hintText: 'Find a note', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(16)), contentPadding: const EdgeInsets.symmetric(vertical: 13))),
      const SizedBox(height: 14),
      Row(children: [
        const Expanded(child: Text('Kategori catatan', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy))),
        TextButton.icon(onPressed: manageNoteCategories, icon: const Icon(Icons.tune, size: 16), label: const Text('Kelola')),
        IconButton(onPressed: addNoteCategory, tooltip: 'Tambah kategori', icon: const Icon(Icons.add_circle_outline, color: AppColors.blue)),
      ]),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['All notes', ...noteCategoryNames].map((value) {
        final selected = value == category;
        return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(value), selected: selected, selectedColor: AppColors.blue, backgroundColor: Colors.white, showCheckmark: false, labelStyle: TextStyle(color: selected ? Colors.white : AppColors.muted), onSelected: (_) => setState(() => category = value)));
      }).toList())),
    ])),
    Expanded(child: visibleNotes.isEmpty ? const Center(child: Text('No notes found. Add your first note.')) : ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 100), itemCount: visibleNotes.length, separatorBuilder: (_, _) => const SizedBox(height: 12), itemBuilder: (_, i) => noteCard(visibleNotes[i]),
    )),
  ]);

  Widget tasksContent() => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 12), child: Row(children: [Expanded(child: Text('Your next steps', style: Theme.of(context).textTheme.headlineSmall)), Text('${todos.where((t) => t.done).length}/${todos.length}', style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600))])),
    Expanded(child: ListView.separated(padding: const EdgeInsets.fromLTRB(24, 12, 24, 100), itemCount: todos.length, separatorBuilder: (_, _) => const SizedBox(height: 12), itemBuilder: (_, i) => taskCard(todos[i]))),
  ]);

  Widget libraryContent() => ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 24), children: [
    Text('Library', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 8), const Text('Your thoughts, neatly organized.', style: TextStyle(color: AppColors.muted)),
    const SizedBox(height: 24),
    OutlinedButton.icon(onPressed: manageNoteCategories, icon: const Icon(Icons.folder_open), label: const Text('Kelola Kategori Notes')),
    const SizedBox(height: 12),
    ...noteCategoryNames.map((value) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: ListTile(
        leading: const Icon(Icons.folder_outlined, color: AppColors.blue),
        title: Text(value), subtitle: Text('${notes.where((n) => n.category == value).length} notes'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => setState(() { tab = 1; category = value; query = ''; }),
      )),
    )),
    const SizedBox(height: 12),
    OutlinedButton.icon(onPressed: _openSettings, icon: const Icon(Icons.settings_outlined), label: const Text('Settings')),
  ]);
}

String _todayLabel() {
  final now = DateTime.now();
  const days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
  const months = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
  return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
}

String formatTime(DateTime date) {
  final delta = DateTime.now().difference(date);
  if (delta.inMinutes < 1) return 'just now';
  if (delta.inHours < 1) return '${delta.inMinutes} min ago';
  if (delta.inDays < 1) return '${delta.inHours} hours ago';
  return '${delta.inDays} days ago';
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)), child: Text(message, style: const TextStyle(color: AppColors.muted)));
}

class NoteDraft {
  const NoteDraft(this.title, this.body, this.category);
  final String title;
  final String body;
  final String category;
}

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, this.note, required this.categories});
  final Note? note;
  final List<String> categories;
  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController titleController;
  late final TextEditingController bodyController;
  late String category;
  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.note?.title ?? '');
    bodyController = TextEditingController(text: widget.note?.body ?? '');
    category = widget.note?.category ?? 'Personal';
  }
  @override
  void dispose() { titleController.dispose(); bodyController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(backgroundColor: AppColors.background, title: Text(widget.note == null ? 'New note' : 'Edit note'), actions: [
      TextButton(onPressed: () {
        final title = titleController.text.trim();
        if (title.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title'))); return; }
        Navigator.pop(context, NoteDraft(title, bodyController.text.trim(), category));
      }, child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.blue))),
    ]),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('CATEGORY', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: AppColors.muted)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: {...widget.categories, category}.map((value) => ChoiceChip(label: Text(value), selected: category == value, selectedColor: AppColors.pale, onSelected: (_) => setState(() => category = value))).toList()),
      const SizedBox(height: 18),
      TextField(controller: titleController, maxLines: null, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.navy), decoration: const InputDecoration(hintText: 'A thought worth keeping', border: InputBorder.none)),
      const Divider(color: AppColors.border),
      TextField(controller: bodyController, minLines: 12, maxLines: null, keyboardType: TextInputType.multiline, style: const TextStyle(fontSize: 16, height: 1.6, color: AppColors.navy), decoration: const InputDecoration(hintText: 'Start writing...', border: InputBorder.none)),
    ])),
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.userName, required this.email, required this.onSaveName, required this.onLogout});

  final String userName;
  final String email;
  final Future<bool> Function(String newName) onSaveName;
  final Future<void> Function() onLogout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 40) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name must contain 1–40 characters.')),
      );
      return;
    }
    setState(() => _saving = true);
    final saved = await widget.onSaveName(name);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your name. Try again.')),
      );
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings'), backgroundColor: AppColors.background),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('LISTNOTE', style: TextStyle(color: AppColors.blue, letterSpacing: 2, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Make it yours.', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.person_outline, color: AppColors.blue),
            SizedBox(width: 10),
            Text('Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.navy)),
          ]),
          const SizedBox(height: 18),
          Text('Email: ${widget.email}', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          const Text('Display name', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) { if (!_saving) _saveName(); },
            decoration: InputDecoration(
              hintText: 'Enter your name',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: _saving ? null : _saveName,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save name'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
          )),
          const SizedBox(height: 10),
          const Text('Your name is saved in your private Firestore profile and syncs across devices.', style: TextStyle(color: AppColors.muted, height: 1.5, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Elegant Blue', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy)),
          SizedBox(height: 8),
          Text('Notes and tasks sync with Cloud Firestore under your account.', style: TextStyle(color: AppColors.muted, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(onPressed: () async {
        await widget.onLogout();
        if (context.mounted) Navigator.of(context).pop();
      }, icon: const Icon(Icons.logout), label: const Text('Logout')),
    ])),
  );
}
