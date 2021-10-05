import 'package:bloc_pattern/bloc_pattern.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:inside_api/models.dart';
import 'package:inside_chassidus/util/library-navigator/index.dart';
import 'package:inside_chassidus/util/text-null-if-empty.dart';
import 'package:inside_chassidus/widgets/inside-breadcrumbs.dart';
import 'package:inside_chassidus/widgets/inside-navigator.dart';
import 'package:inside_chassidus/widgets/media-list/media-item.dart';
import 'package:inside_chassidus/widgets/section-content-list.dart';

class TernarySectionRoute extends StatelessWidget {
  static const routeName = '/library/ternary-section';
  final Section? section;

  TernarySectionRoute({required this.section});

  @override
  Widget build(BuildContext context) {
    final lastPlayingId =
        BlocProvider.getDependency<LibraryPositionService>().lastPlayingId;
    final scrollToIndexRaw = section?.content.indexWhere((element) =>
        element.media?.id != null && element.media?.id == lastPlayingId);
    final scrollToIndex = scrollToIndexRaw == null
        ? scrollToIndexRaw
        : scrollToIndexRaw < 0
            ? null
            : scrollToIndexRaw;
    return SectionContentList(
        scrollIndex: scrollToIndex,
        isSeperated: true,
        section: section,
        leadingWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [InsideBreadcrumbs()],
        ),
        sectionBuilder: (context, section) =>
            InsideNavigator(data: section, child: _tile(section)),
        lessonBuilder: (context, lesson) => _tile(lesson),
        mediaBuilder: (context, media) => MediaItem(
              media: media,
              sectionId: section!.id,
              routeDataService:
                  BlocProvider.getDependency<LibraryPositionService>(),
            ));
  }

  static Widget _tile(CountableSiteDataItem data) {
    var itemWord = data.audioCount! > 1 ? 'classes' : 'class';

    return ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 4),
        title: textIfNotEmpty(data.title, maxLines: 1),
        subtitle: textIfNotEmpty('${data.audioCount} $itemWord'),
        trailing: Icon(Icons.arrow_forward_ios));
  }
}
