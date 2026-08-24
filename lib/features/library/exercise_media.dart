import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/exercise.dart';

class ExerciseMedia extends StatelessWidget {
  const ExerciseMedia({required this.exercise, this.size, super.key});

  final Exercise exercise;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.fitness_center_rounded,
          size: size == null ? 42 : 26,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
    final mediaUrl = exercise.mediaUrl;
    return Semantics(
      label: '${exercise.name} movement preview',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: mediaUrl == null || mediaUrl.isEmpty
              ? placeholder
              : CachedNetworkImage(
                  imageUrl: mediaUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => placeholder,
                  errorWidget: (_, url, error) {
                    debugPrint(
                      'Exercise GIF failed to load for ${exercise.id}: $url ($error)',
                    );
                    return placeholder;
                  },
                ),
        ),
      ),
    );
  }
}
