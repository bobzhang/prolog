# Prolog Interpreter Improvement TODOs

Initial audit: 2026-08-31
Last re-evaluated: 2026-09-01

## Quality assessment

This is now a stronger alpha-quality interpreter with a compact, understandable
architecture. Its strongest parts are the explicit-stack resolution engine,
occurs-checking unification, predicate indexing, readable implementation, useful
README examples, and substantial tests. Variable hygiene, relational `append/3`,
strict input consumption, disjunction depth, unsupported directives, target
declarations, and CLI failure behavior have all improved since the initial audit.

It is not yet a broadly Prolog-compatible production interpreter. All six
original P0 blockers are now closed, including the two re-opened edge cases
(sticky negation truncation and `max_solutions = 0`). The API still collapses
every resource-limit cause into one Boolean, several relations only implement
selected modes, and the supported language remains intentionally small.

Current baseline:

- `moon fmt --check`, `moon check --target all`, `moon test`, and CLI cram tests
  pass for the declared target matrix.
- 56 unit/doc/white-box tests and 16 CLI transcript tests pass.
- Library-package coverage is 1087/1286 executable lines (84.5%). CLI transcript
  coverage is tracked separately by cram tests.
- Checklist progress is 11/30 fully complete: all six P0 blockers plus target
  declarations, directive rejection, CLI failure behavior, interface review, and
  parser diagnostics.
- Rough completeness estimate: about 80% of the README-promised subset, 60-65%
  of a dependable small pure-Prolog core, and 25-30% of the surface normally
  expected from a conventional Prolog implementation.

Suggested release gate: complete P0 before treating results as semantically
reliable, and complete P1 before describing the project as beta quality.

## P0 - Correctness blockers

- [x] Make all interpreter-created variables hygienically fresh.

  Clause renaming and list built-ins now use parser-disjoint internal names.
  Regressions cover the original collisions:

  - `p(Y) :- Y = a.` with `p(Z), Y_0 = b` now yields both bindings.
  - `length(L, 1), _g0 = a` no longer aliases the generated list variable.

- [x] Fix `append/3` so corresponding list elements are unified, not compared
  with structural equality.

  Prefix unification now threads bindings element by element and then through the
  suffix. `append([X], [b], [a, b])` correctly binds `X = a`, with regressions
  for variables on both sides and inconsistent prefixes.

- [x] Require complete consumption of queries and standalone terms.

  Queries and standalone terms now require EOF after an optional terminating
  dot. Inputs such as `X = 1. X = 2` and `a. b` produce parse errors instead of
  silently ignoring the suffix.

- [x] Preserve goal depth when backtracking into a disjunction.

  `Choice::Goal` now stores and restores the original dispatch depth. With DFS
  depth 1, `p :- (q; r). r.` correctly reports no solution and truncation; depth
  2 succeeds.

- [x] Finish bounded negation soundness across prior truncation.

  A truncation epoch counter now makes each negation sub-search's truncation
  local, so a bound hit by an earlier branch no longer masks it. With DFS depth 1
  and `deep :- deep. loop :- loop.`, the query `deep; \+ loop` fails instead of
  emitting `true`; isolated and previously-truncated regressions both pass.

- [x] Finish limit boundary semantics and validation.

  Step accounting, depth-0 reporting, negative-option validation, and the
  `max_solutions = 0` boundary are fixed: zero now emits no answers, and reaching
  the solution cap only marks truncation when a further candidate exists.

## P1 - Semantic clarity and robustness

- [ ] Replace `QueryResult::truncated : Bool` with structured completion data.

  Distinguish at least depth, inference-step, solution-count, bounded-generator,
  and incomplete-negation outcomes. Preserve the best round's completion reason
  during iterative deepening and show the specific reason in the CLI.

- [ ] Specify iterative-deepening answer and duplicate semantics.

  For `p(X) :- p(X). p(a).`, depth 4 currently returns `X = a` four times. Decide
  whether proof duplicates are intentional Prolog behavior or whether iterative
  rounds should emit variant-deduplicated answers. Document and test ordering,
  side effects, cuts, and the interaction between step and solution limits across
  rounds.

- [ ] Make multi-solution built-ins lazy and budget-aware.

  `member/2`, `append/3`, `length/2`, `nth0/3`, and especially `between/3`
  precompute arrays of bindings before the engine can honor `max_solutions`.
  Extend the choice-point machinery to produce one answer at a time. Avoid
  allocating up to one million `between/3` bindings for a caller requesting one
  solution.

- [ ] Define a consistent built-in error policy.

  Several invalid or insufficiently instantiated calls silently fail, including
  non-integer `between/3`, invalid `length/2`, and improper-list arguments. Decide
  on a documented dialect (preferably structured instantiation, type, domain,
  existence, and resource errors) and apply it consistently. Also decide whether
  an undefined predicate is failure or an `existence_error`.

- [ ] Make partial list relations explicit and honest.

  Open-list and two-variable modes are hard-coded or incomplete: `length/2`
  generates only lengths 0 through 20, `member/2` stops at an open tail without
  marking incompleteness, and `reverse/2`/`nth0/3` support only selected modes.
  Either implement fair lazy generation or return structured incompleteness.
  Remove magic limits in favor of documented options.

