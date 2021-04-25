import 'package:audio_service/audio_service.dart';

/// Persists the current location. Updates it whenever there's reason to think that
/// it has changed. For example, before calling playFromUri, stop, etc.
class AudioHandlerPersistPosition extends CompositeAudioHandler {
  final PositionSaver positionRepository;

  AudioHandlerPersistPosition(AudioHandler inner,
      {required this.positionRepository})
      : super(inner);

  @override
  Future<void> play() async {}

  @override
  Future<void> playFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {}

  @override
  Future<void> playFromSearch(String query,
      [Map<String, dynamic>? extras]) async {}

  @override
  Future<void> playFromUri(Uri uri, [Map<String, dynamic>? extras]) async {}

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToQueueItem(int index) async {}

  @override
  Future<void> seek(Duration position) async {
    await super.seek(position);

    final value = mediaItem.valueWrapper?.value;
    if (value != null) {
      positionRepository.set(value.id, position);
    }
  }

  @override
  Future<void> onTaskRemoved() async {}

  @override
  Future<void> onNotificationDeleted() async {
    await stop();
  }

  Future<void> _updateSavedPosition() async {}
}

abstract class PositionSaver {
  Future<void> set(String mediaId, Duration position);

  Future<Duration> get(String mediaId);
}

class MemoryPositionSaver extends PositionSaver {
  final Map<String, Duration> _positions = Map();

  @override
  Future<Duration> get(String mediaId) async =>
      _positions[mediaId] ?? Duration.zero;

  @override
  Future<void> set(String mediaId, Duration position) async =>
      _positions[mediaId] = position;
}

class HivePositionSaver extends PositionSaver {
  @override
  Future<Duration> get(String mediaId) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  Future<void> set(String mediaId, Duration position) {
    // TODO: implement set
    throw UnimplementedError();
  }
}
