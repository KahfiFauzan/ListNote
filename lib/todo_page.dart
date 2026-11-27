import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// A standalone, realtime To-Do page for a signed-in ListNote user.
/// Firestore paths: users/{uid}/tasks/{taskId}, users/{uid}/categories/{categoryId}.
class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  String? _selectedCategoryId;
  bool _showCompleted = true;

  User? get _user => FirebaseAuth.instance.currentUser;
  CollectionReference<Map<String, dynamic>> get _tasks => FirebaseFirestore.instance
      .collection('users').doc(_user!.uid).collection('tasks');
  CollectionReference<Map<String, dynamic>> get _categories => FirebaseFirestore.instance
      .collection('users').doc(_user!.uid).collection('categories');

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editTask({DocumentSnapshot<Map<String, dynamic>>? task}) async {
    final initial = task?.data() ?? {};
    final titleController = TextEditingController(text: (initial['title'] as String?) ?? '');
    final detailController = TextEditingController(text: (initial['description'] as String?) ?? '');
    String? categoryId = initial['categoryId'] as String?;
    bool saving = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, updateDialog) => AlertDialog(
            title: Text(task == null ? 'Tambah To-Do' : 'Edit To-Do'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      maxLength: 120,
                      decoration: const InputDecoration(labelText: 'Nama tugas *'),
                    ),
                    TextField(
                      controller: detailController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(labelText: 'Deskripsi (opsional)'),
                    ),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _categories.orderBy('name').snapshots(),
                      builder: (context, snapshot) {
                        final docs = snapshot.data?.docs ?? [];
                        final ids = docs.map((e) => e.id).toSet();
                        final validSelection = ids.contains(categoryId) ? categoryId : null;
                        return DropdownButtonFormField<String>(
                          key: ValueKey('${task?.id ?? 'new'}-${docs.length}-$validSelection'),
                          initialValue: validSelection ?? '',
                          decoration: const InputDecoration(labelText: 'Kategori'),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('Tanpa kategori')),
                            ...docs.map((doc) => DropdownMenuItem(
                              value: doc.id,
                              child: Text(doc.data()['name'] as String? ?? 'Kategori'),
                            )),
                          ],
                          onChanged: (value) => updateDialog(() => categoryId = value == '' ? null : value),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Batal')),
              FilledButton(
                onPressed: saving ? null : () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    _showMessage('Nama tugas tidak boleh kosong');
                    return;
                  }
                  updateDialog(() => saving = true);
                  try {
                    final values = <String, dynamic>{
                      'title': title,
                      'description': detailController.text.trim(),
                      'categoryId': categoryId,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };
                    if (task == null) {
                      await _tasks.add({
                        ...values,
                        'done': false,
                        'status': 'pending',
                        'when': 'Today',
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                    } else {
                      await _tasks.doc(task.id).update(values);
                    }
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (e) {
                    _showMessage('Gagal menyimpan tugas: $e');
                    if (dialogContext.mounted) updateDialog(() => saving = false);
                  }
                },
                child: Text(saving ? 'Menyimpan...' : 'Simpan'),
              ),
            ],
          ),
        ),
      );
    } finally {
      // Allow the dialog route's closing animation to finish before disposal.
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        titleController.dispose();
        detailController.dispose();
      });
    }
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    bool saving = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, updateDialog) => AlertDialog(
            title: const Text('Tambah Kategori'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 50,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama kategori',
                hintText: 'Contoh: Kuliah, Kerja, Pribadi',
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Batal')),
              FilledButton(
                onPressed: saving ? null : () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) {
                    _showMessage('Nama kategori tidak boleh kosong');
                    return;
                  }
                  updateDialog(() => saving = true);
                  try {
                    final existing = await _categories.where('name', isEqualTo: name).limit(1).get();
                    if (existing.docs.isNotEmpty) {
                      _showMessage('Kategori sudah ada');
                      if (dialogContext.mounted) updateDialog(() => saving = false);
                      return;
                    }
                    await _categories.add({
                      'name': name,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (e) {
                    _showMessage('Gagal menambah kategori: $e');
                    if (dialogContext.mounted) updateDialog(() => saving = false);
                  }
                },
                child: const Text('Tambah'),
              ),
            ],
          ),
        ),
      );
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 350), controller.dispose);
    }
  }

  // Rename the category document. Tasks keep the same categoryId, so they
  // automatically display the new name without rewriting every task.
  Future<void> _renameCategory(DocumentSnapshot<Map<String, dynamic>> item) async {
    final controller = TextEditingController(text: item.data()?['name'] as String? ?? '');
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Edit nama kategori'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 50,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama kategori'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Simpan')),
          ],
        ),
      );
      if (name == null || !mounted) return;
      if (name.isEmpty) { _showMessage('Nama kategori tidak boleh kosong'); return; }
      try {
        final existing = await _categories.where('name', isEqualTo: name).get();
        if (existing.docs.any((doc) => doc.id != item.id)) {
          _showMessage('Nama kategori sudah digunakan');
          return;
        }
        await _categories.doc(item.id).update({
          'name': name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _showMessage('Kategori berhasil diubah');
      } catch (e) { _showMessage('Gagal mengubah kategori: $e'); }
    } finally {
      // Dispose after the dialog's closing transition.
      Future<void>.delayed(const Duration(milliseconds: 350), controller.dispose);
    }
  }

  Future<void> _deleteCategory(DocumentSnapshot<Map<String, dynamic>> item) async {
    try {
      final linked = await _tasks.where('categoryId', isEqualTo: item.id).limit(1).get();
      if (linked.docs.isNotEmpty) {
        _showMessage('Pindahkan atau hapus tugas dalam kategori ini dahulu.');
        return;
      }
    } catch (e) { _showMessage('Gagal memeriksa kategori: $e'); return; }
    if (!mounted) return;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus kategori?'),
        content: Text('Kategori "${item.data()?['name'] ?? ''}" akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (agreed != true) return;
    try {
      await _categories.doc(item.id).delete();
      if (mounted && _selectedCategoryId == item.id) {
        setState(() => _selectedCategoryId = null);
      }
    } catch (e) { _showMessage('Gagal menghapus kategori: $e'); }
  }

  Future<void> _manageCategories() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Expanded(child: Text('Kelola Kategori', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                IconButton(tooltip: 'Tambah kategori', onPressed: _addCategory, icon: const Icon(Icons.add_circle_outline)),
              ]),
              SizedBox(
                height: 320,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _categories.orderBy('name').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Text('Gagal memuat kategori: ${snapshot.error}');
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final categories = snapshot.data!.docs;
                    if (categories.isEmpty) return const Center(child: Text('Belum ada kategori. Tekan + untuk menambah.'));
                    return ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (_, index) {
                        final item = categories[index];
                        return ListTile(
                          leading: const Icon(Icons.folder_outlined, color: Color(0xFF2563EB)),
                          title: Text(item.data()['name'] as String? ?? 'Kategori'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(tooltip: 'Edit kategori', icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _renameCategory(item)),
                            IconButton(tooltip: 'Hapus kategori', icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteCategory(item)),
                          ]),
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _addCategory, icon: const Icon(Icons.add), label: const Text('Tambah Kategori'),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTask(DocumentSnapshot<Map<String, dynamic>> task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus tugas?'),
        content: const Text('Tugas yang dihapus tidak bisa dikembalikan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _tasks.doc(task.id).delete();
    } catch (e) {
      _showMessage('Gagal menghapus tugas: $e');
    }
  }

  Future<void> _setTaskStatus(DocumentSnapshot<Map<String, dynamic>> task, String status) async {
    try {
      await _tasks.doc(task.id).update({
        'done': status == 'done',
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _showMessage('Gagal mengubah status tugas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: Text('Masuk akun untuk menggunakan To-Do List.')));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F8FF),
        title: const Text('To-Do List', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Kelola kategori',
            onPressed: _manageCategories,
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'Tambah kategori',
            onPressed: _addCategory,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editTask(),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Tugas'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _categories.orderBy('name').snapshots(),
        builder: (context, categoriesSnapshot) {
          if (categoriesSnapshot.hasError) {
            return Center(child: Text('Gagal memuat kategori: ${categoriesSnapshot.error}'));
          }
          final categories = categoriesSnapshot.data?.docs ?? [];
          final names = <String, String>{for (final doc in categories) doc.id: doc.data()['name'] as String? ?? 'Kategori'};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 58,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    _categoryChip('Semua', null),
                    ...categories.map((doc) => _categoryChip(names[doc.id]!, doc.id)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('Tampilkan yang selesai'),
                    const Spacer(),
                    Switch(
                      value: _showCompleted,
                      onChanged: (value) => setState(() => _showCompleted = value),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _tasks.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Gagal memuat tugas: ${snapshot.error}', textAlign: TextAlign.center),
                      ));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final all = snapshot.data!.docs.toList()..sort((a, b) {
                      final aTime = a.data()['updatedAt'];
                      final bTime = b.data()['updatedAt'];
                      final aDate = aTime is Timestamp ? aTime.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                      final bDate = bTime is Timestamp ? bTime.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                      return bDate.compareTo(aDate);
                    });
                    final visible = all.where((doc) {
                      final data = doc.data();
                      final completed = _taskStatus(data) == 'done';
                      return (_showCompleted || !completed) &&
                          (_selectedCategoryId == null || data['categoryId'] == _selectedCategoryId);
                    }).toList();
                    final completedCount = all.where((e) => _taskStatus(e.data()) == 'done').length;
                    if (visible.isEmpty) {
                      return Center(child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.checklist_rounded, size: 64, color: Color(0xFF2563EB)),
                          const SizedBox(height: 12),
                          const Text('Belum ada tugas di sini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('Total selesai: $completedCount dari ${all.length} tugas'),
                        ]),
                      ));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                      itemCount: visible.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('$completedCount dari ${all.length} tugas selesai',
                                style: const TextStyle(color: Color(0xFF64748B))),
                          );
                        }
                        final doc = visible[index - 1];
                        final data = doc.data();
                        final status = _taskStatus(data);
                        final completed = status == 'done';
                        final description = data['description'] as String? ?? '';
                        final categoryName = names[data['categoryId']] ?? 'Tanpa kategori';
                        return Card(
                          color: Colors.white,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: ListTile(
                              leading: Icon(
                                status == 'done' ? Icons.check_circle_rounded :
                                status == 'cancelled' ? Icons.cancel_rounded : Icons.remove_circle_outline_rounded,
                                color: status == 'done' ? const Color(0xFF059669) :
                                  status == 'cancelled' ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                              ),
                              title: Text(data['title'] as String? ?? 'Tugas',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    decoration: status == 'done' || status == 'cancelled' ? TextDecoration.lineThrough : null,
                                    color: completed ? Colors.grey : const Color(0xFF142544),
                                  )),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (description.isNotEmpty) Text(description),
                                  Text(categoryName,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
                                  const SizedBox(height: 6),
                                  Row(children: [
                                    _statusButton(doc, 'pending', Icons.remove, 'Belum selesai', const Color(0xFF64748B), status),
                                    const SizedBox(width: 5),
                                    _statusButton(doc, 'done', Icons.check, 'Selesai', const Color(0xFF059669), status),
                                    const SizedBox(width: 5),
                                    _statusButton(doc, 'cancelled', Icons.close, 'Dibatalkan', const Color(0xFFDC2626), status),
                                  ]),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                tooltip: 'Opsi tugas',
                                onSelected: (action) {
                                  if (action == 'edit') _editTask(task: doc);
                                  if (action == 'delete') _deleteTask(doc);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Preserve compatibility with tasks created before tri-state support.
  String _taskStatus(Map<String, dynamic> data) {
    final status = data['status'];
    if (status == 'done' || status == 'pending' || status == 'cancelled') return status as String;
    return data['done'] == true ? 'done' : 'pending';
  }

  Widget _statusButton(DocumentSnapshot<Map<String, dynamic>> task, String value,
      IconData icon, String tooltip, Color color, String current) {
    final selected = current == value;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _setTaskStatus(task, value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : const Color(0xFFF1F5F9),
            border: Border.all(color: selected ? color : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }

  Widget _categoryChip(String label, String? categoryId) {
    final selected = _selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: const Color(0xFFDBEAFE),
        onSelected: (_) => setState(() => _selectedCategoryId = categoryId),
      ),
    );
  }
}
