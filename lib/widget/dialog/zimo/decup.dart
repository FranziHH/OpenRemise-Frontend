// Copyright (C) 2025 Vincent Hamp
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:math';

import 'package:Frontend/constant/ws_batch_size.dart';
import 'package:Frontend/constant/zimo/mx_decoder_ids.dart';
import 'package:Frontend/model/zimo/zpp.dart';
import 'package:Frontend/model/zimo/zsu.dart';
import 'package:Frontend/provider/zimo/decup_service.dart';
import 'package:Frontend/service/zimo/decup_service.dart';
import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// \todo document
class DecupDialog extends ConsumerStatefulWidget {
  final Zpp? _zpp;
  final Zsu? _zsu;

  const DecupDialog.zpp(this._zpp, {super.key}) : _zsu = null;
  const DecupDialog.zsu(this._zsu, {super.key}) : _zpp = null;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _DecupDialogState();
}

/// \todo document
class _DecupDialogState extends ConsumerState<DecupDialog> {
  static const int _retries = 10;
  late final DecupService _decup;
  late final StreamQueue<Uint8List> _events;
  final Map<int, ListTile> _decoders = {};
  String _status = '';
  String _option = 'Cancel';
  double? _progress;

  /// \todo document
  @override
  void initState() {
    super.initState();
    _decup =
        ref.read(decupServiceProvider(widget._zpp != null ? 'zpp/' : 'zsu/'));
    _events = StreamQueue(_decup.stream);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _execute().catchError((_) {}),
    );
  }

  /// \todo document
  @override
  void dispose() {
    _events.cancel();
    _decup.close();
    super.dispose();
  }

  /// \todo document
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('DECUP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: _progress),
          Text(_status),
          AnimatedSize(
            alignment: Alignment.topCenter,
            curve: Curves.easeIn,
            duration: const Duration(milliseconds: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final tile in _decoders.values) tile],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_option),
        ),
      ],
      shape: RoundedRectangleBorder(
        side: Divider.createBorderSide(context),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  /// \todo document
  Future<void> _execute() async {
    await _connect();

    // ZPP
    if (widget._zpp != null) {
      for (var i = 0; i < 300; ++i) {
        await _zppPreamble();
      }
      var msg = await _zppSearch();
      if (!msg.contains(DecupService.ack)) return;
      msg = await _zppErase();
      if (!msg.contains(DecupService.ack)) return;
      msg = await _zppUpdate(widget._zpp!.flash);
      if (!msg.contains(DecupService.ack)) return;
      msg = await _zppCvs();
      if (!msg.contains(DecupService.ack)) return;
    }
    // ZSU
    else {
      for (var i = 0; i < 300; ++i) {
        await _zsuPreamble();
      }
      var msg = await _zsuSearch();
      if (!msg.contains(DecupService.ack)) return;
      msg = await _zsuBlockCount();
      if (!msg.contains(DecupService.nak)) return;
      msg = await _zsuSecurityBytes();
      if (!msg.contains(DecupService.nak)) return;
      msg = await _zsuUpdate();
      if (!msg.contains(DecupService.ack)) return;
    }

    await _disconnect();
  }

  /// \todo document
  Future<void> _connect() async {
    _updateEphemeralState(status: 'Connecting');
    await _decup.ready;
  }

  /// \todo document
  Future<void> _zppPreamble() async {
    _decup.zppPreamble();
    await _events.next;
  }

  /// \todo document
  Future<Uint8List> _zppSearch() async {
    _decup.zppReadCv(7);
    var msgs = await _events.take(8);
    if (msgs.any((msg) => msg.isEmpty) || _decup.closeReason != null) {
      _updateEphemeralState(
        status: _decup.closeReason ?? 'Could not read CV8',
        progress: 0,
      );
      return Uint8List.fromList([]);
    }
    final cv8 = msgs.reversed.fold<int>(
      0,
      (prev, cur) => prev << 1 | (cur.first == DecupService.ack ? 1 : 0),
    );
    if (cv8 != 145) {
      _updateEphemeralState(
        status: 'Unknown decoder manufacturer',
        progress: 0,
      );
      return Uint8List.fromList([]);
    }

    _decup.zppDecoderId();
    msgs = await _events.take(8);
    if (msgs.any((msg) => msg.isEmpty) || _decup.closeReason != null) {
      _updateEphemeralState(
        status: _decup.closeReason ?? 'Could not read decoder ID',
        progress: 0,
      );
      return Uint8List.fromList([]);
    }
    final id = msgs.reversed.fold<int>(
      0,
      (prev, cur) => prev << 1 | (cur.first == DecupService.ack ? 1 : 0),
    );
    if (!mxDecoderIds.contains(id)) {
      _updateEphemeralState(status: 'Unknown decoder ID', progress: 0);
      return Uint8List.fromList([]);
    }

    return Uint8List.fromList([DecupService.ack]);
  }

  /// \todo document
  Future<Uint8List> _zppErase() async {
    _updateEphemeralState(status: 'Erasing');
    _decup.zppErase();
    await _events.next;

    // and here... check every... 10s with... some command?
    // return if it returns something useful
    for (var i = 0; i < 6; ++i) {
      await Future.delayed(const Duration(seconds: 10));
      _decup.zppDecoderId();
      final msgs = await _events.take(8);
      if (!msgs.any((msg) => msg.isEmpty)) {
        return Uint8List.fromList([DecupService.ack]);
      }
    }

    _updateEphemeralState(status: 'Erasing failed', progress: 0);
    return Uint8List.fromList([]);
  }

  /// \todo document
  Future<Uint8List> _zppUpdate(Uint8List bin) async {
    _updateEphemeralState(status: 'Writing');

    const int blockSize = 256;
    final blocks = bin.slices(blockSize).toList();

    int i = 0;
    int failCount = 0;
    while (i < blocks.length) {
      // Number of blocks transmit at once
      final n = min(wsBatchSize, blocks.length - i);
      for (var j = 0; j < n; ++j) {
        _decup.zppBlocks(i + j, Uint8List.fromList(blocks[i + j]));
      }

      // Wait for all responses
      for (final msg in await _events.take(n)) {
        // Go either forward
        if (msg.contains(DecupService.ack)) {
          failCount = 0;
          ++i;
        }
        // Or back (limited number of times)
        else if (failCount < _retries) {
          ++failCount;
          i = max(i - 1, 0);
          break;
        }
        // Or bail
        else {
          _updateEphemeralState(status: 'Writing failed', progress: 0);
          return Uint8List.fromList([]);
        }
      }

      // WebSocket closed on the server side
      if (_decup.closeReason != null) {
        _updateEphemeralState(status: _decup.closeReason, progress: 0);
        return Uint8List.fromList([]);
      }

      // Update progress
      _updateEphemeralState(
        status:
            'Writing ${i * blockSize ~/ 1024} / ${blocks.length * blockSize ~/ 1024} kB',
        progress: i / blocks.length,
      );
    }

    return Uint8List.fromList([DecupService.ack]);
  }

  /// \todo document
  Future<Uint8List> _zppCvs() async {
    int i = 0;
    for (final entry in widget._zpp!.cvs.entries) {
      final msg = await _retryOnFailure(
        () => _decup.zppWriteCv(entry.key, entry.value),
      );
      if (!msg.contains(DecupService.ack) || _decup.closeReason != null) {
        _updateEphemeralState(
          status: _decup.closeReason ?? 'Writing CVs failed',
          progress: 0,
        );
        return Uint8List.fromList([]);
      }

      // Update progress
      _updateEphemeralState(
        status: 'Writing ${++i} / ${widget._zpp!.cvs.length} CVs',
        progress: i / widget._zpp!.cvs.length,
      );
    }
    return Uint8List.fromList([DecupService.ack]);
  }

  /// \todo document
  Future<void> _zsuPreamble() async {
    _decup.zsuPreamble();
    await _events.next;
  }

  /// \todo document
  Future<Uint8List> _zsuSearch() async {
    _updateEphemeralState(status: 'Search decoder');

    for (final entry in widget._zsu!.firmwares.entries) {
      final decoderId = entry.key;
      _decup.zsuDecoderId(decoderId);
      final msg = await _events.next;
      if (msg.contains(DecupService.ack)) {
        _updateEphemeralState(
          decoder: MapEntry(
            decoderId,
            ListTile(
              leading: const Icon(Icons.circle),
              title: Text(entry.value.name),
            ),
          ),
        );
        break;
      }
    }

    if (_decoders.isEmpty) {
      _updateEphemeralState(status: 'No decoder found', progress: 0);
      return Uint8List.fromList([]);
    }

    return Uint8List.fromList([DecupService.ack]);
  }

  /// \todo document
  Future<Uint8List> _zsuBlockCount() async {
    final blockCount =
        (widget._zsu!.firmwares[_decoders.keys.first]!.bin.length ~/ 256 +
            8 -
            1);
    _decup.zsuBlockCount(blockCount);
    final msg = await _events.next;
    if (!msg.contains(DecupService.nak) || _decup.closeReason != null) {
      _updateEphemeralState(
        status: _decup.closeReason ?? 'Block count not acknowledged',
        progress: 0,
      );
      return Uint8List.fromList([]);
    }
    return Uint8List.fromList([DecupService.nak]);
  }

  /// \todo document
  Future<Uint8List> _zsuSecurityBytes() async {
    _decup.zsuSecurityByte1();
    final msg1 = await _events.next;
    _decup.zsuSecurityByte2();
    final msg2 = await _events.next;
    if (!msg1.contains(DecupService.nak) ||
        !msg2.contains(DecupService.nak) ||
        _decup.closeReason != null) {
      _updateEphemeralState(
        status: _decup.closeReason ?? 'Security byte not acknowledged',
        progress: 0,
      );
      return Uint8List.fromList([]);
    }
    return Uint8List.fromList([DecupService.nak]);
  }

  /// \todo document
  Future<Uint8List> _zsuUpdate() async {
    final decoderId = _decoders.keys.first;

    // Write flash
    _updateEphemeralState(
      status: 'Writing',
      decoder: MapEntry(
        decoderId,
        ListTile(
          leading: const Icon(Icons.download_for_offline),
          title: _decoders[decoderId]!.title,
        ),
      ),
    );

    final blockSize =
        decoderId == 200 || (decoderId >= 202 && decoderId <= 205) ? 32 : 64;
    final blocks =
        widget._zsu!.firmwares[decoderId]!.bin.slices(blockSize).toList();

    int i = 0;
    int failCount = 0;
    while (i < blocks.length) {
      // Number of blocks transmit at once
      final n = min(wsBatchSize, blocks.length - i);
      for (var j = 0; j < n; ++j) {
        _decup.zsuBlocks(i + j, Uint8List.fromList(blocks[i + j]));
      }

      // Wait for all responses
      for (final msg in await _events.take(n)) {
        // Go either forward
        if (msg.contains(DecupService.ack)) {
          failCount = 0;
          ++i;
        }
        // Or back (limited number of times)
        else if (failCount < _retries) {
          ++failCount;
          i = max(i - 1, 0);
          break;
        }
        // Or bail
        else {
          _updateEphemeralState(
            status: 'Writing failed',
            progress: 0,
            decoder: MapEntry(
              decoderId,
              ListTile(
                leading: const Icon(Icons.error),
                title: _decoders[decoderId]!.title,
              ),
            ),
          );
          return Uint8List.fromList([]);
        }
      }

      // WebSocket closed on the server side
      if (_decup.closeReason != null) {
        _updateEphemeralState(
          status: _decup.closeReason,
          progress: 0,
          decoder: MapEntry(
            decoderId,
            ListTile(
              leading: const Icon(Icons.error),
              title: _decoders[decoderId]!.title,
            ),
          ),
        );
        return Uint8List.fromList([]);
      }

      // Update progress
      _updateEphemeralState(
        status:
            'Writing ${i * blockSize ~/ 1024} / ${blocks.length * blockSize ~/ 1024} kB',
        progress: i / blocks.length,
      );
    }

    // Done
    _updateEphemeralState(
      decoder: MapEntry(
        decoderId,
        ListTile(
          leading: const Icon(Icons.check_circle),
          title: _decoders[decoderId]!.title,
        ),
      ),
    );
    return Uint8List.fromList([DecupService.ack]);
  }

  /// \todo document
  Future<void> _disconnect() async {
    await Future.delayed(const Duration(seconds: 1));
    _updateEphemeralState(status: 'Done', option: 'OK');
    await _decup.close();
  }

  /// \todo document
  Future<Uint8List> _retryOnFailure(
    Function() f, {
    int retries = _retries,
  }) async {
    var msg = Uint8List.fromList([]);
    for (int i = 0; i < retries; i++) {
      f();
      msg = await _events.next;
      if (msg.contains(DecupService.ack)) return msg;
    }
    return msg;
  }

  /// \todo document
  Future<void> _updateEphemeralState({
    String? status,
    String? option,
    double? progress,
    MapEntry<int, ListTile>? decoder,
  }) async {
    setState(
      () {
        if (status != null) _status = status;
        if (option != null) _option = option;
        if (progress != null) _progress = progress;
        if (decoder != null) _decoders[decoder.key] = decoder.value;
      },
    );
  }

  /// \todo document
  @override
  void setState(VoidCallback fn) {
    if (!mounted) return;
    super.setState(fn);
  }
}
