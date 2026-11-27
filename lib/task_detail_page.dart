import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Detail tugas yang menggunakan dokumen tasks yang sama dengan TodoPage.
/// Sub-checklist disimpan sebagai list map: {title: String, done: bool}.
class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({super.key, required this.taskId});
  final String taskId;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  static const _background = Color(0xFFF5F8FF);
  static const _navy = Color(0xFF142544);
  static const _blue = Color(0xFF2563EB);
  bool _saving = false;

  DocumentReference<Map<String, dynamic>>? get _task {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users')
        .doc(user.uid).collection('tasks').doc(widget.taskId);
  }

  String _status(Map<String, dynamic> data) {
    final current = data['status'];
    if (current == 'done' || current == 'pending' || current == 'cancelled') {
      return current as String;
    }
    return data['done'] == true ? 'done' : 'pending';
  }

  List<Map<String, dynamic>> _steps(Map<String, dynamic> data) {
    final raw = data['steps'];
    if (raw is! List) return [];
    return raw.whereType<Map>().map((item) => <String, dynamic>{
      'title': (item['title'] ?? '').toString(),
      'done': item['done'] == true,
    }).where((item) => (item['title'] as String).isNotEmpty).toList();
  }

  Future<void> _update(Map<String, dynamic> data) async {
    final task = _task;
    if (task == null || _saving) return;
    setState(() => _saving = true);
    try {
      await task.update({...data, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan perubahan: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addStep(List<Map<String, dynamic>> existing) async {
    final controller = TextEditingController();
    try {
      final text = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Tambah langkah kecil'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 100,
            decoration: const InputDecoration(hintText: 'Contoh: Review tugas minggu lalu'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Tambah')),
          ],
        ),
      );
      if (!mounted || text == null || text.isEmpty) return;
      final steps = [...existing, {'title': text, 'done': false}];
      await _update({'steps': steps});
    } finally {
      // Biarkan animasi penutupan dialog selesai dahulu.
      Future<void>.delayed(const Duration(milliseconds: 350), controller.dispose);
    }
  }

  Future<void> _changeStep(List<Map<String, dynamic>> existing, int index, bool done) async {
    final steps = existing.map((e) => Map<String, dynamic>.from(e)).toList();
    steps[index]['done'] = done;
    await _update({'steps': steps});
  }

  Future<void> _editStep(List<Map<String, dynamic>> existing, int index) async {
    final controller = TextEditingController(text: existing[index]['title'] as String);
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Edit langkah'),
          content: TextField(controller: controller, autofocus: true, maxLength: 100),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Simpan')),
          ],
        ),
      );
      if (result == null || !mounted || result.isEmpty) return;
      final steps = existing.map((e) => Map<String, dynamic>.from(e)).toList();
      steps[index]['title'] = result;
      await _update({'steps': steps});
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 350), controller.dispose);
    }
  }

  Future<void> _removeStep(List<Map<String, dynamic>> existing, int index) async {
    final steps = existing.map((e) => Map<String, dynamic>.from(e)).toList()..removeAt(index);
    await _update({'steps': steps});
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;
    if (task == null) {
      return const Scaffold(body: Center(child: Text('Silakan login terlebih dahulu.')));
    }
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Task details', style: TextStyle(fontSize: 15, color: _navy)),
        backgroundColor: _background,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: task.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Gagal memuat tugas: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists) return const Center(child: Text('Tugas tidak ditemukan.'));
          final data = snapshot.data!.data()!;
          final title = (data['title'] as String?) ?? 'Untitled task';
          final description = (data['description'] as String?) ?? '';
          final when = (data['when'] as String?) ?? 'Today';
          final status = _status(data);
          final steps = _steps(data);
          final completedSteps = steps.where((s) => s['done'] == true).length;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  children: [
                    const Text('MY TASK', style: TextStyle(color: _blue,
                        fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.5)),
                    const SizedBox(height: 14),
                    Text(title, style: const TextStyle(fontSize: 30, height: 1.15,
                      color: _navy, fontWeight: FontWeight.w700)),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(description, style: const TextStyle(color: Color(0xFF6A7891), height: 1.55)),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(18)),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined, color: _blue, size: 19),
                        const SizedBox(width: 12),
                        Expanded(child: Text(when, style: const TextStyle(
                          color: _navy, fontWeight: FontWeight.w600))),
                        Text(status == 'done' ? 'Completed' :
                          status == 'cancelled' ? 'Cancelled' : 'Pending',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ]),
                    ),
                    const SizedBox(height: 32),
                    Row(children: [
                      Expanded(child: Text('The small steps',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold, color: _navy))),
                      Text('$completedSteps/${steps.length}',
                        style: const TextStyle(color: _blue, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 6),
                    const Text('Break a big task into small wins.',
                      style: TextStyle(color: Color(0xFF7B879A), fontSize: 12)),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(20)),
                      child: steps.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('Belum ada langkah kecil. Tambahkan checklist pertama.',
                              style: TextStyle(color: Color(0xFF64748B))),
                          )
                        : Column(children: [
                            for (var i = 0; i < steps.length; i++)
                              ListTile(
                                leading: Checkbox(
                                  value: steps[i]['done'] == true,
                                  activeColor: _blue,
                                  onChanged: _saving ? null : (value) =>
                                    _changeStep(steps, i, value ?? false),
                                ),
                                title: Text(steps[i]['title'] as String,
                                  style: TextStyle(
                                    color: _navy,
                                    decoration: steps[i]['done'] == true
                                      ? TextDecoration.lineThrough : null,
                                  )),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'edit') _editStep(steps, i);
                                    if (action == 'delete') _removeStep(steps, i);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                                  ],
                                ),
                              ),
                          ]),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => _addStep(steps),
                      icon: const Icon(Icons.add),
                      label: const Text('Add a small step'),
                    ),
                    const SizedBox(height: 14),
                    const Text('Give yourself a realistic amount of space.\nThe goal is intention, not a perfect schedule.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.55)),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _saving ? null : () => _update({
                        'status': status == 'done' ? 'pending' : 'done',
                        'done': status != 'done',
                      }),
                      style: FilledButton.styleFrom(backgroundColor: _blue),
                      child: Text(status == 'done' ? 'Mark as pending' : 'Mark as complete'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
