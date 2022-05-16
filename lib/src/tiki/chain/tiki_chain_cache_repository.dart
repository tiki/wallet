/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */

import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_sqlcipher/sqlite_api.dart';
import 'package:tiki_localchain/tiki_localchain.dart';

import 'tiki_chain_cache_model.dart';

class TikiChainCacheRepository {
  static const String _table = 'localchain_cache';
  final _log = Logger('TikiChainCacheRepository');

  final Database _database;

  TikiChainCacheRepository(this._database);

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) =>
      _database.transaction(action);

  Future<void> createTable() =>
      _database.execute('CREATE TABLE IF NOT EXISTS $_table('
          'hash BLOB PRIMARY KEY, '
          'contents BLOB NOT NULL, '
          'previous_hash BLOB NOT NULL, '
          'created_epoch INTEGER NOT NULL, '
          'block_schema INTEGER NOT NULL);');

  Future<TikiChainCacheModel> insert(TikiChainCacheModel block,
      {Transaction? txn}) async {
    await (txn ?? _database).insert(_table, block.toMap());
    _log.finest('inserted: #${block.hash}');
    return block;
  }

  Future<void> insertAll(List<TikiChainCacheModel> blocks,
      {Transaction? txn}) async {
    Batch batch = (txn ?? _database).batch();
    for (var block in blocks) {
      batch.insert(_table, block.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> drop() => _database.delete(_table);

  Future<TikiChainCacheModel?> get(Uint8List hash, {Transaction? txn}) async {
    List<Map<String, Object?>> rows = await (txn ?? _database).query(_table,
        columns: [
          'hash',
          'contents',
          'previous_hash',
          'created_epoch',
          'block_schema'
        ],
        where: 'hash = ?',
        whereArgs: [hash]);
    if (rows.isEmpty) {
      _log.finest('$hash not found');
      return null;
    } else {
      _log.finest('got $hash');
      return TikiChainCacheModel.fromMap(rows[0]);
    }
  }

  Future<List<TikiChainCacheModel>> getDataNfts(int page, {int pageSize = 100, Transaction? txn}) async {
    int offset = page <= 1 ? 0 : pageSize * page - 1;
    List<Map<String, Object?>> rows = await (txn ?? _database).query(_table,
        where: 'block_schema = ?',
        whereArgs: [BlockContentsSchema.dataNft.code],
        offset: offset,
        limit: 100);
    if (rows.isEmpty) {
      _log.finest('no data nft blocks in cache page #$page');
      return [];
    } else {
      _log.finest('got data nft ${rows.length} blocks from page #$page');
      return rows.map((row) => TikiChainCacheModel.fromMap(row)).toList();
    }
  }
}
