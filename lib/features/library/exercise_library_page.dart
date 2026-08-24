import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/exercise.dart';
import 'exercise_media.dart';
import 'library_bloc.dart';

class ExerciseLibraryPage extends StatelessWidget {
  const ExerciseLibraryPage({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<LibraryBloc, LibraryState>(
    builder: (context, state) {
      final exercises = state.visibleExercises;
      return RefreshIndicator(
        onRefresh: () async {
          context.read<LibraryBloc>().add(const LibraryRefreshed());
          await context.read<LibraryBloc>().stream.firstWhere(
            (next) => !next.isRefreshing,
          );
        },
        child: CustomScrollView(
          key: const PageStorageKey('exercise-library'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              sliver: SliverToBoxAdapter(child: _LibraryHeader(state: state)),
            ),
            if (state.message != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: _StatusMessage(message: state.message!),
                ),
              ),
            if (state.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _LoadingState(),
              )
            else if (exercises.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(hasCatalog: state.exercises.isNotEmpty),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                sliver: SliverList.separated(
                  itemCount: exercises.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _ExerciseCard(exercise: exercises[index]),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.state});
  final LibraryState state;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Exercise library',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (state.isRefreshing)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              tooltip: 'Refresh library',
              onPressed: () =>
                  context.read<LibraryBloc>().add(const LibraryRefreshed()),
              icon: const Icon(Icons.sync),
            ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        '${state.exercises.length} exercises saved on this device',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 18),
      SearchBar(
        hintText: 'Search exercise, muscle, or equipment',
        leading: const Icon(Icons.search),
        onChanged: (query) =>
            context.read<LibraryBloc>().add(LibrarySearchChanged(query)),
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              selected: state.onlyFavorites,
              label: const Text('Favorites'),
              avatar: Icon(
                state.onlyFavorites ? Icons.star : Icons.star_border,
                size: 18,
              ),
              onSelected: (selected) => context.read<LibraryBloc>().add(
                LibraryFavoritesChanged(selected),
              ),
            ),
            const SizedBox(width: 8),
            _FilterMenu(
              label: state.selectedTarget ?? 'Muscle',
              values: state.targets,
              onSelected: (value) =>
                  context.read<LibraryBloc>().add(LibraryTargetChanged(value)),
            ),
            const SizedBox(width: 8),
            _FilterMenu(
              label: state.selectedEquipment ?? 'Equipment',
              values: state.equipment,
              onSelected: (value) => context.read<LibraryBloc>().add(
                LibraryEquipmentChanged(value),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.values,
    required this.onSelected,
  });
  final String label;
  final List<String> values;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String?>(
    tooltip: 'Filter by $label',
    onSelected: onSelected,
    itemBuilder: (context) => [
      const PopupMenuItem<String?>(value: null, child: Text('All')),
      ...values.map(
        (value) => PopupMenuItem<String?>(value: value, child: Text(value)),
      ),
    ],
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down, size: 18),
        ],
      ),
    ),
  );
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExerciseDetailPage(exercise: exercise),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ExerciseMedia(exercise: exercise, size: 72),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text('${exercise.target} • ${exercise.equipment}'),
                ],
              ),
            ),
            IconButton(
              tooltip: exercise.isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
              onPressed: () => context.read<LibraryBloc>().add(
                LibraryFavoriteToggled(exercise),
              ),
              icon: Icon(exercise.isFavorite ? Icons.star : Icons.star_border),
            ),
          ],
        ),
      ),
    ),
  );
}

class ExerciseDetailPage extends StatelessWidget {
  const ExerciseDetailPage({super.key, required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Exercise'),
      actions: [
        BlocBuilder<LibraryBloc, LibraryState>(
          builder: (context, state) {
            final current = state.exercises.firstWhere(
              (item) => item.id == exercise.id,
              orElse: () => exercise,
            );
            return IconButton(
              tooltip: current.isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
              onPressed: () => context.read<LibraryBloc>().add(
                LibraryFavoriteToggled(current),
              ),
              icon: Icon(current.isFavorite ? Icons.star : Icons.star_border),
            );
          },
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ExerciseMedia(exercise: exercise),
        ),
        const SizedBox(height: 22),
        Text(
          exercise.name,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '${exercise.target} • ${exercise.equipment}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (exercise.secondaryMuscles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Also works ${exercise.secondaryMuscles.join(', ')}'),
        ],
        const SizedBox(height: 28),
        Text(
          'How to perform it',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (exercise.instructions.isEmpty)
          const Text('Instructions are not available for this exercise.')
        else
          ...exercise.instructions.indexed.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${entry.$1 + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(child: Text(entry.$2)),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_outlined),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Loading exercises'),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasCatalog});
  final bool hasCatalog;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 42),
          const SizedBox(height: 14),
          Text(
            hasCatalog
                ? 'No exercises match these filters.'
                : 'No exercises are saved yet.',
            textAlign: TextAlign.center,
          ),
          if (hasCatalog) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                final bloc = context.read<LibraryBloc>();
                bloc
                  ..add(const LibrarySearchChanged(''))
                  ..add(const LibraryTargetChanged(null))
                  ..add(const LibraryEquipmentChanged(null))
                  ..add(const LibraryFavoritesChanged(false));
              },
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    ),
  );
}
