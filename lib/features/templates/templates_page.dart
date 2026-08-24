import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/workout_template.dart';
import '../workout/workout_bloc.dart';
import 'template_bloc.dart';
import 'template_editor_page.dart';

class TemplatesPage extends StatelessWidget {
  const TemplatesPage({super.key, this.onBack});

  /// Provided when the page is reached from a home tile rather than the dock,
  /// so there is always a way back to Today.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<TemplateBloc, TemplateState>(
        builder: (context, state) => ListView(
          key: const Key('templates-page'),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: [
            if (onBack != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('templates-back-button'),
                  onPressed: onBack,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Today'),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              'Templates',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start repeat workouts without rebuilding them.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            BlocBuilder<WorkoutBloc, WorkoutState>(
              builder: (context, workout) => FilledButton.icon(
                key: const Key('save-template-button'),
                onPressed: workout.hasActiveSession
                    ? () => context.read<TemplateBloc>().add(
                        TemplateSavedFromWorkout(workout.session!),
                      )
                    : null,
                icon: const Icon(Icons.bookmark_add_rounded),
                label: const Text('Save current workout as template'),
              ),
            ),
            const SizedBox(height: 20),
            if (state.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (state.templates.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 36),
                child: Text(
                  'No templates yet. Start a workout, then save it here.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...state.templates.map(
                (template) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.fitness_center_rounded,
                          color: Color(0xffd7ff4f),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                template.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${template.exercises.length} exercises',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Duplicate template',
                          onPressed: () => context.read<TemplateBloc>().add(
                            TemplateDuplicated(template),
                          ),
                          icon: const Icon(Icons.copy_rounded),
                        ),
                        PopupMenuButton<String>(
                          key: ValueKey('template-menu-${template.id}'),
                          onSelected: (value) async {
                            if (value == 'favorite') {
                              context.read<TemplateBloc>().add(
                                TemplateFavoriteToggled(template),
                              );
                            } else if (value == 'edit') {
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TemplateEditorPage(template: template),
                                ),
                              );
                            } else if (value == 'delete') {
                              await _deleteTemplate(context, template);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'favorite',
                              child: ListTile(
                                leading: Icon(
                                  template.isFavorite
                                      ? Icons.star_outline_rounded
                                      : Icons.star_rounded,
                                ),
                                title: Text(
                                  template.isFavorite
                                      ? 'Remove from favorites'
                                      : 'Add to favorites',
                                ),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit_rounded),
                                title: Text('Edit template'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_outline_rounded),
                                title: Text('Delete template'),
                              ),
                            ),
                          ],
                        ),
                        FilledButton(
                          onPressed: () => context.read<WorkoutBloc>().add(
                            WorkoutStartedFromTemplate(template),
                          ),
                          child: const Text('Start'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Future<void> _deleteTemplate(
    BuildContext context,
    WorkoutTemplate template,
  ) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('“${template.title}” will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-delete-template-button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (delete == true && context.mounted) {
      context.read<TemplateBloc>().add(TemplateDeleted(template.id));
    }
  }
}
