// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

// Well-formed block types parse, but aren't supported yet.
one-param [b int]: null
two-params [b int string -> bool]: null
no-params [b -> int]: null
nullable [b int? -> bool?]: null
prefixed [b core.List -> none]: null
named [--b any -> any]: null

// Malformed.
after-bracket [b] /int: null
missing-bracket [b int -> bool: null
double-arrow [b -> -> int]: null
empty-return [b int -> ]: null
nested [b [c]]: null
colon-after-type [b int: null
default-with-type [b = 5 int -> int]: null
names-with-types [b x/int y/string -> bool]: null
slash [b/int]: null
slash-more [b /int string -> bool]: null
names-only [b x y]: null
named-inside [b --baz]: null
named-after-type [b int --baz]: null
named-before-type [b --baz int]: null
named-between [b int --baz -> bool]: null

main:
  one-param: null
  two-params: null
  no-params: null
  nullable: null
  prefixed: null
  named --b=: null
  after-bracket: null
  missing-bracket: true
  nested: null
  colon-after-type: null
  default-with-type: null
  names-with-types: null
  slash: null
  slash-more: null
  names-only: null
  named-inside: null
  named-after-type: null
  named-before-type: null
  named-between: null

unterminated-at-eof [b int ->
