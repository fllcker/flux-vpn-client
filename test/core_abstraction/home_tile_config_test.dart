import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/home_tile_config.dart';

void main() {
  test('HomeTileConfig round-trips through JSON', () {
    const tile = HomeTileConfig(
      id: 'tile-1',
      type: HomeTileType.routingPreset,
      size: HomeTileSize.wide,
      position: 4,
      radiusStyle: HomeTileRadiusStyle.pill,
      contentAlign: HomeTileContentAlign.center,
    );

    final restored = HomeTileConfig.fromJson(tile.toJson());

    expect(restored.id, 'tile-1');
    expect(restored.type, HomeTileType.routingPreset);
    expect(restored.size, HomeTileSize.wide);
    expect(restored.position, 4);
    expect(restored.radiusStyle, HomeTileRadiusStyle.pill);
    expect(restored.contentAlign, HomeTileContentAlign.center);
  });

  test('fromJson falls back to rounded radius, start align and position 0 on missing/unknown values', () {
    final restored = HomeTileConfig.fromJson({
      'id': 'tile-2',
      'type': 'serverIcon',
      'size': 'not-a-real-size',
      'radiusStyle': 'not-a-real-style',
    });

    expect(restored.size, HomeTileSize.small); // единственный поддерживаемый размер serverIcon
    expect(restored.position, 0);
    expect(restored.radiusStyle, HomeTileRadiusStyle.rounded);
    expect(restored.contentAlign, HomeTileContentAlign.start);
  });

  test('defaultHomeTiles: server info + mode selector, wide + pill, one per row', () {
    expect(defaultHomeTiles.length, 2);
    expect(defaultHomeTiles[0].type, HomeTileType.serverInfo);
    expect(defaultHomeTiles[0].size, HomeTileSize.wide);
    expect(defaultHomeTiles[0].position, 0);
    expect(defaultHomeTiles[0].radiusStyle, HomeTileRadiusStyle.pill);
    expect(defaultHomeTiles[1].type, HomeTileType.modeSelector);
    expect(defaultHomeTiles[1].size, HomeTileSize.wide);
    expect(defaultHomeTiles[1].position, homeTileColumns);
    expect(defaultHomeTiles[1].radiusStyle, HomeTileRadiusStyle.pill);
  });

  test('HomeTileConfig.create picks the first supported size for the type and the given position', () {
    final tile = HomeTileConfig.create(HomeTileType.serverIcon, position: 7);
    expect(tile.size, HomeTileSize.small);
    expect(tile.position, 7);
    expect(tile.radiusStyle, HomeTileRadiusStyle.rounded);
  });

  test('copyWith only changes the requested fields', () {
    const tile = HomeTileConfig(
      id: 'tile-3',
      type: HomeTileType.serverStatus,
      size: HomeTileSize.small,
      position: 2,
    );
    final resized = tile.copyWith(size: HomeTileSize.wide, position: 0);

    expect(resized.id, tile.id);
    expect(resized.type, tile.type);
    expect(resized.size, HomeTileSize.wide);
    expect(resized.position, 0);
    expect(resized.radiusStyle, tile.radiusStyle);
    expect(resized.contentAlign, tile.contentAlign);
  });
}
