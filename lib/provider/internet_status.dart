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

import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'internet_status.g.dart';

/// \todo document
@Riverpod(keepAlive: true)
Stream<InternetStatus> internetStatus(ref) async* {
  final stream = InternetConnection.createInstance(
    customCheckOptions: [
      InternetCheckOption(uri: Uri.parse('https://openremise.at')),
      InternetCheckOption(uri: Uri.parse('https://www.zimo.at')),
    ],
    useDefaultOptions: false,
  ).onStatusChange;
  await for (final status in stream) {
    yield status;
  }
}