- [ ] Harden arithmetic boundary behavior.

  Check overflow and minimum-integer edge cases for negation, `abs`, division,
  remainder, range subtraction, and `b + 1` in `between/3`. Define NaN/infinity
  handling and mixed integer/float comparison semantics. Add boundary and
  property tests on every supported backend.

- [x] Improve parser correctness and diagnostics.

  Tokens store line and column, diagnostics report both, exponent notation is
  parsed, and escaped quotes, malformed escapes, comments, Unicode input, deeply
  nested terms, and printer/parser round trips all have regression coverage.
  Replacing recursive list construction and other easily exhausted paths is
  tracked under the P2 profiling item.

- [x] Reject unsupported directives instead of silently ignoring them.

  Directives such as `op/3` now produce a clear unsupported-feature parse error
  instead of being accepted and discarded. If directives are added later,
  introduce an operator environment and apply them in source order.

- [x] Fix CLI error and repetition behavior.

  All repeatable `--query` values now run in order. Parse, evaluation, and I/O
  failures produce a nonzero status, output-write failures are propagated, and
  negative numeric flags are rejected. Cram tests cover repeated queries,
  evaluation failure status, and invalid numeric flags.

- [ ] Make REPL statement collection syntax-aware.

  Do not decide completeness only from whether the trimmed line ends in `.`.
  Track brackets, parentheses, quoted strings, escapes, and comments, and provide
  useful EOF diagnostics for incomplete input. Add interactive transcript tests.

- [x] Declare and continuously test the supported target matrix.

  `cmd/prolog` is declared for native and wasm. CI checks all declared targets,
  runs wasm unit tests, and builds both native and wasm CLI targets.

- [x] Eliminate compiler warnings and enforce interface review.

  The deprecation warnings are gone and `moon check --target all` is clean. CI
  regenerates interfaces with `moon info` and fails if any tracked `.mbti` file
  drifts from the committed API.

## P2 - API, tests, and maintainability

- [ ] Add a streaming query API.

  Support a callback, iterator, or explicit search cursor so callers can stop
  after the first answer without materializing all solutions. Keep the eager
  `QueryResult` API as a convenience wrapper and define how output events are
  delivered relative to answers.

- [ ] Add a parsed-query API and structured errors.

  Let callers parse once and execute repeatedly without round-tripping through a
  string. Replace free-form evaluation error strings with public structured error
  variants while retaining `message()` for display.

- [ ] Expand regression, property, and conformance tests.

  Test parser/printer
  round trips over generated terms, unification symmetry/idempotence/occurs-check
  properties, cut barriers, meta-calls, nested disjunction depth, search ordering,
  and every error branch. Maintain a documented compatibility suite for the
  chosen Prolog dialect. Raise library coverage beyond 90% based on meaningful
  assertions, not line-only tests.

- [ ] Add parser and evaluator fuzzing with resource caps.

  Fuzz arbitrary input, deeply nested terms, large clauses, and adversarial
  variable chains. Fail with structured errors rather than panics, stack
  overflows, or unbounded allocation.

- [ ] Profile before optimizing persistent bindings and goal storage.

  The binding store has eight fixed buckets, copies a bucket on every extension,
  retains shadowed entries, and recursively follows chains. Goal and choice-point
  arrays are also copied frequently. Profile representative recursive, list, and
  combinatorial workloads; then consider a persistent map/union-find design,
  typed predicate keys, and cheaper goal snapshots. Record reproducible benchmark
  fixtures and before/after results.

- [ ] Split large files by responsibility after semantics stabilize.

  `parser.mbt`, `search.mbt`, and `builtins.mbt` are still navigable but nearing
  the point where lexer/parser, search/control, arithmetic, list predicates, and
  term predicates deserve focused files. Preserve the public API and verify that
  generated `.mbti` files do not change during organizational refactors.

- [ ] Document the exact supported dialect and resource model.

  Add a feature matrix for supported, partial, and unsupported syntax and
  predicates. Explain occurs-check behavior, bounded search, side effects,
  duplicate answers, strings, undefined predicates, numeric semantics, and the
  meaning of every completion status. Avoid broad claims such as "fair" unless
  the corresponding contract is tested.

## P3 - Feature growth after correctness

- [ ] Add common control predicates and syntax: `once/1`, if-then-else (`->/2`),
  and a documented soft-cut policy.
- [ ] Add core term predicates such as `functor/3`, `arg/3`, `=../2`,
  `copy_term/2`, `compare/3`, and standard term ordering.
- [ ] Add atom, number, string, and character-code conversions according to the
  chosen dialect.
- [ ] Add `consult`/`include` and program composition with explicit file and
  directive error handling.
- [ ] Consider DCG expansion, exceptions (`throw/1`, `catch/3`), and dynamic
  predicates only after the execution and error contracts are stable.

## Recommended implementation order

1. Replace the truncation Boolean with structured completion/error outcomes.
2. Convert built-in answer generation to lazy choice points and make partial
   relation modes explicit.
3. Lock down the dialect with conformance/property tests and target-matrix CI.
4. Profile and improve internals, then consider P3 language features.
