import 'package:flutter_test/flutter_test.dart';
import 'package:listnote/main.dart';

void main() {
  group('ListNote models', () {
    test('a new Todo starts as pending', () {
      final task = Todo('task-1', 'Plan the week', 'Today');
      expect(task.id, 'task-1');
      expect(task.title, 'Plan the week');
      expect(task.done, isFalse);
      expect(task.status, 'pending');
    });

    test('a Todo supports completed status', () {
      final task = Todo('task-2', 'Review notes', 'Today',
          done: true, status: 'done');
      expect(task.done, isTrue);
      expect(task.status, 'done');
    });

    test('a Todo supports cancelled status', () {
      final task = Todo('task-3', 'Old task', 'Today', status: 'cancelled');
      expect(task.status, 'cancelled');
      expect(task.done, isFalse);
    });
  });
}
