//
//  TolerantDecoding.swift
//  Politici
//

import Foundation

/// A `String`-backed enum with a designated fallback case, so decoding an
/// unrecognized raw value never throws — real open-data sources may add new
/// codes over time, and a decode failure shouldn't take down the whole file.
///
/// Conformers must implement `init(from:)` themselves by calling
/// `decodeTolerant(from:)` directly (rather than relying on this protocol's
/// extension alone) — Swift's compiler-synthesized `Decodable` for raw-value
/// enums takes precedence over a protocol extension's default witness, so a
/// `enum Foo: String, TolerantStringEnum` declaration alone would silently
/// fall back to the throwing, non-tolerant synthesized decoder.
protocol TolerantStringEnum: RawRepresentable where RawValue == String {
    static var unknownCase: Self { get }
}

extension TolerantStringEnum {
    static func decodeTolerant(from decoder: Decoder) throws -> Self {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        return Self(rawValue: raw) ?? unknownCase
    }
}
