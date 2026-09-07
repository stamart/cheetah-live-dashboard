import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'gt7_telemetry.dart';

/// GT7's UDP telemetry packet: 296-byte Salsa20-encrypted blob, key is a fixed
/// string PD ships in the game (community reverse-engineered, e.g.
/// snipem/gt7dashboard, Nenkai/PDTools). Nonce is derived from 4 bytes in the
/// packet itself, XORed with a magic constant — note it's 0xDEADBEAF, not the
/// more common 0xDEADBEEF typo-lookalike; this exact constant is required.
const _kGt7Key = 'Simulator Interface Packet GT7 ver 0.0';
const _kMagic = 0x47375330; // "0S7G" little-endian — decrypted packet header
const _kNonceXor = 0xDEADBEAF;

/// Decrypts a raw GT7 UDP datagram. Returns null if the packet doesn't
/// decrypt to a valid GT7 header (garbage/out-of-sync packet — caller should
/// treat this as a transient miss, not a fatal error).
Uint8List? decryptGt7Packet(Uint8List data) {
  if (data.length < 0x44 + 4) return null;

  final keyBytes = Uint8List.fromList(ascii.encode(_kGt7Key).sublist(0, 32));

  final oiv = ByteData.sublistView(data, 0x40, 0x44);
  final iv1 = oiv.getUint32(0, Endian.little);
  final iv2 = iv1 ^ _kNonceXor;

  final iv = Uint8List(8);
  final ivView = ByteData.sublistView(iv);
  ivView.setUint32(0, iv2, Endian.little);
  ivView.setUint32(4, iv1, Endian.little);

  final cipher = Salsa20Engine()
    ..init(false, ParametersWithIV(KeyParameter(keyBytes), iv));

  final output = Uint8List(data.length);
  cipher.processBytes(data, 0, data.length, output, 0);

  final magic = ByteData.sublistView(output, 0, 4).getUint32(0, Endian.little);
  if (magic != _kMagic) return null;
  return output;
}

/// Extracts the fields we care about from a decrypted packet (byte offsets
/// verified against snipem/gt7dashboard's gt7communication.py). Packet type
/// 'A' only — the 'B'/'~'/'C' extended variants carry additional fields
/// (surface type, sway/heave/surge) that this app doesn't use.
Gt7Telemetry? parseGt7Packet(Uint8List d) {
  if (d.length < 0x94) return null;
  final bd = ByteData.sublistView(d);

  final speedMs = bd.getFloat32(0x4C, Endian.little);
  final rpm = bd.getFloat32(0x3C, Endian.little);
  final fuelLevel = bd.getFloat32(0x44, Endian.little);
  final fuelCapacity = bd.getFloat32(0x48, Endian.little);
  final currentLap = bd.getInt16(0x74, Endian.little);
  final bestLapMs = bd.getInt32(0x78, Endian.little);
  final lastLapMs = bd.getInt32(0x7C, Endian.little);
  final throttleRaw = d[0x91];
  final brakeRaw = d[0x92];
  final flags = d[0x8E];

  return Gt7Telemetry(
    speedKph: speedMs * 3.6,
    rpm: rpm,
    currentLap: currentLap,
    // -1 (0xFFFFFFFF) means "no time recorded yet" in GT7's packet.
    lastLapTimeMs: lastLapMs > 0 ? lastLapMs : null,
    bestLapTimeMs: bestLapMs > 0 ? bestLapMs : null,
    fuelPct: fuelCapacity > 0 ? (fuelLevel / fuelCapacity * 100).clamp(0, 100) : null,
    throttlePct: (throttleRaw / 2.55).clamp(0, 100),
    brakePct: (brakeRaw / 2.55).clamp(0, 100),
    inRace: (flags & 0x01) != 0,
    isPaused: (flags & 0x02) != 0,
  );
}
