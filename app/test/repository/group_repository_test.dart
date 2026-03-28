import 'package:app/core/constants/app_constants.dart';
import 'package:app/features/groups/data/datasources/hive_group_datasource.dart';
import 'package:app/features/groups/data/datasources/supabase_group_datasource.dart';
import 'package:app/features/groups/data/repositories/group_repository_impl.dart';
import 'package:app/features/groups/domain/entities/group_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseGroupDataSource extends Mock
    implements SupabaseGroupDataSource {}

class MockHiveGroupDataSource extends Mock implements HiveGroupDataSource {}

void main() {
  late MockSupabaseGroupDataSource mockRemote;
  late MockHiveGroupDataSource mockLocal;
  late GroupRepositoryImpl repository;

  final cachedGroups = [
    GroupEntity(
      id: 'group-1',
      name: 'Old Name',
      type: GroupType.travel,
      currency: 'JPY',
      inviteCode: 'ABC123',
      createdBy: 'user-1',
      createdAt: DateTime(2025, 1, 1),
    ),
  ];

  setUp(() {
    mockRemote = MockSupabaseGroupDataSource();
    mockLocal = MockHiveGroupDataSource();
    repository = GroupRepositoryImpl(mockRemote, mockLocal, true);

    when(() => mockLocal.getGroups()).thenReturn(cachedGroups);
    when(() => mockLocal.saveGroups(any())).thenAnswer((_) async {});
  });

  test('updateGroupName updates remote and local cache on success', () async {
    when(
      () => mockRemote.updateGroupName('group-1', 'New Name'),
    ).thenAnswer((_) async {});

    final result = await repository.updateGroupName('group-1', 'New Name');

    expect(result.isRight(), isTrue);
    verify(() => mockRemote.updateGroupName('group-1', 'New Name')).called(1);
    verify(
      () => mockLocal.saveGroups(
        any(
          that: predicate<List<GroupEntity>>(
            (groups) =>
                groups.length == 1 &&
                groups.first.id == 'group-1' &&
                groups.first.name == 'New Name',
          ),
        ),
      ),
    ).called(1);
  });

  test('updateGroupName returns failure when remote throws', () async {
    when(
      () => mockRemote.updateGroupName('group-1', 'New Name'),
    ).thenThrow(Exception('permission denied'));

    final result = await repository.updateGroupName('group-1', 'New Name');

    expect(result.isLeft(), isTrue);
    verifyNever(() => mockLocal.saveGroups(any()));
  });
}
