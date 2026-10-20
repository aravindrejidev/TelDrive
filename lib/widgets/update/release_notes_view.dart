import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/neu_theme.dart';

enum NoteBlockType { heading, bullet, paragraph }

class NoteBlock {
  const NoteBlock(this.type, this.text, {this.level = 2});

  final NoteBlockType type;
  final String text;

  /// Heading depth: 1 for `#`, 2 for `##`, and so on.
  final int level;
}

/// Turns the Markdown of a release description into simple blocks. It handles
/// what release notes actually use: headings, bullet and numbered lists,
/// paragraphs, and **bold**, `code` and [link](url) inside the text.
List<NoteBlock> parseReleaseNotes(String markdown) {
  final cleaned = markdown
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll('\r\n', '\n');

  final blocks = <NoteBlock>[];
  for (final raw in cleaned.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || RegExp(r'^[-*_]{3,}$').hasMatch(line)) continue;

    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    if (heading != null) {
      blocks.add(NoteBlock(
        NoteBlockType.heading,
        heading.group(2)!.trim(),
        level: heading.group(1)!.length,
      ));
      continue;
    }

    final bullet = RegExp(r'^(?:[-*+]|\d+[.)])\s+(.*)$').firstMatch(line);
    if (bullet != null) {
      blocks.add(NoteBlock(NoteBlockType.bullet, bullet.group(1)!.trim()));
      continue;
    }

    blocks.add(NoteBlock(NoteBlockType.paragraph, line));
  }
  return blocks;
}

List<TextSpan> _inlineSpans(String text, Color accent) {
  final spans = <TextSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*|`(.+?)`|\[([^\]]+)\]\([^)]+\)');
  var cursor = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    if (match.group(1) != null) {
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ));
    } else if (match.group(2) != null) {
      spans.add(TextSpan(
        text: match.group(2),
        style: TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ));
    } else {
      spans.add(TextSpan(text: match.group(3)));
    }
    cursor = match.end;
  }
  if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
  return spans;
}

/// Shows the release notes with each line easing in one after another.
class ReleaseNotesView extends StatefulWidget {
  const ReleaseNotesView({super.key, required this.notes});

  final String notes;

  @override
  State<ReleaseNotesView> createState() => _ReleaseNotesViewState();
}

class _ReleaseNotesViewState extends State<ReleaseNotesView>
    with SingleTickerProviderStateMixin {
  late List<NoteBlock> _blocks;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _blocks = parseReleaseNotes(widget.notes);
    final steps = math.min(_blocks.length, 14);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 450 + 60 * steps),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.neu;

    if (_blocks.isEmpty) {
      return Text(
        'No release notes were written for this version.',
        style: TextStyle(fontSize: 14, height: 1.45, color: c.textMuted),
      );
    }

    final count = _blocks.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < count; i++)
          _Reveal(
            animation: _controller,
            begin: (i / count) * 0.6,
            child: _buildBlock(c, _blocks[i], isFirst: i == 0),
          ),
      ],
    );
  }

  Widget _buildBlock(NeuColors c, NoteBlock block, {required bool isFirst}) {
    switch (block.type) {
      case NoteBlockType.heading:
        return Padding(
          padding: EdgeInsets.only(top: isFirst ? 0 : 14, bottom: 8),
          child: Text.rich(
            TextSpan(children: _inlineSpans(block.text, c.accent)),
            style: TextStyle(
              fontSize: block.level <= 2 ? 16 : 14.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: c.text,
            ),
          ),
        );
      case NoteBlockType.bullet:
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 12, left: 2),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: c.accentGradient,
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: _inlineSpans(block.text, c.accent)),
                  style: TextStyle(fontSize: 14.5, height: 1.45, color: c.text),
                ),
              ),
            ],
          ),
        );
      case NoteBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Text.rich(
            TextSpan(children: _inlineSpans(block.text, c.accent)),
            style: TextStyle(fontSize: 14.5, height: 1.45, color: c.textMuted),
          ),
        );
    }
  }
}

/// Fades and lifts [child] into place during its slice of [animation].
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.animation,
    required this.begin,
    required this.child,
  });

  final Animation<double> animation;
  final double begin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final slice = animation.drive(
      CurveTween(
        curve: Interval(begin, math.min(1.0, begin + 0.4), curve: Curves.easeOutCubic),
      ),
    );
    return FadeTransition(
      opacity: slice,
      child: SlideTransition(
        position: slice.drive(
          Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }
}
