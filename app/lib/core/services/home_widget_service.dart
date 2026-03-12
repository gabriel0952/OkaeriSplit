import 'dart:convert';
import 'dart:developer';

import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:home_widget/home_widget.dart';

class HomeWidgetService {
  HomeWidgetService._();
  static final instance = HomeWidgetService._();

  static const _appGroupId = 'group.com.raycat.okaerisplit';
  static const _iOSWidgetName = 'OkaeriSplitWidget';

  Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  Future<void> updateGroups(List<GroupEntity> groups) async {
    final payload = jsonEncode({
      'groups': groups.take(3).map((g) => {
            'id': g.id,
            'name': g.name,
            'currency': g.currency,
          }).toList(),
      'lastUpdated': DateTime.now().toIso8601String(),
    });
    await HomeWidget.saveWidgetData('groups_payload', payload);
    await HomeWidget.updateWidget(iOSName: _iOSWidgetName);
    log('[HomeWidget] updated ${groups.length} groups', name: 'HomeWidgetService');
  }
}
