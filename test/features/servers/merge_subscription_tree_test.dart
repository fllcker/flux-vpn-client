import 'package:flutter_test/flutter_test.dart';
import 'package:flux/core_abstraction/proxy_node.dart';
import 'package:flux/core_abstraction/server_config.dart';
import 'package:flux/features/servers/merge_subscription_tree.dart';

const _germanyVariant = ConnectionVariant(
  id: 'old-variant-de',
  label: 'TCP Reality',
  config: VlessConfig(address: 'de1.example.com', port: 443, uuid: 'u1'),
);
const _polandVariant = ConnectionVariant(
  id: 'old-variant-pl',
  label: 'TCP Reality',
  config: VlessConfig(address: 'pl1.example.com', port: 443, uuid: 'u2'),
);

const _germanyLeaf = ServerLeaf(
  id: 'old-germany',
  name: 'Germany 1',
  hidden: true,
  variants: [_germanyVariant],
  selection: ManualVariantSelection('old-variant-de'),
);
const _polandLeaf = ServerLeaf(
  id: 'old-poland',
  name: 'Poland 1',
  variants: [_polandVariant],
  selection: ManualVariantSelection('old-variant-pl'),
);

void main() {
  test('keeps hidden and selection for a leaf matched by address', () {
    final oldRoot = ServerGroup(
      id: 'old-root',
      name: 'Sub',
      children: [_germanyLeaf, _polandLeaf],
    );
    final newRoot = ServerGroup(
      id: 'new-root',
      name: 'Sub',
      children: [
        const ServerLeaf(
          id: 'new-germany',
          name: 'Germany 1',
          variants: [
            ConnectionVariant(
              id: 'new-variant-de',
              label: 'TCP Reality',
              config: VlessConfig(
                address: 'de1.example.com',
                port: 443,
                uuid: 'u1-rotated',
              ),
            ),
          ],
          selection: ManualVariantSelection('new-variant-de'),
        ),
      ],
    );

    final merged = mergeSubscriptionTree(oldRoot, newRoot) as ServerGroup;
    final leaf = merged.children.single as ServerLeaf;

    // Старый id листа и варианта сохранён, чтобы selectedServerIdProvider и
    // выбор варианта не слетели на этом же рефреше.
    expect(leaf.id, 'old-germany');
    expect(leaf.hidden, isTrue);
    expect(leaf.variants.single.id, 'old-variant-de');
    // Содержимое конфига при этом всё равно берётся свежее (например,
    // ротация uuid/пароля должна долетать до подключения).
    expect(
      (leaf.variants.single.config as VlessConfig).uuid,
      'u1-rotated',
    );
    expect(leaf.selection, isA<ManualVariantSelection>());
    expect(
      (leaf.selection as ManualVariantSelection).variantId,
      'old-variant-de',
    );
  });

  test('a server missing from the fresh subscription is dropped', () {
    final oldRoot = ServerGroup(
      id: 'old-root',
      name: 'Sub',
      children: [_germanyLeaf, _polandLeaf],
    );
    final newRoot = ServerGroup(
      id: 'new-root',
      name: 'Sub',
      children: [_germanyLeaf],
    );

    final merged = mergeSubscriptionTree(oldRoot, newRoot) as ServerGroup;

    expect(merged.children, hasLength(1));
    expect((merged.children.single as ServerLeaf).id, 'old-germany');
  });

  test('a brand-new server keeps its freshly generated id and selection', () {
    final oldRoot = ServerGroup(id: 'old-root', name: 'Sub', children: const []);
    final newRoot = ServerGroup(
      id: 'new-root',
      name: 'Sub',
      children: [_polandLeaf],
    );

    final merged = mergeSubscriptionTree(oldRoot, newRoot) as ServerGroup;

    expect((merged.children.single as ServerLeaf).id, 'old-poland');
  });

  test('routing rules come from the fresh subscription data, not preserved', () {
    const oldGermanyWithRules = ServerLeaf(
      id: 'old-germany',
      name: 'Germany 1',
      variants: [_germanyVariant],
      selection: ManualVariantSelection('old-variant-de'),
      routingRules: [
        DomainRule(values: ['old-rule.example.com'], outboundTag: 'block'),
      ],
    );
    final oldRoot = ServerGroup(
      id: 'old-root',
      name: 'Sub',
      children: [oldGermanyWithRules],
    );
    final newRoot = ServerGroup(
      id: 'new-root',
      name: 'Sub',
      children: [
        const ServerLeaf(
          id: 'new-germany',
          name: 'Germany 1',
          variants: [_germanyVariant],
          selection: ManualVariantSelection('old-variant-de'),
          routingRules: [
            DomainRule(values: ['new-rule.example.com'], outboundTag: 'proxy'),
          ],
        ),
      ],
    );

    final merged = mergeSubscriptionTree(oldRoot, newRoot) as ServerGroup;
    final leaf = merged.children.single as ServerLeaf;
    final rule = leaf.routingRules.single as DomainRule;

    expect(rule.values, ['new-rule.example.com']);
    expect(rule.outboundTag, 'proxy');
  });

  test('new variant on an existing leaf gets a fresh id, unmatched selection falls back', () {
    final oldRoot = ServerGroup(
      id: 'old-root',
      name: 'Sub',
      children: [_germanyLeaf],
    );
    final newRoot = ServerGroup(
      id: 'new-root',
      name: 'Sub',
      children: [
        const ServerLeaf(
          id: 'new-germany',
          name: 'Germany 1',
          variants: [
            ConnectionVariant(
              id: 'new-variant-xhttp',
              label: 'XHTTP Reality',
              config: VlessConfig(
                address: 'de1.example.com',
                port: 2053,
                uuid: 'u1',
              ),
            ),
          ],
          selection: ManualVariantSelection('new-variant-xhttp'),
        ),
      ],
    );

    final merged = mergeSubscriptionTree(oldRoot, newRoot) as ServerGroup;
    final leaf = merged.children.single as ServerLeaf;

    expect(leaf.id, 'old-germany');
    // Новый вариант (другая подпись) не совпал ни с одним старым — id
    // остаётся свежесгенерированным.
    expect(leaf.variants.single.id, 'new-variant-xhttp');
    // Старый ManualVariantSelection('old-variant-de') больше не указывает
    // ни на один из новых вариантов — используется свежий выбор.
    expect(
      (leaf.selection as ManualVariantSelection).variantId,
      'new-variant-xhttp',
    );
  });
}
