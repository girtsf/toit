// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import expect show *

// Migration annotations on block parameters are checked statically only; the
// declared `-> any` is what counts at runtime, so truthiness keeps working.
// __TYPE-MIGRATION__ predicate: [block any -> bool]
truthy-every list/List [predicate any -> any] -> bool:
  list.do: if not predicate.call it: return false
  return true

main:
  value/any := [1]
  expect (truthy-every [1]: value or false)
  expect (truthy-every [1]: it)
  expect (truthy-every [1]: it == 1)
  expect-not (truthy-every [1, 2]: it == 1)
