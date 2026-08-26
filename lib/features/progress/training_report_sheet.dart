import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/training_report.dart';

class TrainingReportSheet extends StatefulWidget {
  const TrainingReportSheet({required this.builder, super.key});

  final TrainingReportBuilder builder;

  @override
  State<TrainingReportSheet> createState() => _TrainingReportSheetState();
}

class _TrainingReportSheetState extends State<TrainingReportSheet> {
  bool _sharing = false;
  String? _error;

  Future<void> _share() async {
    setState(() {
      _sharing = true;
      _error = null;
    });
    try {
      final report = await widget.builder.build();
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          title: 'RepSet training report',
          subject: 'RepSet training report',
          text:
              'A read-only training report from RepSet. It includes Markdown and structured JSON.',
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(report.markdown)),
              mimeType: 'text/markdown',
            ),
            XFile.fromData(
              Uint8List.fromList(utf8.encode(report.json)),
              mimeType: 'application/json',
            ),
          ],
          fileNameOverrides: const [
            'repset-training-report.md',
            'repset-training-data.json',
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The training report could not be generated.');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(12),
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
    decoration: BoxDecoration(
      color: const Color(0xff202620),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xff3a463a)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xff687468),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Share training report',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        const Text(
          'Generate a local snapshot for a coach, Claude, ChatGPT, Hermes, or any app you choose.',
          style: TextStyle(color: Color(0xffb7c2b6), height: 1.35),
        ),
        const SizedBox(height: 16),
        const _ReportDetail(
          icon: Icons.description_outlined,
          text: 'Markdown report for quick reading',
        ),
        const SizedBox(height: 9),
        const _ReportDetail(
          icon: Icons.data_object_rounded,
          text: 'Structured JSON for deeper analysis',
        ),
        const SizedBox(height: 9),
        const _ReportDetail(
          icon: Icons.lock_outline_rounded,
          text: 'No account identity or free-form notes',
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            key: const Key('share-training-report-button'),
            onPressed: _sharing ? null : _share,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffd7ff4f),
              foregroundColor: const Color(0xff171914),
            ),
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            label: Text(
              _sharing ? 'Preparing report…' : 'Generate & share',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        TextButton(
          onPressed: _sharing ? null : () => Navigator.pop(context),
          child: const Text('Not now'),
        ),
      ],
    ),
  );
}

class _ReportDetail extends StatelessWidget {
  const _ReportDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(width: 4),
      Icon(icon, size: 18, color: const Color(0xffd7ff4f)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}
