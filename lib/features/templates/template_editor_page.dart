import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/exercise.dart';
import '../../domain/workout_session.dart';
import '../../domain/workout_template.dart';
import '../library/exercise_media.dart';
import '../library/library_bloc.dart';
import 'template_bloc.dart';

class TemplateEditorPage extends StatefulWidget {
  const TemplateEditorPage({required this.template, super.key});

  final WorkoutTemplate template;

  @override
  State<TemplateEditorPage> createState() => _TemplateEditorPageState();
}

class _TemplateEditorPageState extends State<TemplateEditorPage> {
  late final TextEditingController _title = TextEditingController(
    text: widget.template.title,
  );
  late List<WorkoutExercise> _exercises = widget.template.exercises;
  int _sequence = 0;

  String _id() => '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final exercises = _exercises
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(position: entry.key))
        .toList(growable: false);
    context.read<TemplateBloc>().add(
      TemplateUpdated(
        WorkoutTemplate(
          id: widget.template.id,
          title: title.length > 60 ? title.substring(0, 60) : title,
          exercises: exercises,
          updatedAt: DateTime.now(),
          isFavorite: widget.template.isFavorite,
        ),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _addExercise() async {
    final exercise = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _TemplateExercisePicker(),
    );
    if (exercise == null || !mounted) return;
    setState(() {
      _exercises = [
        ..._exercises,
        WorkoutExercise(
          id: _id(),
          exerciseId: exercise.id,
          name: exercise.name,
          position: _exercises.length,
          sets: [
            WorkoutSet(
              id: _id(),
              exerciseId: exercise.id,
              position: 0,
              repetitions: 8,
            ),
          ],
        ),
      ];
    });
  }

  Future<void> _editExercise(int index) async {
    final edited = await showModalBottomSheet<WorkoutExercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _TemplateExerciseSheet(exercise: _exercises[index], newId: _id),
    );
    if (edited == null || !mounted) return;
    setState(
      () => _exercises = [
        for (var i = 0; i < _exercises.length; i++)
          if (i == index) edited else _exercises[i],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Edit template'),
      actions: [
        TextButton(
          key: const Key('save-template-editor-button'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: TextField(
            key: const Key('template-editor-name-field'),
            controller: _title,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            decoration: const InputDecoration(
              labelText: 'Routine name',
              counterText: '',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                '${_exercises.length} exercises',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                'Drag to reorder',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _exercises.isEmpty
              ? const Center(
                  child: Text('Add exercises to build this routine.'),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  itemCount: _exercises.length,
                  onReorderItem: (oldIndex, newIndex) => setState(() {
                    final moved = _exercises.removeAt(oldIndex);
                    _exercises.insert(newIndex, moved);
                  }),
                  itemBuilder: (context, index) {
                    final exercise = _exercises[index];
                    final sets = exercise.sets;
                    final target = sets.isEmpty ? null : sets.first;
                    return Padding(
                      key: ValueKey(exercise.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle_rounded),
                          ),
                          title: Text(
                            exercise.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${sets.length} sets'
                            '${target == null ? '' : ' · ${target.repetitions} reps'}'
                            ' · ${exercise.restSeconds}s rest',
                          ),
                          onTap: () => _editExercise(index),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit exercise targets',
                                onPressed: () => _editExercise(index),
                                icon: const Icon(Icons.tune_rounded),
                              ),
                              IconButton(
                                tooltip: 'Remove exercise',
                                onPressed: () => setState(
                                  () => _exercises = [
                                    for (var i = 0; i < _exercises.length; i++)
                                      if (i != index) _exercises[i],
                                  ],
                                ),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('template-editor-add-exercise-button'),
              onPressed: _addExercise,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add exercise'),
            ),
          ),
        ),
      ],
    ),
  );
}

class _TemplateExercisePicker extends StatefulWidget {
  const _TemplateExercisePicker();

  @override
  State<_TemplateExercisePicker> createState() =>
      _TemplateExercisePickerState();
}

class _TemplateExercisePickerState extends State<_TemplateExercisePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) => BlocBuilder<LibraryBloc, LibraryState>(
    builder: (context, state) {
      final query = _query.trim().toLowerCase();
      final exercises = state.exercises
          .where((exercise) {
            if (query.isEmpty) return true;
            return '${exercise.name} ${exercise.target} ${exercise.equipment}'
                .toLowerCase()
                .contains(query);
          })
          .toList(growable: false);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .5,
        builder: (context, controller) => Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search exercises',
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  itemCount: exercises.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    return ListTile(
                      key: Key('template-picker-${exercise.id}'),
                      leading: ExerciseMedia(exercise: exercise, size: 44),
                      title: Text(exercise.name),
                      subtitle: Text(
                        '${exercise.target} · ${exercise.equipment}',
                      ),
                      onTap: () => Navigator.pop(context, exercise),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _TemplateExerciseSheet extends StatefulWidget {
  const _TemplateExerciseSheet({required this.exercise, required this.newId});

  final WorkoutExercise exercise;
  final String Function() newId;

  @override
  State<_TemplateExerciseSheet> createState() => _TemplateExerciseSheetState();
}

class _TemplateExerciseSheetState extends State<_TemplateExerciseSheet> {
  late final TextEditingController _sets = TextEditingController(
    text: '${widget.exercise.sets.length}',
  );
  late final TextEditingController _reps = TextEditingController(
    text:
        '${widget.exercise.sets.isEmpty ? 8 : widget.exercise.sets.first.repetitions}',
  );
  late final TextEditingController _load = TextEditingController(
    text:
        '${widget.exercise.sets.isEmpty ? 0 : widget.exercise.sets.first.loadKg}',
  );
  late final TextEditingController _rest = TextEditingController(
    text: '${widget.exercise.restSeconds}',
  );

  @override
  void dispose() {
    _sets.dispose();
    _reps.dispose();
    _load.dispose();
    _rest.dispose();
    super.dispose();
  }

  void _save() {
    final count = (int.tryParse(_sets.text) ?? 1).clamp(1, 20);
    final reps = (int.tryParse(_reps.text) ?? 0).clamp(0, 999);
    final load = double.tryParse(_load.text.replaceAll(',', '.')) ?? 0;
    final rest = (int.tryParse(_rest.text) ?? 120).clamp(15, 600);
    final sets = List.generate(count, (index) {
      final source = index < widget.exercise.sets.length
          ? widget.exercise.sets[index]
          : WorkoutSet(
              id: widget.newId(),
              exerciseId: widget.exercise.exerciseId,
              position: index,
            );
      return source.copyWith(
        position: index,
        repetitions: reps,
        loadKg: load < 0 ? 0 : load,
        clearCompletedAt: true,
        isCompleted: false,
      );
    });
    Navigator.pop(
      context,
      widget.exercise.copyWith(restSeconds: rest, sets: sets),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.exercise.name,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _NumberField(label: 'Sets', controller: _sets),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NumberField(label: 'Reps', controller: _reps),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                label: 'Target kg',
                controller: _load,
                decimal: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NumberField(label: 'Rest sec', controller: _rest),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('save-template-exercise-targets-button'),
            onPressed: _save,
            child: const Text('Save exercise targets'),
          ),
        ),
      ],
    ),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    this.decimal = false,
  });

  final String label;
  final TextEditingController controller;
  final bool decimal;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    inputFormatters: [
      FilteringTextInputFormatter.allow(
        decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
      ),
    ],
    decoration: InputDecoration(labelText: label),
  );
}
