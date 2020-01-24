import 'package:audio_service/audio_service.dart';
import 'package:bloc_pattern/bloc_pattern.dart';
import 'package:flutter/material.dart';
import 'package:inside_chassidus/data/models/inside-data/media.dart';
import 'package:inside_chassidus/data/media-manager.dart';
import 'package:inside_chassidus/data/repositories/class-position-repository.dart';
import 'package:inside_chassidus/util/duration-helpers.dart';
import 'package:rxdart/rxdart.dart';

typedef Widget ProgressStreamBuilder(Duration state);

class ProgressBar extends StatelessWidget {
  final Media media;

  ProgressBar({this.media});

  @override
  Widget build(BuildContext context) {
    final mediaManager = BlocProvider.getBloc<MediaManager>();

    final positionRepository =
        BlocProvider.getDependency<ClassPositionRepository>();

    // Stream of media. A new media object is set when the duration is loaded.
    // Really, I should have all the durations offline, but I don't yet, so when I
    // get it rebuild.
    return StreamBuilder<MediaState>(
      stream: mediaManager.mediaState.where((state) =>
          state.media.source == media.source &&
          state.media.duration != media.duration),
      initialData:
          MediaState(media: media, state: BasicPlaybackState.connecting),
      builder: (context, snapshot) {
        final media = snapshot.data.media;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _slider(mediaManager, media,
                start: positionRepository.getPositionsFor(this.media)),
            _timeLabels(mediaManager, media,
                start: positionRepository.getPositionsFor(this.media))
          ],
        );
      },
    );
  }

  Row _timeLabels(MediaManager mediaManager, Media media,
      {Stream<Duration> start}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        // Show current time in class.
        _stateDurationStreamBuilder(mediaManager.mediaPosition,
            start: start, builder: (position) => _time(position)),
        // Show time remaining in class.
        _stateDurationStreamBuilder(mediaManager.mediaPosition,
            start: start,
            builder: (position) => _time(media.duration - position))
      ],
    );
  }

  Container _slider(MediaManager mediaManager, Media media,
      {Stream<Duration> start}) {
    final maxSliderValue = media.duration?.inMilliseconds?.toDouble() ?? 0;

    final onChanged = maxSliderValue == 0
        ? null
        : (double newProgress) => mediaManager.seek(
            media, Duration(milliseconds: newProgress.round()));

    return Container(
      child: _stateDurationStreamBuilder(mediaManager.mediaPosition,
          start: start, builder: (position) {
        double value = position.inMilliseconds.toDouble();

        value = value > maxSliderValue ? maxSliderValue : value < 0 ? 0 : value;

        return Slider(
          value: value,
          max: maxSliderValue,
          onChanged: onChanged,
        );
      }),
    );
  }

  // TODO: This method is really just taking up space. Move stream to own method
  // and just use a StreamBuilder.
  Widget _stateDurationStreamBuilder<T>(Stream<WithMediaState<Duration>> stream,
          {ProgressStreamBuilder builder, @required Stream<Duration> start}) =>
      StreamBuilder<Duration>(
        stream: Rx.combineLatest2<WithMediaState<Duration>, Duration, Duration>(
            stream.startWith(null), start, (mediaState, preloadedPosition) {
          return preloadedPosition == Duration.zero && mediaState?.state?.media?.source == media.source
              ? mediaState?.data
              : preloadedPosition;
        }),
        builder: (context, snapshot) {
          return builder(snapshot.data ?? Duration.zero);
        },
      );

  /// Text representation of the given [Duration].
  Widget _time(Duration duration) => Text(toDurationString(duration));
}
