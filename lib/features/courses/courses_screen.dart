import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../data/models/models.dart';
import '../../widgets/common_widgets.dart';
import '../import_data/import_screen.dart';
import 'lesson_detail_screen.dart';

/// Lists all courses with full user control: create, rename, delete,
/// and navigation into lessons.
class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(coursesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        actions: [
          IconButton(
            tooltip: 'Import lessons',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ImportScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createCourseDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Course'),
      ),
      body: AsyncView<List<Course>>(
        value: courses,
        builder: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.school_outlined,
              title: 'No courses yet',
              message:
                  'Create a course for any language pair, or import lessons from a CSV or Excel file.',
              actionLabel: 'Import Lesson',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            itemBuilder: (ctx, i) => _courseCard(ctx, ref, list[i]),
          );
        },
      ),
    );
  }

  Widget _courseCard(BuildContext context, WidgetRef ref, Course course) {
    final lessons = ref.watch(lessonsProvider(course.id));
    return SectionCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CourseDetailScreen(courseId: course.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  course.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'rename') {
                    _renameCourseDialog(context, ref, course);
                  } else if (v == 'delete') {
                    _deleteCourse(context, ref, course);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
          lessons.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
            data: (ls) => Text(
              '${ls.length} lesson${ls.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createCourseDialog(BuildContext context, WidgetRef ref) async {
    final source = TextEditingController();
    final target = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: source,
              decoration: const InputDecoration(
                labelText: 'Source language (e.g. English)',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: target,
              decoration: const InputDecoration(
                labelText: 'Target language (e.g. Persian)',
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok == true && source.text.trim().isNotEmpty && target.text.trim().isNotEmpty) {
      await ref
          .read(repositoryProvider)
          .createCourse(source.text, target.text);
      ref.invalidate(coursesProvider);
    }
  }

  Future<void> _renameCourseDialog(
    BuildContext context,
    WidgetRef ref,
    Course course,
  ) async {
    final source = TextEditingController(text: course.sourceLang);
    final target = TextEditingController(text: course.targetLang);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: source,
              decoration: const InputDecoration(labelText: 'Source language'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: target,
              decoration: const InputDecoration(labelText: 'Target language'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true &&
        source.text.trim().isNotEmpty &&
        target.text.trim().isNotEmpty) {
      await ref
          .read(repositoryProvider)
          .renameCourse(course.id, source.text, target.text);
      ref.invalidate(coursesProvider);
    }
  }

  Future<void> _deleteCourse(
    BuildContext context,
    WidgetRef ref,
    Course course,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Delete course?',
      message:
          'Delete "${course.title}" and all its lessons, items, and progress? This action cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (ok) {
      await ref.read(repositoryProvider).deleteCourse(course.id);
      ref.invalidate(coursesProvider);
      refreshAfterStudy(ref);
    }
  }
}

/// Lessons inside one course with full lesson controls.
class CourseDetailScreen extends ConsumerWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseOfProvider(courseId));
    final lessons = ref.watch(lessonsProvider(courseId));
    return Scaffold(
      appBar: AppBar(
        title: Text(course.maybeWhen(
          data: (c) => c?.title ?? 'Course',
          orElse: () => 'Course',
        )),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createLessonDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Lesson'),
      ),
      body: AsyncView<List<Lesson>>(
        value: lessons,
        builder: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.book_outlined,
              title: 'No lessons yet',
              message:
                  'Add a lesson manually or import lessons from a CSV or Excel file.',
            );
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            onReorderItem: (oldI, newI) async {
              await ref
                  .read(repositoryProvider)
                  .moveLesson(courseId, oldI, newI);
              ref.invalidate(lessonsProvider(courseId));
            },
            itemBuilder: (ctx, i) {
              final lesson = list[i];
              return _lessonTile(ctx, ref, lesson, key: ValueKey(lesson.id));
            },
          );
        },
      ),
    );
  }

  Widget _lessonTile(
    BuildContext context,
    WidgetRef ref,
    Lesson lesson, {
    required Key key,
  }) {
    final counts = ref.watch(typeCountsProvider(lesson.id));
    final status = ref.watch(statusCountsProvider(lesson.id));
    return Card(
      key: key,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          lesson.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: counts.when(
          loading: () => const Text('…'),
          error: (_, _) => const SizedBox.shrink(),
          data: (c) {
            final total = (c['vocab'] ?? 0) +
                (c['sentence'] ?? 0) +
                (c['communication'] ?? 0);
            final mastered = status.maybeWhen(
              data: (s) => s['mastered'] ?? 0,
              orElse: () => 0,
            );
            return Text(
              '$total items · $mastered mastered',
            );
          },
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'rename') {
              _renameLessonDialog(context, ref, lesson);
            } else if (v == 'reset') {
              _resetLesson(context, ref, lesson);
            } else if (v == 'clear') {
              _clearLesson(context, ref, lesson);
            } else if (v == 'delete') {
              _deleteLessonWithConfirm(context, ref, lesson);
            } else if (v == 'export') {
              _exportLesson(context, ref, lesson);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Rename')),
            PopupMenuItem(value: 'export', child: Text('Export as CSV')),
            PopupMenuItem(value: 'reset', child: Text('Reset Progress')),
            PopupMenuItem(value: 'clear', child: Text('Clear Content')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LessonDetailScreen(lessonId: lesson.id),
          ),
        ),
      ),
    );
  }

  Future<void> _createLessonDialog(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Lesson'),
        content: TextField(
          controller: title,
          decoration: const InputDecoration(
            labelText: 'Lesson title (e.g. Basic Greetings)',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      await ref.read(repositoryProvider).createLesson(courseId, title.text);
      ref.invalidate(lessonsProvider(courseId));
      refreshAfterStudy(ref);
    }
  }

  Future<void> _renameLessonDialog(
    BuildContext context,
    WidgetRef ref,
    Lesson lesson,
  ) async {
    final title = TextEditingController(text: lesson.title);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Lesson'),
        content: TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Lesson title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      await ref.read(repositoryProvider).renameLesson(lesson.id, title.text);
      ref.invalidate(lessonsProvider(courseId));
    }
  }

  Future<void> _resetLesson(
    BuildContext context,
    WidgetRef ref,
    Lesson lesson,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Reset progress?',
      message:
          'Remove your learning progress for "${lesson.title}" but keep the lesson content? This action cannot be undone.',
      confirmLabel: 'Reset Progress',
      danger: false,
    );
    if (ok) {
      await ref.read(repositoryProvider).resetLessonProgress(lesson.id);
      ref.invalidate(statusCountsProvider(lesson.id));
      refreshAfterStudy(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress reset.')),
        );
      }
    }
  }

  Future<void> _clearLesson(
    BuildContext context,
    WidgetRef ref,
    Lesson lesson,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Clear lesson?',
      message:
          'Remove "${lesson.title}" and all its imported content? This action cannot be undone.',
      confirmLabel: 'Clear Lesson',
    );
    if (ok) {
      await ref.read(repositoryProvider).deleteLesson(lesson.id);
      ref.invalidate(lessonsProvider(courseId));
      refreshAfterStudy(ref);
    }
  }

  Future<void> _deleteLessonWithConfirm(
    BuildContext context,
    WidgetRef ref,
    Lesson lesson,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Delete lesson?',
      message:
          'Delete "${lesson.title}" and all its items and progress? This action cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (ok) {
      await ref.read(repositoryProvider).deleteLesson(lesson.id);
      ref.invalidate(lessonsProvider(courseId));
      refreshAfterStudy(ref);
    }
  }

  Future<void> _exportLesson(
    BuildContext context,
    WidgetRef ref,
    Lesson lesson,
  ) async {
    final path = await ref.read(repositoryProvider).exportLesson(lesson.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lesson exported to $path')),
      );
    }
  }
}
