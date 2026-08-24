import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/workout_repository.dart';
import '../../domain/workout_session.dart';
import '../../domain/workout_template.dart';

sealed class TemplateEvent {
  const TemplateEvent();
}

class TemplatesLoaded extends TemplateEvent {
  const TemplatesLoaded();
}

class TemplateSavedFromWorkout extends TemplateEvent {
  const TemplateSavedFromWorkout(this.session);
  final WorkoutSession session;
}

class TemplateArchived extends TemplateEvent {
  const TemplateArchived(this.template);
  final WorkoutTemplate template;
}

class TemplateDuplicated extends TemplateEvent {
  const TemplateDuplicated(this.template);
  final WorkoutTemplate template;
}

class TemplateRenamed extends TemplateEvent {
  const TemplateRenamed(this.template, this.title);
  final WorkoutTemplate template;
  final String title;
}

class TemplateDeleted extends TemplateEvent {
  const TemplateDeleted(this.templateId);
  final String templateId;
}

class TemplateUpdated extends TemplateEvent {
  const TemplateUpdated(this.template);
  final WorkoutTemplate template;
}

class TemplateFavoriteToggled extends TemplateEvent {
  const TemplateFavoriteToggled(this.template);
  final WorkoutTemplate template;
}

class TemplateState {
  const TemplateState({this.templates = const [], this.isLoading = false});
  final List<WorkoutTemplate> templates;
  final bool isLoading;
  TemplateState copyWith({List<WorkoutTemplate>? templates, bool? isLoading}) =>
      TemplateState(
        templates: templates ?? this.templates,
        isLoading: isLoading ?? this.isLoading,
      );
}

class TemplateBloc extends Bloc<TemplateEvent, TemplateState> {
  TemplateBloc(this._repository) : super(const TemplateState()) {
    on<TemplatesLoaded>(_load);
    on<TemplateSavedFromWorkout>(_saveFromWorkout);
    on<TemplateArchived>(_archive);
    on<TemplateDuplicated>(_duplicate);
    on<TemplateRenamed>(_rename);
    on<TemplateDeleted>(_delete);
    on<TemplateUpdated>(_update);
    on<TemplateFavoriteToggled>(_toggleFavorite);
  }
  final WorkoutRepository _repository;
  int _ids = 0;
  String _id() => '${DateTime.now().microsecondsSinceEpoch}-${_ids++}';
  Future<void> _load(TemplatesLoaded event, Emitter<TemplateState> emit) async {
    emit(state.copyWith(isLoading: true));
    emit(
      state.copyWith(
        templates: await _repository.getTemplates(),
        isLoading: false,
      ),
    );
  }

  Future<void> _saveFromWorkout(
    TemplateSavedFromWorkout event,
    Emitter<TemplateState> emit,
  ) async {
    final template = WorkoutTemplate(
      id: _id(),
      title: event.session.title,
      exercises: event.session.exercises,
      updatedAt: DateTime.now(),
    );
    await _repository.saveTemplate(template);
    add(const TemplatesLoaded());
  }

  Future<void> _archive(
    TemplateArchived event,
    Emitter<TemplateState> emit,
  ) async {
    await _repository.saveTemplate(
      WorkoutTemplate(
        id: event.template.id,
        title: event.template.title,
        exercises: event.template.exercises,
        updatedAt: DateTime.now(),
        isArchived: true,
      ),
    );
    add(const TemplatesLoaded());
  }

  Future<void> _duplicate(
    TemplateDuplicated event,
    Emitter<TemplateState> emit,
  ) async {
    await _repository.saveTemplate(
      WorkoutTemplate(
        id: _id(),
        title: '${event.template.title} copy',
        exercises: event.template.exercises,
        updatedAt: DateTime.now(),
      ),
    );
    add(const TemplatesLoaded());
  }

  Future<void> _rename(
    TemplateRenamed event,
    Emitter<TemplateState> emit,
  ) async {
    final title = event.title.trim();
    if (title.isEmpty) return;
    await _repository.saveTemplate(
      WorkoutTemplate(
        id: event.template.id,
        title: title.length > 60 ? title.substring(0, 60) : title,
        exercises: event.template.exercises,
        updatedAt: DateTime.now(),
        isArchived: event.template.isArchived,
        isFavorite: event.template.isFavorite,
      ),
    );
    add(const TemplatesLoaded());
  }

  Future<void> _delete(
    TemplateDeleted event,
    Emitter<TemplateState> emit,
  ) async {
    await _repository.deleteTemplate(event.templateId);
    add(const TemplatesLoaded());
  }

  Future<void> _update(
    TemplateUpdated event,
    Emitter<TemplateState> emit,
  ) async {
    await _repository.saveTemplate(event.template);
    add(const TemplatesLoaded());
  }

  Future<void> _toggleFavorite(
    TemplateFavoriteToggled event,
    Emitter<TemplateState> emit,
  ) async {
    await _repository.saveTemplate(
      WorkoutTemplate(
        id: event.template.id,
        title: event.template.title,
        exercises: event.template.exercises,
        updatedAt: DateTime.now(),
        isArchived: event.template.isArchived,
        isFavorite: !event.template.isFavorite,
      ),
    );
    add(const TemplatesLoaded());
  }
}
