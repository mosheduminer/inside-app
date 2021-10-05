import 'package:flutter/material.dart';
import 'package:inside_api/models.dart';
import 'package:inside_api/site-service.dart';

/// A class which hold route data, and allows it to be set.
/// This is useful when a widget can be a part of a couple diffirent routes, and
/// needs a generic way to set the route data for the route it's a part of currently.
///
/// For example, the media player classes.
abstract class IRoutDataService {
  void setActiveItem(SiteDataItem? data);
}

/// Supports setting a new active section.
/// Stores a list of parents and current item (keeping note if parents weren't
/// navigated to, e.g. because user navigated from previously played to its section)
/// a thin abstraction around the page stack for the router
class LibraryPositionService extends ChangeNotifier
    implements IRoutDataService {
  final SiteBoxes siteBoxes;
  List<SitePosition> sections = [];

  /// Available only when the previous screen was the player screen
  int? lastPlayingId;

  LibraryPositionService({required this.siteBoxes});

  /// Ensure that next to last item is parent of new item, or clear the list.
  /// If new parent isn't in list, replace the list with it and its ancestors.
  /// Make note that they were never navigated to (and so shouldn't show up
  /// e.g. when user hits back button)
  Future<List<SitePosition>> setActiveItem(SiteDataItem? item) async {
    if (sections.isNotEmpty && sections.last.data == item) {
      return sections;
    }

    setLastPlayingId();

    await _clearTo(item!);

    notifyListeners();
    return sections;
  }

  bool removeLast() {
    setLastPlayingId();
    if (sections.isNotEmpty) {
      sections.removeLast();
      notifyListeners();
      return true;
    }

    return false;
  }

  clear() {
    if (sections.isNotEmpty) {
      setLastPlayingId();
      sections.clear();
      notifyListeners();
    }
  }

  void setLastPlayingId() {
    if (sections.isNotEmpty) {
      final lastData = sections.last.data;
      print(sections.last.data is Media);
      if (lastData is Media) {
        lastPlayingId = lastData.id;
      } else {
        lastPlayingId = null;
      }
    }
  }

  /// Clear the saved list, and reset to the given item and all of its parents.
  Future<void> _clearTo(SiteDataItem item) async {
    sections.clear();
    sections.add(SitePosition(data: item, level: 0));

    // Add all the parents to the list. These aren't used for some navigation (the
    // back button won't get you there), but they are used for explicit navigation
    // (e.g. clicking a parent section button), and to provide context to a class.
    var lastItemAdded = item;
    while ((lastItemAdded.closestSectionId ?? 0) != 0) {
      final parentSection =
          await (this.siteBoxes.sections!.get(lastItemAdded.closestSectionId));

      if (parentSection == null) {
        print('parent is null');
        break;
      }

      if (lastItemAdded is Media &&
          lastItemAdded.closestSectionId != lastItemAdded.parentId) {
        final mediaSectionId = lastItemAdded.parentId;
        final parentMediaSection = parentSection.content
            .firstWhere((content) => content.mediaSection?.id == mediaSectionId)
            .mediaSection;
        sections.insert(
            0,
            SitePosition(
                data: parentMediaSection,
                wasNavigatedTo: false,
                level: sections.length));
      }

      sections.insert(
          0, SitePosition(data: parentSection, level: sections.length));
      lastItemAdded = parentSection;
    }

    for (int i = 0; i < sections.length; i++) {
      sections[i].level = i;

      if (sections[i].data is Section) {
        await siteBoxes.resolve(sections[i].data as Section);
      }
    }
  }
}

class SitePosition {
  final SiteDataItem? data;
  final bool wasNavigatedTo;
  // For example, the top level section (which would be on the home screen)
  // would be level 0. A child would be level 1, etc.
  int level;

  SitePosition({this.data, this.wasNavigatedTo = true, required this.level});
}
