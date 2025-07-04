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

// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'config.freezed.dart';
part 'config.g.dart';

/// \todo document
@freezed
abstract class Config with _$Config {
  const factory Config({
    @JsonKey(name: 'sta_mdns') String? stationMdns,
    @JsonKey(name: 'sta_ssid') String? stationSsid,
    @JsonKey(name: 'sta_pass') String? stationPassword,
    @JsonKey(name: 'sta_alt_ssid') String? stationAlternativeSsid,
    @JsonKey(name: 'sta_alt_pass') String? stationAlternativePassword,
    @JsonKey(name: 'sta_ip') String? stationIp,
    @JsonKey(name: 'sta_netmask') String? stationNetmask,
    @JsonKey(name: 'sta_gateway') String? stationGateway,
    @JsonKey(name: 'http_rx_timeout') int? httpReceiveTimeout,
    @JsonKey(name: 'http_tx_timeout') int? httpTransmitTimeout,
    @JsonKey(name: 'http_exit_msg') bool? httpExitMessage,
    @JsonKey(name: 'cur_lim') int? currentLimit,
    @JsonKey(name: 'cur_lim_serv') int? currentLimitService,
    @JsonKey(name: 'cur_sc_time') int? currentShortCircuitTime,
    @JsonKey(name: 'led_dc_bug') int? ledDutyCycleBug,
    @JsonKey(name: 'led_dc_wifi') int? ledDutyCycleWiFi,
    @JsonKey(name: 'dcc_preamble') int? dccPreamble,
    @JsonKey(name: 'dcc_bit1_dur') int? dccBit1Duration,
    @JsonKey(name: 'dcc_bit0_dur') int? dccBit0Duration,
    @JsonKey(name: 'dcc_bidibit_dur') int? dccBiDiBitDuration,
    @JsonKey(name: 'dcc_prog_type') int? dccProgrammingType,
    @JsonKey(name: 'dcc_strtp_rs_pc') int? dccStartupResetPacketCount,
    @JsonKey(name: 'dcc_cntn_rs_pc') int? dccContinueResetPacketCount,
    @JsonKey(name: 'dcc_prog_pc') int? dccProgramPacketCount,
    @JsonKey(name: 'dcc_verify_bit1') bool? dccBitVerifyTo1,
    @JsonKey(name: 'dcc_ack_cur') int? dccProgrammingAckCurrent,
    @JsonKey(name: 'dcc_loco_flags') int? dccLocoFlags,
    @JsonKey(name: 'dcc_accy_flags') int? dccAccyFlags,
  }) = _Config;

  factory Config.fromJson(Map<String, Object?> json) => _$ConfigFromJson(json);
}
