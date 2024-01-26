//===----------------------------------------------------------*- swift -*-===//
//
// This source file is part of the Swift MMIO open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import SwiftSyntax
import SwiftSyntaxMacros

extension BitFieldDescription {
  func validate(
    in context: MacroContext<some ParsableMacro, some MacroExpansionContext>
  ) {
    precondition(self.bitRanges.count == self.bitRangeExpressions.count)
    for index in self.bitRanges.indices {
      self.validateBounds(
        bitRange: self.bitRanges[index],
        bitRangeExpression: self.bitRangeExpressions[index],
        in: context)
    }

    if self.bitRanges.count > 1 {
      self.validateOverlappingRanges(in: context)
    }
  }

  func validateBounds(
    bitRange: BitRange,
    bitRangeExpression: ExprSyntax,
    in context: MacroContext<some ParsableMacro, some MacroExpansionContext>
  ) {
    let range = 0..<self.bitWidth
    if let bound = bitRange.inclusiveLowerBound, !range.contains(bound) {
      _ = context.error(
        at: bitRangeExpression,
        message: .bitFieldOutOfRange(
          fieldName: "\(self.fieldName)",
          bitRange: "\(bitRangeExpression)",
          bitWidth: self.bitWidth))
    }

    if let bound = bitRange.inclusiveUpperBound, !range.contains(bound) {
      _ = context.error(
        at: bitRangeExpression,
        message: .bitFieldOutOfRange(
          fieldName: "\(self.fieldName)",
          bitRange: "\(bitRangeExpression)",
          bitWidth: self.bitWidth))
    }
  }

  /// Walk through the sorted array of bit ranges, forming error diagnostics
  /// of each overlapping pair of bit ranges.
  ///
  /// Given the example bit field:
  /// ```
  /// @BitField(bits: 0..<32, 8..<40, 16..<48)
  /// var field: Field
  /// ```
  ///
  /// Visually the ranges look like:
  /// ```
  ///                1         2         3         4         5
  ///      01234567890123456789012345678901234567890123456789
  /// min <──────────────────────────────────────────────────> max
  ///
  ///      0       8       16             31      39      47
  ///      ╎       ╎       ╎              ╎       ╎       ╎
  ///      ├──────────────────────────────┤       ╎       ╎
  ///      ╎       ├──────────────────────────────┤       ╎
  ///      ╎       ╎       ├──────────────────────────────┤
  ///      ╎       ╎       ╎              ╎       ╎       ╎
  ///      0       8       16             31      39      47
  /// ```
  ///
  /// The following diagnostics would be emitted:
  /// ```
  /// <location> error: bit field 'field' contains overlapping bit ranges
  /// var field: Field
  ///     ^~~~~
  ///
  /// <location> note: bits '8..<32' of range '0..<32' overlap bit ranges '8..<16' and '16..<48'
  /// @BitField(bits: 0..<32, 8..<40, 16..<48)
  ///                 ^~~~~~
  ///
  /// <location> note: bits '8..<40' of range '8..<40' overlap bit ranges '0..<32' and '16..<48'
  /// @BitField(bits: 0..<32, 8..<40, 16..<48)
  ///                         ^~~~~~
  ///
  /// <location> note: bits '16..<40' of range '16..<48' overlap bit ranges '0..<32' and '8..<40'
  /// @BitField(bits: 0..<32, 8..<40, 16..<48)
  ///                                 ^~~~~~~
  /// ```
  func validateOverlappingRanges(
    in context: MacroContext<some ParsableMacro, some MacroExpansionContext>
  ) {
    var indices = self.bitRanges.indices
    indices.sorted { self.bitRanges[$0] < self.bitRanges[$1] }

    var currentIndexBitRangeStart = indices.startIndex
    var currentIndexBitRangeEnd = indices.startIndex

    while currentIndexBitRangeEnd < indices.endIndex {
        
    }


  }
}

extension ErrorDiagnostic {
  static func bitFieldOutOfRange(
    fieldName: String,
    bitRange: String,
    bitWidth: Int
  ) -> Self {
    .init(
      """
      Bit field '\(fieldName)' references bit range '\(bitRange)' which falls \
      outside of the bit range '0..<\(bitWidth)' of the enclosing register.
      """)
  }
}
