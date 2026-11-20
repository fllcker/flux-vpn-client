import 'dart:math';

enum MineTile { air, dirt, stone, coal, copper, gold, crystal }

enum MineAction { moved, hit, mined, full, blocked }

extension MineTileInfo on MineTile {
  int get hardness => [0, 1, 3, 2, 3, 5, 8][index];
  int get price => [0, 0, 0, 5, 12, 35, 100][index];
  bool get ore => price > 0;
}

class MinerGame {
  static const width = 15;
  static const height = 81;
  final List<MineTile> tiles;
  final Map<int, int> damage;
  final Map<MineTile, int> cargo;
  int seed;
  int x;
  int y;
  int coins;
  int pickLevel;
  int bagLevel;
  int bestDepth;
  int mined;

  MinerGame({
    required this.seed,
    required this.tiles,
    Map<int, int>? damage,
    Map<MineTile, int>? cargo,
    this.x = 7,
    this.y = 0,
    this.coins = 0,
    this.pickLevel = 0,
    this.bagLevel = 0,
    this.bestDepth = 0,
    this.mined = 0,
  }) : damage = damage ?? {},
       cargo = cargo ?? {};

  factory MinerGame.fresh({int? seed}) {
    final worldSeed = seed ?? DateTime.now().microsecondsSinceEpoch;
    final random = Random(worldSeed);
    return MinerGame(
      seed: worldSeed,
      tiles: [
        for (var row = 0; row < height; row++)
          for (var col = 0; col < width; col++)
            if (row == 0) MineTile.air else _generate(random, row),
      ],
    );
  }

  static MineTile _generate(Random random, int row) {
    final roll = random.nextDouble();
    if (row > 35 && roll < .065) return MineTile.crystal;
    if (row > 16 && roll < .13) return MineTile.gold;
    if (roll < .25) return MineTile.copper;
    if (roll < .40) return MineTile.coal;
    return random.nextDouble() < .28 + row / 160
        ? MineTile.stone
        : MineTile.dirt;
  }

  int get capacity => 8 + bagLevel * 6;
  int get load => cargo.values.fold(0, (a, b) => a + b);
  int get cargoValue =>
      cargo.entries.fold(0, (sum, e) => sum + e.key.price * e.value);
  int get pickCost => 40 * (1 << pickLevel);
  int get bagCost => 55 * (1 << bagLevel);
  bool get atSurface => y == 0;
  int index(int col, int row) => row * width + col;
  MineTile tile(int col, int row) => tiles[index(col, row)];

  MineAction step(int dx, int dy) {
    if (dx.abs() + dy.abs() != 1) return MineAction.blocked;
    final nx = x + dx, ny = y + dy;
    if (nx < 0 || nx >= width || ny < 0 || ny >= height) {
      return MineAction.blocked;
    }
    final i = index(nx, ny);
    final target = tiles[i];
    if (target.ore && load >= capacity) return MineAction.full;
    if (target != MineTile.air) {
      final hits = (damage[i] ?? 0) + pickLevel + 1;
      if (hits < target.hardness) {
        damage[i] = hits;
        return MineAction.hit;
      }
      damage.remove(i);
      tiles[i] = MineTile.air;
      mined++;
      if (target.ore) cargo.update(target, (v) => v + 1, ifAbsent: () => 1);
    }
    x = nx;
    y = ny;
    bestDepth = max(bestDepth, y);
    return target == MineTile.air ? MineAction.moved : MineAction.mined;
  }

  void surface() {
    x = width ~/ 2;
    y = 0;
  }

  int sell() {
    if (!atSurface) return 0;
    final earned = cargoValue;
    coins += earned;
    cargo.clear();
    return earned;
  }

  bool upgradePick() {
    if (!atSurface || pickLevel >= 5 || coins < pickCost) return false;
    coins -= pickCost;
    pickLevel++;
    return true;
  }

  bool upgradeBag() {
    if (!atSurface || bagLevel >= 5 || coins < bagCost) return false;
    coins -= bagCost;
    bagLevel++;
    return true;
  }

  void newShaft() {
    if (!atSurface) return;
    final fresh = MinerGame.fresh();
    seed = fresh.seed;
    tiles.setAll(0, fresh.tiles);
    damage.clear();
    surface();
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'seed': seed,
    'tiles': tiles.map((t) => t.index).toList(),
    'damage': {for (final e in damage.entries) '${e.key}': e.value},
    'cargo': {for (final e in cargo.entries) '${e.key.index}': e.value},
    'x': x,
    'y': y,
    'coins': coins,
    'pick': pickLevel,
    'bag': bagLevel,
    'best': bestDepth,
    'mined': mined,
  };

  factory MinerGame.fromJson(Map<String, dynamic> json) {
    int bounded(String key, int min, int max) {
      final value = json[key];
      if (value is! int || value < min || value > max) {
        throw FormatException('Invalid $key');
      }
      return value;
    }

    if (json['version'] != 1) throw const FormatException('Unknown mine save');
    final raw = json['tiles'] as List;
    if (raw.length != width * height) {
      throw const FormatException('Invalid map size');
    }
    final tiles = [
      for (final value in raw)
        if (value is int && value >= 0 && value < MineTile.values.length)
          MineTile.values[value]
        else
          throw const FormatException('Invalid tile'),
    ];
    final game = MinerGame(
      seed: json['seed'] as int,
      tiles: tiles,
      x: bounded('x', 0, width - 1),
      y: bounded('y', 0, height - 1),
      coins: bounded('coins', 0, 1 << 40),
      pickLevel: bounded('pick', 0, 5),
      bagLevel: bounded('bag', 0, 5),
      bestDepth: bounded('best', 0, height - 1),
      mined: bounded('mined', 0, 1 << 40),
    );
    if (game.tile(game.x, game.y) != MineTile.air ||
        tiles.take(width).any((t) => t != MineTile.air)) {
      throw const FormatException('Miner inside rock');
    }
    for (final e in (json['cargo'] as Map).entries) {
      final tile = MineTile.values[int.parse(e.key as String)];
      if (!tile.ore || e.value is! int || e.value < 0) {
        throw const FormatException('Invalid cargo');
      }
      game.cargo[tile] = e.value as int;
    }
    if (game.load > game.capacity) {
      throw const FormatException('Cargo overflow');
    }
    for (final e in (json['damage'] as Map).entries) {
      final i = int.parse(e.key as String);
      if (i < width ||
          i >= tiles.length ||
          e.value is! int ||
          e.value <= 0 ||
          e.value >= tiles[i].hardness) {
        throw const FormatException('Invalid damage');
      }
      game.damage[i] = e.value as int;
    }
    return game;
  }
}
