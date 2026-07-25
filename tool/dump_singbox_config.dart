// Печатает сгенерированный sing-box-конфиг TUN-моста в stdout, чтобы его можно
// было сверить с настоящим бинарником, не запуская сам TUN-режим.
//
// Схема sing-box меняется между минорными версиями и уже трижды ломала TUN
// молча — удалённое поле `sniff` на inbound, обязательный
// `default_domain_resolver`, запрещённый `detour: direct` у DNS-сервера, —
// причём каждый раз единственным симптомом было «после включения TUN пропал
// интернет».
//
// Двух проверок мало по отдельности, нужны обе:
//
//   dart run tool/dump_singbox_config.dart > cfg.json
//   sing-box check -c cfg.json           # схема
//
//   dart run tool/dump_singbox_config.dart --probe-inbound > probe.json
//   sing-box run -c probe.json           # старт сервиса
//
// `check` проверяет только разбор конфига и пропускает ошибки уровня «сервис не
// поднялся» (`detour to an empty direct outbound makes no sense` вылезает именно
// на `run`). А `run` с настоящим tun-inbound требует админских прав и трогает
// системные маршруты, поэтому `--probe-inbound` подменяет только его на
// локальный socks — всё остальное (DNS-серверы, outbounds, правила роутинга)
// остаётся ровно тем, что уйдёт в бой. Чистый старт probe-конфига означает, что
// непроверенным остаётся один tun-inbound.
import 'dart:convert';
import 'dart:io';

import 'package:flux/engines/singbox/singbox_config_mapper.dart';

void main(List<String> args) {
  final config = buildSingBoxTunBridgeConfig(
    socksInPort: 10808,
    serverHost: 'de1.example.com',
    serverIps: const ['203.0.113.7', '2001:db8::1'],
  );

  if (args.contains('--probe-inbound')) {
    config['inbounds'] = [
      {
        'type': 'socks',
        'tag': 'probe-in',
        'listen': '127.0.0.1',
        'listen_port': 10998,
      },
    ];
    // В боевом конфиге уровень `warn`, при котором успешный старт вообще ничем
    // себя не проявляет — а тут отличать «поднялся» от «молча ничего не сделал»
    // и есть весь смысл упражнения.
    config['log'] = {'level': 'info'};
  }

  stdout.writeln(const JsonEncoder.withIndent('  ').convert(config));
}
