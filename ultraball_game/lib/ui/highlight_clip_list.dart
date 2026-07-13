import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/highlight_recorder.dart';

class HighlightClipList extends StatelessWidget {
  final HighlightRecorder recorder;
  final String homeTeamName;
  final String awayTeamName;
  final Color  homeTeamColor;
  final Color  awayTeamColor;

  const HighlightClipList({
    super.key,
    required this.recorder,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.homeTeamColor,
    required this.awayTeamColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Recording indicator — visible only while R-key recording is active
        ValueListenableBuilder<bool>(
          valueListenable: recorder.isRecording,
          builder: (_, recording, __) {
            if (!recording) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF200008).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFFF3B53).withValues(alpha: 0.65),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFF3B53),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'REC  6s',
                      style: GoogleFonts.chakraPetch(
                        fontSize:      9,
                        fontWeight:    FontWeight.w700,
                        letterSpacing: 2.5,
                        color:         const Color(0xFFFF3B53),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Clip list
        ValueListenableBuilder<List<HighlightClip>>(
          valueListenable: recorder.allClips,
          builder: (_, clips, __) {
            if (clips.isEmpty) return const SizedBox.shrink();
            return _ClipListPanel(
              clips:         clips.reversed.toList(),
              recorder:      recorder,
              homeTeamName:  homeTeamName,
              awayTeamName:  awayTeamName,
              homeTeamColor: homeTeamColor,
              awayTeamColor: awayTeamColor,
            );
          },
        ),
      ],
    );
  }
}

class _ClipListPanel extends StatelessWidget {
  final List<HighlightClip> clips;
  final HighlightRecorder   recorder;
  final String homeTeamName;
  final String awayTeamName;
  final Color  homeTeamColor;
  final Color  awayTeamColor;

  const _ClipListPanel({
    required this.clips,
    required this.recorder,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.homeTeamColor,
    required this.awayTeamColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: const Color(0xFF04050A).withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
            child: Row(
              children: [
                Text(
                  'HIGHLIGHTS',
                  style: GoogleFonts.chakraPetch(
                    fontSize:      9,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: 2.5,
                    color:         const Color(0xFFFFCB3D),
                  ),
                ),
                const Spacer(),
                Text(
                  '${clips.length} clips',
                  style: const TextStyle(
                    color:      Color(0xFF555577),
                    fontSize:   8,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFF111122)),
          Flexible(
            child: ListView.builder(
              shrinkWrap:  true,
              padding:     EdgeInsets.zero,
              itemCount:   clips.length,
              itemBuilder: (_, i) => _ClipItem(
                clip:          clips[i],
                homeTeamName:  homeTeamName,
                awayTeamName:  awayTeamName,
                homeTeamColor: homeTeamColor,
                awayTeamColor: awayTeamColor,
                onTap:         () => recorder.onPlayClipRequest?.call(clips[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClipItem extends StatelessWidget {
  final HighlightClip clip;
  final String        homeTeamName;
  final String        awayTeamName;
  final Color         homeTeamColor;
  final Color         awayTeamColor;
  final VoidCallback  onTap;

  const _ClipItem({
    required this.clip,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.homeTeamColor,
    required this.awayTeamColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isHome    = clip.teamId == 'player';
    final teamColor = isHome ? homeTeamColor : awayTeamColor;
    final teamName  = isHome ? homeTeamName : awayTeamName;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Row(
            children: [
              // Score type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color:        teamColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(3),
                  border:       Border.all(
                    color: teamColor.withValues(alpha: 0.55),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  clip.scoreType.toUpperCase(),
                  style: TextStyle(
                    color:         teamColor,
                    fontSize:      8,
                    fontWeight:    FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Scorer name + team
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:       MainAxisSize.min,
                  children: [
                    Text(
                      clip.scorerName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      teamName,
                      style: TextStyle(
                        color:    teamColor.withValues(alpha: 0.65),
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Resulting score: away – home
              Text(
                '${clip.opponentScore}–${clip.playerScore}',
                style: GoogleFonts.barlowCondensed(
                  fontSize:   12,
                  fontWeight: FontWeight.w700,
                  color:      const Color(0xFFFFCB3D),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => HighlightRecorder.downloadClip(clip),
                child: Icon(
                  Icons.download,
                  size:  14,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
