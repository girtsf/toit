// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

// __TYPE-MIGRATION__ predicate: [block any -> bool]
every list/List [predicate any -> any] -> bool:
  list.do: if not predicate.call it: return false
  return true

// The pattern core uses for predicates: non-bool results are deprecated, not errors.
// __TYPE-MIGRATION__ predicate: [block any -> bool]
// __TYPE-MIGRATION__ predicate: [block any -> any]. Deprecated. Return a bool instead.
lenient-every list/List [predicate any -> any] -> bool:
  list.do: if not predicate.call it: return false
  return true

// __TYPE-MIGRATION__ b: [block int -> int]. Deprecated. Return a string instead.
// __TYPE-MIGRATION__ b: [block int -> string]
legacy [b int -> any] -> any:
  return b.call 1

// __TYPE-MIGRATION__ p: [block any -> bool]
declared-bool [p any -> bool]: p.call 1

// __TYPE-MIGRATION__ p: int
not-block-type [p any -> any]: p.call 1

// __TYPE-MIGRATION__ p: [block any -> bool]
on-non-block p/any: p

// __TYPE-MIGRATION__ p: [block any -> bool
unterminated [p]: p.call

// __TYPE-MIGRATION__ p: [block any -> bool -> int]
two-returns [p]: p.call

// __TYPE-MIGRATION__ p: [-> bool]
no-name [p]: p.call

main:
  x/any := null
  y := 5
  every [1]: it == 1          // OK.
  every [1]: x or y           // OK: `or` yields the last value.
  every [1]: it               // OK: any.
  every [1]: |e/int| e > 0    // OK.
  every [1]: 42               // Error.
  every [1]: null             // Error.
  lenient-every [1]: it == 1  // OK.
  lenient-every [1]: x or y   // OK.
  lenient-every [1]: it & 1   // OK: any.
  lenient-every [1]: 42       // Warning.
  lenient-every [1]: null     // Warning.
  lenient-every [1]: |a b| 1  // Error: too many parameters.
  legacy: "$it"               // OK.
  legacy: it                  // Warning: deprecated.
  legacy: 1.5                 // Error.
