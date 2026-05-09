import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/models/task_model.dart';

class TasksNotifier extends StateNotifier<AsyncValue<List<TaskModel>>> {
  TasksNotifier() : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      if (!SupabaseService.instance.isConfigured ||
          !SupabaseService.instance.isLoggedIn) {
        state = const AsyncValue.data([]);
        return;
      }
      final res = await SupabaseService.instance.client
          .from('tasks')
          .select()
          .order('due_date', ascending: true)
          .order('due_time', ascending: true);
      final list = (res as List)
          .map((m) => TaskModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add({
    required String title,
    String? description,
    DateTime? dueDate,
    String? dueTime,
    String? category,
    String? routineId,
  }) async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;
    await SupabaseService.instance.client.from('tasks').insert({
      'user_id': user.id,
      'title': title,
      'description': description,
      'due_date': dueDate?.toIso8601String().substring(0, 10),
      'due_time': dueTime,
      'category': category,
      'routine_id': routineId,
    });
    await NotificationService.instance.scheduleTaskReminder(
      title: title,
      dueDate: dueDate,
      dueTime: dueTime,
    );
    await fetch();
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    await SupabaseService.instance.client
        .from('tasks')
        .update(patch)
        .eq('id', id);
    await fetch();
  }

  Future<void> toggle(TaskModel task) async {
    await SupabaseService.instance.client
        .from('tasks')
        .update({'completed': !task.completed}).eq('id', task.id);
    await fetch();
  }

  Future<void> delete(String id) async {
    await SupabaseService.instance.client.from('tasks').delete().eq('id', id);
    await fetch();
  }
}

final tasksProvider =
    StateNotifierProvider<TasksNotifier, AsyncValue<List<TaskModel>>>(
        (ref) => TasksNotifier());

final todayTasksProvider = Provider<List<TaskModel>>((ref) {
  final tasks = ref
      .watch(tasksProvider)
      .maybeWhen(data: (l) => l, orElse: () => <TaskModel>[]);
  final today = DateTime.now();
  return tasks.where((t) {
    if (t.dueDate == null) return false;
    return t.dueDate!.year == today.year &&
        t.dueDate!.month == today.month &&
        t.dueDate!.day == today.day;
  }).toList();
});
