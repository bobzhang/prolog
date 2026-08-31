# Prolog Interpreter Improvement TODOs

Audit date: 2026-08-31

## Quality assessment

This is a promising alpha-quality interpreter with a compact, understandable
architecture. Its strongest parts are the explicit-stack resolution engine,
occurs-checking unification, predicate indexing, readable implementation, useful
README examples, and substantial tests. It is a good educational interpreter and
a solid base for further work.

It is not yet a dependable or Prolog-compatible production interpreter. Several
confirmed defects affect variable isolation, relational built-ins, depth bounds,
query parsing, and incomplete negation. The API also reports all resource limits
through one Boolean, and the CLI hides some failures behind exit status 0.

Current baseline:

- `moon fmt --check`, `moon check`, `moon test`, CLI cram tests, and the native
  build pass.
- 40 unit/doc/white-box tests and 13 CLI transcript tests pass.
- Coverage is 1074/1367 executable lines (78.6%), or 1074/1279 (84.0%) when the
  separately tested CLI is excluded.
- `moon check --target all` fails because `cmd/prolog` uses APIs unavailable on
  the JS and wasm-gc targets but does not declare its supported targets.
- The current compiler reports seven `implicit_impl_as_method` deprecation
  warnings.

Suggested release gate: complete P0 before treating results as semantically
reliable, and complete P1 before describing the project as beta quality.

## P0 - Correctness blockers

- [ ] Make all interpreter-created variables hygienically fresh.

  Clause variables are renamed by appending a numeric suffix, and list built-ins
  generate visible names such as `_g0`. Both can collide with legal variables in
  the query. Confirmed examples:

  - `p(Y) :- Y = a.` with `p(Z), Y_0 = b` incorrectly fails.
  - `length(L, 1), _g0 = a` incorrectly forces `L = [a]`.

  Use an internal variable identity or a fresh-name allocator that is guaranteed
  disjoint from every parsed and public-API-created variable. Add regressions for
  query/clause, nested-clause, anonymous-variable, and built-in collisions.

- [ ] Fix `append/3` so corresponding list elements are unified, not compared
  with structural equality.

  `append([X], [b], [a, b])` currently fails instead of binding `X = a`.
  Thread the resulting bindings through every prefix element and then through
  the suffix. Cover variables on both sides, repeated variables, open lists, and
  failures caused by inconsistent bindings.

- [ ] Require complete consumption of queries and standalone terms.

  After an optional terminating dot, only EOF should be accepted. The query
  `X = 1. X = 2` currently runs as `X = 1` and silently ignores the rest. Test
  trailing terms, operators, dots, comments, and whitespace through both
  `Program::query` and `Term::parse`.

- [ ] Preserve goal depth when backtracking into a disjunction.

  `Choice::Goal` restores its alternative at depth 0. As a result, with DFS depth
  1, `p :- (q; r). r.` incorrectly succeeds. Store and restore the original goal
  depth, then add nested disjunction/conjunction/call tests at exact depth
  boundaries.

- [ ] Make bounded negation sound.

  A negated sub-search that reaches a depth or step bound is currently treated as
  ordinary failure, so `\+ loop` can return `true` while also setting
  `truncated`. Represent the outcome as success, failure, or incomplete; never
  present an incomplete negation as definitive success. Document whether the
  public API returns an explicit unknown result or raises a resource-limit error.

- [ ] Correct limit accounting and validate every `Options` value.

  With `max_steps = 1`, the query `true` is processed but is never emitted because
  the budget check runs before solution detection. A depth of 0 also returns
  `false` without reporting truncation, and non-positive solution limits have
  surprising behavior. Define boundary semantics, reject invalid options, and
  add exact 0/1/limit-1/limit/limit+1 tests for depth, steps, and solutions.

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

- [ ] Improve parser correctness and diagnostics.

  Store both line and column on tokens so the public error contract is true.
  Add tests for escaped quotes, malformed escapes, comments, Unicode input,
  exponent notation, deeply nested terms, and printer/parser round trips.
  Replace recursive list construction, list checks, and other easily exhausted
  paths where practical.

- [ ] Reject unsupported directives instead of silently ignoring them.

  An `op/3` directive is accepted and discarded, even though its operator is not
  available to following clauses. Until directives are implemented, return a
  clear unsupported-feature error. Later, add an operator environment and apply
  directives in source order.

- [ ] Fix CLI error and repetition behavior.

  The help says `--query` is repeatable, but only the first query is run.
  Evaluation errors such as division by zero print a message and still exit 0.
  Run all supplied queries in order, return nonzero on parse/evaluation/I/O
  failure, validate numeric flags, and test stdout, stderr, and exit codes.

- [ ] Make REPL statement collection syntax-aware.

  Do not decide completeness only from whether the trimmed line ends in `.`.
  Track brackets, parentheses, quoted strings, escapes, and comments, and provide
  useful EOF diagnostics for incomplete input. Add interactive transcript tests.

- [ ] Declare and continuously test the supported target matrix.

  Mark `cmd/prolog` as native+wasm (unless JS/wasm-gc support is implemented),
  make `moon check --target all` pass for the declared matrix, and exercise both
  wasm and native in CI.

- [ ] Eliminate compiler warnings and enforce interface review.

  Resolve the seven current derive/implicit-method deprecation warnings. Keep
  generated `.mbti` interfaces up to date with `moon info`, and review API diffs
  in CI or code review.

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

  Add every P0 reproducer first. Then test parser/printer round trips over
  generated terms, unification symmetry/idempotence/occurs-check properties,
  cut barriers, meta-calls, nested disjunction depth, search ordering, and every
  error branch. Maintain a documented compatibility suite for the chosen Prolog
  dialect. Raise library coverage beyond 90% based on meaningful assertions, not
  line-only tests.

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

1. Add regression tests for all P0 examples and fix variable hygiene,
   `append/3`, complete parsing, and disjunction depth.
2. Introduce structured completion/error outcomes; fix limit accounting and
   bounded negation on top of them.
3. Convert built-in answer generation to lazy choice points and finish the CLI
   contract.
4. Lock down the dialect with conformance/property tests and target-matrix CI.
5. Profile and improve internals, then consider P3 language features.
