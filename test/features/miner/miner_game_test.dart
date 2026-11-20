import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flux/features/miner/miner_game.dart';
import 'package:flux/features/miner/miner_store.dart';

MinerGame _world() => MinerGame.fresh(seed: 12);

void main() {
  test('mining takes multiple hits, moves only on break and collects once', () {
    final game = _world();
    game.tiles[game.index(7, 1)] = MineTile.gold;
    for (var i = 0; i < 4; i++) {
      expect(game.step(0, 1), MineAction.hit);
      expect(game.y, 0);
    }
    expect(game.step(0, 1), MineAction.mined);
    expect(game.y, 1);
    expect(game.cargo[MineTile.gold], 1);
    expect(game.mined, 1);
    game.step(0, -1);
    expect(game.step(0, 1), MineAction.moved);
    expect(game.cargo[MineTile.gold], 1);
  });

  test(
    'full backpack preserves ore and still permits digging a route home',
    () {
      final game = _world();
      game.cargo[MineTile.coal] = game.capacity;
      game.tiles[game.index(7, 1)] = MineTile.copper;
      expect(game.step(0, 1), MineAction.full);
      expect(game.tile(7, 1), MineTile.copper);
      expect(game.damage, isEmpty);
      game.tiles[game.index(7, 1)] = MineTile.dirt;
      expect(game.step(0, 1), MineAction.mined);
      expect(game.load, game.capacity);
      expect(game.sell(), 0);
      game.surface();
      expect(game.sell(), 40);
      expect(game.load, 0);
      expect(game.sell(), 0);
    },
  );

  test('upgrades spend coins, require surface and stop at the maximum', () {
    final game = _world()..coins = 10000;
    final price = game.pickCost;
    expect(game.upgradePick(), isTrue);
    expect(game.coins, 10000 - price);
    game.tiles[game.index(7, 1)] = MineTile.stone;
    expect(game.step(0, 1), MineAction.hit);
    expect(game.step(0, 1), MineAction.mined);
    expect(game.upgradeBag(), isFalse);
    game.surface();
    expect(game.upgradeBag(), isTrue);
    expect(game.capacity, 14);
    game.pickLevel = 5;
    expect(game.upgradePick(), isFalse);
  });

  test('save roundtrip and a new shaft preserve economy and progress', () {
    final game = _world()
      ..coins = 400
      ..pickLevel = 2
      ..bagLevel = 1;
    game.tiles[game.index(7, 1)] = MineTile.gold;
    game.step(0, 1);
    final restored = MinerGame.fromJson(game.toJson());
    expect(restored.toJson(), game.toJson());
    game.step(0, 1);
    expect(game.y, 1);
    game.surface();
    game.newShaft();
    expect(game.coins, 400);
    expect(game.pickLevel, 2);
    expect(game.bagLevel, 1);
    expect(game.cargo[MineTile.gold], 1);
    expect(game.bestDepth, 1);
    expect(game.damage, isEmpty);
    expect(game.y, 0);
  });

  test('map boundaries and invalid saves are rejected', () {
    final game = _world();
    expect(game.step(0, -1), MineAction.blocked);
    expect(game.step(1, 1), MineAction.blocked);
    final json = game.toJson()..['x'] = -1;
    expect(() => MinerGame.fromJson(json), throwsFormatException);
    final badTiles = game.toJson()..['tiles'] = [];
    expect(() => MinerGame.fromJson(badTiles), throwsFormatException);
  });

  test('on-disk saves restore partially mined blocks and inventory', () async {
    final directory = await Directory.systemTemp.createTemp('flux-miner-test-');
    addTearDown(() => directory.delete(recursive: true));
    final store = MinerStore(directory: directory);
    expect(await store.load(), isNull);
    final game = _world();
    game.tiles[game.index(7, 1)] = MineTile.crystal;
    game.step(0, 1);
    await store.save(game.toJson());
    expect((await store.load())!.toJson(), game.toJson());
  });
}
