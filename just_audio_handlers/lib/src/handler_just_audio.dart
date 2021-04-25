import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Uses just_audio to handle playback.
class AudioHandlerJustAudio extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player;

  AudioHandlerJustAudio({required this.player}) {
    player.playbackEventStream
        .listen((event) => playbackState.add(justAudioToAudioService(event)));
  }

  @override
  Future<void> prepareFromUri(Uri uri, [Map<String, dynamic>? extras]) async {
    final currentState = playbackState.valueWrapper?.value ?? PlaybackState();
    playbackState.add(currentState.copyWith(playing: false));

    await player.setUrl(uri.toString());
  }

  @override
  Future<void> prepareFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {}

  @override
  Future<void> playFromUri(Uri uri, [Map<String, dynamic>? extras]) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> playFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(newPosition) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  PlaybackState justAudioToAudioService(PlaybackEvent event) {
    final currentState = playbackState.valueWrapper?.value ?? PlaybackState();
    final playing = player.playing;

    return currentState.copyWith(
      controls: [
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
