import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:bloc_pattern/bloc_pattern.dart';
import 'package:hive/hive.dart';
import 'package:inside_chassidus/data/models/inside-data/index.dart';
import 'package:inside_chassidus/data/repositories/class-position-repository.dart';
import 'package:inside_chassidus/util/audio-service/audio-task.dart';
import 'package:inside_chassidus/util/audio-service/util.dart';
import 'package:rxdart/rxdart.dart';

class MediaManager extends BlocBase {
  /// The media which is currently playing.
  MediaState get current => _mediaSubject.value;

  /// The current media state.
  Stream<MediaState> get mediaState => _mediaSubject;

  /// The current media position.
  Stream<WithMediaState<Duration>> get mediaPosition => _positionSubject;

  /// Stream for changes in position of not-playing lesson.
  Stream<MapEntry<String, Duration>> get localPreSeek => _localPreSeekSubject;

  final ClassPositionRepository positionRepository;

  /// Keep track of where in a class user seeks to before playback starts.
  final Map<String, Duration> _localPreSeek = new Map();

  StreamSubscription<PlaybackState> _audioPlayerStateSubscription;

  final BehaviorSubject<MediaState> _mediaSubject = BehaviorSubject();

  BehaviorSubject<WithMediaState<Duration>> _positionSubject =
      BehaviorSubject();

  /// Stream for changes in position of not-playing lesson.
  final BehaviorSubject<MapEntry<String, Duration>> _localPreSeekSubject =
      new BehaviorSubject();

  // Ensure that seeks don't happen to frequently.
  final BehaviorSubject<Duration> _seekingValues = BehaviorSubject.seeded(null);

  StreamSubscription _positionSubscription;

  MediaManager({this.positionRepository}) {
    _audioPlayerStateSubscription =
        AudioService.playbackStateStream.listen((state) {
      if (state != null && current != null) {
        // E.g. when user stops from lock screen, we miss the stop state and skip to none.
        // In this case, though, we treat it as stopped. Failing to do so means that the UI
        // thinks that the media is not yet loaded and needs to be, so it just waits forever.

        final newState = state.basicState == BasicPlaybackState.none
            ? BasicPlaybackState.stopped
            : state.basicState;

        _mediaSubject.value = current.copyWith(state: newState, event: state);
      }
    });

    // Update stream of positions.
    _positionSubscription = Rx.combineLatest3<dynamic, Duration, MediaState, WithMediaState<Duration>>(
        Stream.periodic(Duration(milliseconds: 20)),
        _seekingValues,
        // When user hits play, until play back starts, the manager doesn't know where
        // the player is holding.
        // The position repository and audio task are in charge of that.
        // Therefore, when event is null (from being set in play method) - don't update what
        // we consider to be current postion based on that.
        _mediaSubject.where((media) => media.event != null && media.state != BasicPlaybackState.connecting),
        (_, displaySeek, mediaState) =>
            _getCurrentPosition(displaySeek, mediaState)).listen(
        (state) => _positionSubject.value = state);

    // Save the current position of media, in case user listens to another class and then comes back.
    mediaPosition.sampleTime(Duration(milliseconds: 200)).listen((state) =>
        positionRepository.updatePosition(current.media, state.data));

    final nonNullSeekingValues =
        _seekingValues.where((position) => position != null);

    // Change the audio position. Makes sure we don't seek too often.
    nonNullSeekingValues
        .sampleTime(Duration(milliseconds: 50))
        .listen((position) {
      AudioService.seekTo(
          position.inMilliseconds < 0 ? 0 : position.inMilliseconds);
    });

    // Clear seeking value as soon as the latest value is being used by audio_service.
    // Untill then, it holds information relevant to the UI; after, that information has been
    // moved to audio_service.
    Rx.combineLatest2<MediaState, Duration, void>(
        mediaState, nonNullSeekingValues, (state, seeking) {
      // Clear seeking_value if it's latest value has been consumed by audio_service.
      if (isSeeking(state.state) &&
          state.event.currentPosition == seeking.inMilliseconds) {
        _seekingValues.value = null;
      }
    }).listen((_) {});
  }

  pause() => AudioService.pause();

