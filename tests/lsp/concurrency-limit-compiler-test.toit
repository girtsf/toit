// Copyright (C) 2026 Toit contributors.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

// Tests that the number of concurrently running compilers is limited.

import .lsp-client show LspClient run-client-test
import .mock-compiler
import expect show *
import monitor

REQUEST-COUNT ::= 6

main args:
  test args --max-concurrent=1 --limit=1
  test args --max-concurrent=2 --limit=2
  test args --max-concurrent=REQUEST-COUNT --limit=REQUEST-COUNT
  // A limit of 0 means that the compilers are not limited.
  test args --max-concurrent=0 --limit=REQUEST-COUNT

test args --max-concurrent/int --limit/int -> none:
  with-mock-sync: | sync |
    run-client-test
        args
        --use-mock
        --pre-initialize=: it.configuration["maxConcurrentCompilers"] = max-concurrent:
      run-requests it --limit=limit --sync=sync

run-requests client/LspClient --limit/int --sync/MockSync -> none:
  mock-compiler := MockCompiler client

  uri := "untitled:Untitled-1"
  path := client.to-path uri

  mock-compiler.set-mock-data --path=path (MockData [] [])
  mock-compiler.set-analysis-result (mock-compiler.build-analysis-answer --path=path)
  client.send-did-open --uri=uri --text="Ignored content"

  // Every completion request now runs a compiler that waits for us.
  mock-compiler.set-completion-result --sync=sync
      "\n0\n0\n0\n0\nfoo\n-1\nbar\n-1\n"

  // The requests must overlap, so we must not wait for idle in between.
  client.always-wait-for-idle = false
  done := monitor.Semaphore
  errors := []
  REQUEST-COUNT.repeat:
    task::
      try:
        completions := client.send-completion-request --uri=uri 1 2
        if completions.size != 2: errors.add "Unexpected completions: $completions"
      finally:
        done.up

  // Release the compilers one at a time. As long as a compiler isn't released
  // it can't finish, and thus no additional compiler may start.
  REQUEST-COUNT.repeat: | released/int |
    expected-waiting := (min REQUEST-COUNT (released + limit)) - released
    waiting := sync.wait-for-waiting expected-waiting
    // No compiler may have started beyond the limit.
    expect-equals expected-waiting waiting.size
    sync.release waiting.first

  REQUEST-COUNT.repeat: done.down
  if not errors.is-empty: throw "$errors"

  client.always-wait-for-idle = true
  client.wait-for-idle
  expect-equals REQUEST-COUNT sync.started.size