  play(Media media) async {
    final serviceIsRunning = await AudioService.running;
    if (serviceIsRunning && media == _mediaSubject.value?.media) {
      AudioService.play();
      return;
    }

    if (!serviceIsRunning) {
      await AudioService.start(
          backgroundTaskEntrypoint: backgroundTaskEntrypoint,
          androidNotificationChannelName: "Inside Chassidus Class");
    }

    // While getting a file to play, we want to manually handle the state streams.
    _audioPlayerStateSubscription.pause();
    _positionSubscription.pause();

    _mediaSubject.value =
        MediaState(media: media, state: BasicPlaybackState.connecting);

    await AudioService.playFromMediaId(media.source);

    // Seek if user selected a new position.
    // Continuing from a saved position (from lesson progress), though,
    // is handled in audio_task.
    if (_localPreSeek[media.source] != null) {
      await AudioService.seekTo(
          _localPreSeek.remove(media.source).inMilliseconds);
      _localPreSeekSubject.value = MapEntry(media.source, null);
    }

    var durationState = await AudioService.currentMediaItemStream
        .where((item) =>
            item != null &&
            item.duration != null &&
            item.id == media?.source &&
            item.duration > 0)
        .first;

    if (media.duration == null) {
      media.duration = Duration(milliseconds: durationState.duration);

      final lesson = await Hive.lazyBox<Lesson>('lessons').get(media.lessonId);
      lesson.audio
          .where((source) => source.source == media.source)
          .forEach((source) => source.duration = media.duration);
      await lesson.save();
    }

    _mediaSubject.value = current.copyWith(
        state: AudioService.playbackState.basicState, media: media);

    _audioPlayerStateSubscription.resume();
    _positionSubscription.resume();
  }

  /// Updates the current location in given media.
  seek(Media media, Duration location) {
    // If user is seeking in a class which isn't currently being played, save it
    // to play from that location when we get there.
    if (media.source != _mediaSubject.value?.media?.source) {
      _localPreSeek[media.source] = location;
      _localPreSeekSubject.value = MapEntry(media.source, location);
    } else {
      _seekingValues.add(location);
    }
  }

  skip(Media media, Duration duration) async {
    var currentLocation = _positionSubject.value.data;

    if (media.source != _mediaSubject.value.media.source) {
      currentLocation =
          _localPreSeek[media.source] ?? positionRepository.getPosition(media);
    }

    seek(media, currentLocation + duration);
  }

  WithMediaState<Duration> _getCurrentPosition(
      Duration displaySeek, MediaState mediaState) {
    if (mediaState.state == null) {
      return WithMediaState(
          state: mediaState,
          data: Duration(
              milliseconds: AudioService.playbackState?.position ?? 0));
    }

    // If the user wants the audio to be in a particular position, for UI purposes
    // consider that we are already there.
    final position =
        displaySeek?.inMilliseconds ?? mediaState.event.currentPosition;

    return WithMediaState(
        state: mediaState, data: Duration(milliseconds: position));
  }

  @override
  void dispose() {
    _mediaSubject.close();
    _positionSubject.close();
    _seekingValues.close();
    _localPreSeekSubject.close();
    super.dispose();
  }
}

backgroundTaskEntrypoint() async =>
    await AudioServiceBackground.run(() => AudioTask());

class MediaState {
  final Media media;
  final BasicPlaybackState state;
  final PlaybackState event;
  final bool isLoaded;

  MediaState({this.media, this.state, this.event})
      : isLoaded = state != BasicPlaybackState.connecting &&
            state != BasicPlaybackState.error &&
            state != BasicPlaybackState.none;

  MediaState copyWith(
          {Media media, BasicPlaybackState state, PlaybackState event}) =>
      MediaState(
          media: media ?? this.media,
          state: state ?? this.state,
          event: event ?? this.event);
}

/// Allows strongly typed binding of media state with any other value.
/// For example, to associate a stram of audio postions with current file.
class WithMediaState<T> {
  final MediaState state;
  final T data;

  WithMediaState({this.state, this.data});

  WithMediaState<T> copyWith({MediaState state, T data}) =>
      WithMediaState(state: state ?? this.state, data: data ?? this.data);
}
