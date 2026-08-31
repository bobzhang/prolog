///|
/// Blackbox tests for the Prolog interpreter's public API.
suberror TestFailure {
  Msg(String)
} derive(Debug)

///|
fn result(
  prog : String,
  query : String,
) -> @prolog.QueryResult raise TestFailure {
  @prolog.Program::parse(prog).query(query) catch {
    e => raise TestFailure::Msg(e.message())
  }
}

///|
fn result_with(
  prog : String,
  query : String,
  opts : @prolog.Options,
) -> @prolog.QueryResult raise TestFailure {
  @prolog.Program::parse(prog).query_with(query, opts) catch {
    e => raise TestFailure::Msg(e.message())
  }
}

///|
fn sols(prog : String, query : String) -> Array[String] raise TestFailure {
  result(prog, query).answer_lines()
}

///|
fn first(prog : String, query : String) -> String raise TestFailure {
  let a = sols(prog, query)
  if a.is_empty() {
    raise TestFailure::Msg("expected a solution for: \{query}")
  }
  a[0]
}

///|
fn count(prog : String, query : String) -> Int raise TestFailure {
  result(prog, query).solutions.length()
}

///|
fn eval_error(query : String) -> String raise TestFailure {
  let r = @prolog.Program::parse("").query(query) catch {
    @prolog.PrologError::Eval(m) => return m
    other => raise TestFailure::Msg(other.message())
  }
  ignore(r)
  raise TestFailure::Msg("expected an evaluation error for: \{query}")
}

///|
fn parse_error(text : String) -> String raise TestFailure {
  let r = @prolog.Program::parse(text) catch {
    @prolog.PrologError::Parse(m) => return m
    other => raise TestFailure::Msg(other.message())
  }
  ignore(r)
  raise TestFailure::Msg("expected a parse error for: \{text}")
}

///|
fn term_parse_error(text : String) -> String raise TestFailure {
  let r = @prolog.Term::parse(text) catch {
    @prolog.PrologError::Parse(m) => return m
    other => raise TestFailure::Msg(other.message())
  }
  ignore(r)
  raise TestFailure::Msg("expected a parse error for: \{text}")
}

///|
fn options_error(
  opts : @prolog.Options,
  goal : String,
) -> String raise TestFailure {
  let r = @prolog.Program::parse("").query_with(goal, opts) catch {
    @prolog.PrologError::Eval(m) => return m
    other => raise TestFailure::Msg(other.message())
  }
  ignore(r)
  raise TestFailure::Msg("expected an evaluation error for: \{goal}")
}

///|
fn query_parse_error(query : String) -> String raise TestFailure {
  let r = @prolog.Program::parse("").query(query) catch {
    @prolog.PrologError::Parse(m) => return m
    other => raise TestFailure::Msg(other.message())
  }
  ignore(r)
  raise TestFailure::Msg("expected a parse error for: \{query}")
}

///|
fn family() -> String {
  let s =
    #|parent(john, mary).
    #|parent(mary, ann).
    #|parent(mary, tom).
    #|parent(ann, sam).
    #|
    #|ancestor(X, Y) :- parent(X, Y).
    #|ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).
  s
}

///|
fn qsort_program() -> String {
  let s =
    #|qsort([], []).
    #|qsort([X|Xs], S) :- split(X, Xs, Lo, Hi), qsort(Lo, S1), qsort(Hi, S2), append(S1, [X|S2], S).
    #|
    #|split(_, [], [], []).
    #|split(P, [Y|Ys], [Y|Lo], Hi) :- Y =< P, split(P, Ys, Lo, Hi).
    #|split(P, [Y|Ys], Lo, [Y|Hi]) :- Y > P, split(P, Ys, Lo, Hi).
  s
}

///|
fn perm_program() -> String {
  let s =
    #|select(X, [X|T], T).
    #|select(X, [H|T], [H|R]) :- select(X, T, R).
    #|perm([], []).
    #|perm([X|Xs], Y) :- select(X, Y, Ys), perm(Xs, Ys).
  s
}

///|
fn queens_program() -> String {
  let s =
    #|select(X, [X|T], T).
    #|select(X, [H|T], [H|R]) :- select(X, T, R).
    #|perm([], []).
    #|perm([X|Xs], Y) :- select(X, Y, Ys), perm(Xs, Ys).
    #|
    #|range(N, N, [N]).
    #|range(Lo, Hi, [Lo|R]) :- Lo < Hi, Lo1 is Lo + 1, range(Lo1, Hi, R).
    #|
    #|queens(N, Qs) :- range(1, N, Ns), place(N, Ns, [], Qs).
    #|place(_, [], Qs, Qs).
    #|place(N, Cols, Acc, Qs) :-
    #|    select(Q, Cols, Rest),
    #|    \+ attack(Q, Acc, 1),
    #|    place(N, Rest, [Q|Acc], Qs).
    #|attack(Q, [Q1|_], D) :- Q =:= Q1 + D.
    #|attack(Q, [Q1|_], D) :- Q =:= Q1 - D.
    #|attack(Q, [_|Qs], D) :- D1 is D + 1, attack(Q, Qs, D1).
  s
}

///|
test "term display round-trips" {
  let cases = [
    "apple", "42", "-5", "3.5", "\"hi\"", "'hello world'", "[]", "[a, b, c]", "[H|T]",
    "[a, b|T]", "f(a, b)", "f(X = 1)", "f((a, b))", "1 + 2 * 3", "(1 + 2) * 3", "a; b, c",
    "(a; b), c", "X = 1, Y = 2", "-(2 * 3)", "1 - (2 - 3)", "\\+ X = 1", "(\\+ X) = 1",
    "\\+ member(X, [a])", "(X = 1) = 2",
  ]
  for c in cases {
    assert_eq(@prolog.Term::parse(c).to_string(), c)
  }
}

///|
test "free variables are collected in order" {
  assert_eq(@prolog.Term::parse("f(X, Y, X, g(Z))").free_vars(), ["X", "Y", "Z"])
}

///|
test "list constructors" {
  let l = @prolog.cons(
    @prolog.int(1),
    @prolog.cons(@prolog.int(2), @prolog.empty_list()),
  )
  assert_eq(l.to_string(), "[1, 2]")
  assert_true(l.is_list())
  assert_false(@prolog.Term::parse("f(a)").is_list())
  assert_true(@prolog.Term::parse("[a, b]").is_list())
  assert_eq(@prolog.list([@prolog.atom("a")]).to_string(), "[a]")
}

///|
test "parse errors carry messages" {
  assert_true(parse_error("q(.").contains("expected"))
  assert_true(parse_error("\"abc").contains("unterminated"))
  assert_true(parse_error("a = b = c").contains("not associative"))
  assert_true(parse_error("p(x). q(.").contains("expected"))
  assert_true(parse_error("f(x").contains("expected"))
}

///|
test "unification basics" {
  assert_eq(sols("", "X = 1"), ["X = 1"])
  assert_eq(sols("", "X = apple"), ["X = apple"])
  assert_eq(sols("", "X = f(Y), Y = 2"), ["X = f(2), Y = 2"])
  assert_eq(sols("", "X = 1, X = 1"), ["X = 1"])
  assert_eq(sols("", "X = 1, X = 2"), [])
  assert_eq(sols("", "X = Y"), ["X = Y"])
  assert_eq(sols("", "f(X, g(Y)) = f(1, g(2))"), ["X = 1, Y = 2"])
  assert_eq(sols("", "1 = 1.0"), [])
}

///|
test "occurs check rejects cyclic terms" {
  assert_eq(sols("", "X = f(X)"), [])
  assert_eq(sols("", "X = [X]"), [])
}

///|
test "disjunction and conjunction precedence" {
  assert_eq(sols("", "X = 1; X = 2"), ["X = 1", "X = 2"])
  assert_eq(sols("", "X = 1, Y = 2; Y = 3"), ["X = 1, Y = 2", "Y = 3"])
}

///|
test "anonymous variables are distinct" {
  assert_eq(sols("", "_ = 1, _ = 2"), ["true"])
  assert_eq(sols("q(X, Y) :- X \\== Y.", "q(_, _)"), ["true"])
  assert_eq(sols("q(X, Y) :- X \\== Y.", "q(a, a)"), [])
}

///|
test "term identity == and \\==" {
  assert_eq(sols("", "X == X"), ["true"])
  assert_eq(sols("", "X == Y"), [])
  assert_eq(sols("", "X \\== Y"), ["true"])
  assert_eq(sols("", "X = Y, X == Y"), ["X = Y"])
  assert_eq(sols("", "1 == 1.0"), [])
  assert_eq(sols("", "1 \\== 1.0"), ["true"])
  assert_eq(sols("", "f(a) == f(a)"), ["true"])
}

///|
test "arithmetic with is/2" {
  assert_eq(first("", "X is 1 + 2 * 3"), "X = 7")
  assert_eq(first("", "X is 10 // 3"), "X = 3")
  assert_eq(first("", "X is 10 / 4"), "X = 2.5")
  assert_eq(first("", "X is 7 mod 3"), "X = 1")
  assert_eq(first("", "X is -7 mod 2"), "X = 1")
  assert_eq(first("", "X is -7 rem 2"), "X = -1")
  assert_eq(first("", "X is min(3, 4)"), "X = 3")
  assert_eq(first("", "X is max(3, 4)"), "X = 4")
  assert_eq(first("", "X is abs(-3)"), "X = 3")
  assert_eq(first("", "X is sqrt(9)"), "X = 3.0")
  assert_eq(first("", "X is -(2 + 3)"), "X = -5")
  assert_eq(first("", "X is 1 + 2.5"), "X = 3.5")
  assert_eq(sols("", "1 + 1 is 2"), ["true"])
  assert_eq(sols("", "1 + 1 is 3"), [])
}

///|
test "numeric comparison" {
  assert_eq(sols("", "2 < 3"), ["true"])
  assert_eq(sols("", "3 >= 3"), ["true"])
  assert_eq(sols("", "2 =< 2"), ["true"])
  assert_eq(sols("", "1 =:= 1.0"), ["true"])
  assert_eq(sols("", "1 =\\= 2"), ["true"])
  assert_eq(sols("", "1 < 1.5"), ["true"])
  assert_eq(sols("", "2 > 3"), [])
}

///|
test "arithmetic errors" {
  assert_true(eval_error("X is 1 / 0").contains("zero"))
  assert_true(eval_error("X is 1 // 0").contains("zero"))
  assert_true(eval_error("Y is X").contains("uninstantiated"))
  assert_true(eval_error("X is foo(1)").contains("not an arithmetic"))
  assert_true(eval_error("X").contains("uninstantiated"))
  assert_true(eval_error("X is 1.5 mod 2").contains("integer"))
}

///|
test "term inspection built-ins" {
  assert_eq(sols("", "var(X)"), ["true"])
  assert_eq(sols("", "nonvar(a)"), ["true"])
  assert_eq(sols("", "atom(a)"), ["true"])
  assert_eq(sols("", "atom(X)"), [])
  assert_eq(sols("", "integer(1)"), ["true"])
  assert_eq(sols("", "integer(1.0)"), [])
  assert_eq(sols("", "float(1.5)"), ["true"])
  assert_eq(sols("", "number(1)"), ["true"])
  assert_eq(sols("", "number(1.5)"), ["true"])
  assert_eq(sols("", "atomic(a)"), ["true"])
  assert_eq(sols("", "compound(f(a))"), ["true"])
  assert_eq(sols("", "compound(a)"), [])
  assert_eq(sols("", "ground(f(a))"), ["true"])
  assert_eq(sols("", "ground(f(X))"), [])
  assert_eq(sols("", "X = a, var(X)"), [])
  assert_eq(sols("", "is_list([a])"), ["true"])
  assert_eq(sols("", "is_list(a)"), [])
  assert_eq(sols("", "string(\"a\")"), ["true"])
  assert_eq(sols("", "string(a)"), [])
}

///|
test "list built-ins" {
  assert_eq(sols("", "member(X, [a, b, c])"), ["X = a", "X = b", "X = c"])
  assert_eq(sols("", "member(a, [a, b])"), ["true"])
  assert_eq(sols("", "member(d, [a, b])"), [])
  assert_eq(sols("", "append([1, 2], [3], X)"), ["X = [1, 2, 3]"])
  assert_eq(sols("", "append(X, Y, [1, 2, 3])"), [
    "X = [], Y = [1, 2, 3]", "X = [1], Y = [2, 3]", "X = [1, 2], Y = [3]", "X = [1, 2, 3], Y = []",
  ])
  assert_eq(sols("", "append([1, 2], [3, 4], [1, 2, 3, 4])"), ["true"])
  assert_eq(sols("", "append([1, 2], [3, 4], [1, 2])"), [])
  assert_eq(sols("", "append([1, 2], B, C)"), ["C = [1, 2|B]"])
  assert_eq(sols("", "reverse([1, 2, 3], X)"), ["X = [3, 2, 1]"])
  assert_eq(sols("", "reverse(X, [3, 2, 1])"), ["X = [1, 2, 3]"])
  assert_eq(sols("", "reverse([1, 2], [1, 2])"), [])
  assert_eq(sols("", "length([a, b, c], N)"), ["N = 3"])
  assert_eq(sols("", "length(L, 3)"), ["L = [_g0, _g1, _g2]"])
  assert_eq(sols("", "length([a|T], 2)"), ["T = [_g0]"])
  assert_eq(sols("", "length([a|T], N)"), ["T = [], N = 1"])
  assert_eq(sols("", "length([a, b], 2)"), ["true"])
  assert_eq(sols("", "length([a], 2)"), [])
  assert_eq(sols("", "nth0(1, [a, b, c], X)"), ["X = b"])
  assert_eq(sols("", "nth0(N, [a, b], X)"), ["N = 0, X = a", "N = 1, X = b"])
  assert_eq(sols("", "nth0(3, [a, b], X)"), [])
  assert_eq(sols("", "between(1, 3, X)"), ["X = 1", "X = 2", "X = 3"])
}

///|
test "transitive closure with left recursion" {
  let p = family()
  assert_eq(sols(p, "parent(X, mary)"), ["X = john"])
  assert_eq(sols(p, "ancestor(john, X)"), [
    "X = mary", "X = ann", "X = tom", "X = sam",
  ])
  assert_eq(sols(p, "ancestor(X, sam)"), ["X = ann", "X = john", "X = mary"])
  assert_eq(sols(p, "ancestor(tom, X)"), [])
  assert_eq(sols(p, "ancestor(john, sam)"), ["true"])
}

///|
test "left-recursive loop terminates" {
  let p = "loop :- loop. done."
  assert_eq(sols(p, "done"), ["true"])
  let r = result_with(p, "loop", @prolog.Options::make(8, true, 1_000_000, 10))
  assert_eq(r.solutions.length(), 0)
  assert_true(r.truncated)
}

///|
test "quicksort in pure Prolog" {
  let opts = @prolog.Options::make(64, true, 1_000_000, 1_000)
  let r = result_with(
    qsort_program(),
    "qsort([3, 1, 4, 1, 5, 9, 2, 6], S)",
    opts,
  )
  assert_eq(r.answer_lines(), ["S = [1, 1, 2, 3, 4, 5, 6, 9]"])
  assert_false(r.truncated)
}

///|
test "factorial and fibonacci" {
  let fact = "fact(0, 1). fact(N, F) :- N > 0, N1 is N - 1, fact(N1, F1), F is N * F1."
  assert_eq(first(fact, "fact(5, F)"), "F = 120")
  assert_eq(sols(fact, "fact(-1, F)"), [])
  let fib = "fib(0, 0). fib(1, 1). fib(N, F) :- N > 1, N1 is N - 1, N2 is N - 2, fib(N1, F1), fib(N2, F2), F is F1 + F2."
  assert_eq(first(fib, "fib(10, F)"), "F = 55")
}

///|
test "permutation generates all orders" {
  let answers = sols(perm_program(), "perm([1, 2, 3], P)")
  assert_eq(answers.length(), 6)
  answers.sort()
  assert_eq(answers, [
    "P = [1, 2, 3]", "P = [1, 3, 2]", "P = [2, 1, 3]", "P = [2, 3, 1]", "P = [3, 1, 2]",
    "P = [3, 2, 1]",
  ])
}

///|
test "paths in a cyclic graph" {
  let graph =
    #|edge(a, b). edge(b, c). edge(c, a). edge(b, d).
    #|path(X, Y) :- path(X, Y, [X]).
    #|path(X, Y, _) :- edge(X, Y).
    #|path(X, Y, V) :- edge(X, Z), \+ member(Z, V), path(Z, Y, [Z|V]).
  assert_eq(sols(graph, "path(a, d)"), ["true"])
  assert_eq(sols(graph, "path(a, X)"), ["X = b", "X = c", "X = d", "X = a"])
  assert_eq(sols(graph, "path(X, d)"), ["X = b", "X = a", "X = c"])
  assert_eq(sols(graph, "path(a, a)"), ["true"])
}

///|
test "cut prunes choice points" {
  let cut =
    #|a(1) :- !.
    #|a(2).
    #|b(X) :- X = 1, !.
    #|b(X) :- X = 2.
    #|c :- !, fail.
    #|c :- true.
    #|max(X, Y, X) :- X >= Y, !.
    #|max(X, Y, Y).
  assert_eq(sols(cut, "a(X)"), ["X = 1"])
  assert_eq(sols(cut, "a(2)"), ["true"])
  assert_eq(sols(cut, "b(1)"), ["true"])
  assert_eq(sols(cut, "b(X)"), ["X = 1"])
  assert_eq(sols(cut, "b(2)"), ["true"])
  assert_eq(sols(cut, "c"), [])
  assert_eq(sols(cut, "max(2, 5, M)"), ["M = 5"])
  assert_eq(sols(cut, "max(7, 3, M)"), ["M = 7"])
}

///|
test "negation as failure" {
  assert_eq(sols("", "\\+ member(3, [1, 2])"), ["true"])
  assert_eq(sols("", "\\+ member(1, [1, 2])"), [])
  assert_eq(sols("", "not(X = 2), X = 1"), [])
  assert_eq(sols("", "X = 1, not(X = 2)"), ["X = 1"])
  let different = "different(X, Y) :- \\+ X = Y."
  assert_eq(sols(different, "different(a, b)"), ["true"])
  assert_eq(sols(different, "different(a, a)"), [])
}

///|
test "write and nl produce output" {
  let r = result("", "write(hello), nl, write('world!')")
  assert_eq(r.output, "hello\nworld!")
  assert_eq(r.answer_lines(), ["true"])
  let r2 = result("", "(X = 1; X = 2), write(X)")
  assert_eq(r2.output, "12")
  assert_eq(r2.answer_lines(), ["X = 1", "X = 2"])
}

///|
test "call/1 invokes a goal" {
  assert_eq(sols("", "call(member(X, [a, b]))"), ["X = a", "X = b"])
  assert_eq(sols("", "call(true)"), ["true"])
}

///|
test "answers keep free variables" {
  assert_eq(sols("p(X) :- X = f(Y).", "p(X)"), ["X = f(Y)"])
  assert_eq(sols("q(X) :- X = f(_).", "q(X)"), ["X = f(_1)"])
}

///|
test "four queens" {
  let answers = sols(queens_program(), "queens(4, Q)")
  assert_eq(answers.length(), 2)
  answers.sort()
  assert_eq(answers, ["Q = [2, 4, 1, 3]", "Q = [3, 1, 4, 2]"])
}

///|
test "map coloring" {
  let color =
    #|color(WA, NT, SA, Q, NSW, V, T) :-
    #|  R = [red, green, blue],
    #|  member(WA, R), member(NT, R), member(SA, R), member(Q, R), member(NSW, R), member(V, R), member(T, R),
    #|  \+ WA = NT, \+ WA = SA, \+ NT = SA, \+ NT = Q, \+ SA = Q, \+ SA = NSW, \+ SA = V, \+ Q = NSW, \+ NSW = V.
  assert_eq(count(color, "color(WA, NT, SA, Q, NSW, V, T)"), 18)
  assert_eq(
    first(color, "color(WA, NT, SA, Q, NSW, V, T)"),
    "WA = red, NT = green, SA = blue, Q = red, NSW = green, V = red, T = red",
  )
}

///|
test "search bounds are respected" {
  let p = "p(0). p(N) :- p(M), N is M + 1."
  let opts = @prolog.Options::make(5, false, 1_000_000, 1_000)
  let r = result_with(p, "p(N)", opts)
  assert_eq(r.answer_lines(), ["N = 0", "N = 1", "N = 2", "N = 3", "N = 4"])
  assert_true(r.truncated)
  let opts2 = @prolog.Options::make(5, true, 1_000_000, 1_000)
  let r2 = result_with(p, "p(N)", opts2)
  assert_eq(r2.answer_lines(), ["N = 0", "N = 1", "N = 2", "N = 3", "N = 4"])
  assert_true(r2.truncated)
  let opts3 = @prolog.Options::make(10, true, 1_000_000, 3)
  let r3 = result_with(p, "p(N)", opts3)
  assert_eq(r3.answer_lines(), ["N = 0", "N = 1", "N = 2"])
  assert_true(r3.truncated)
}

///|
test "dfs and ilds agree on finite search" {
  let opts = @prolog.Options::make(32, false, 1_000_000, 1_000)
  let r = result_with("", "member(X, [a, b])", opts)
  assert_eq(r.answer_lines(), ["X = a", "X = b"])
  assert_false(r.truncated)
}

///|
test "public API surface" {
  let r = result("likes(sam, apple).", "likes(sam, apple)")
  assert_eq(r.answer_lines(), ["true"])
  assert_eq(r.solutions.length(), 1)
  assert_eq(r.solutions[0].names(), [])
  assert_false(r.truncated)
  assert_eq(r.output, "")
  let r2 = result("", "X = 1")
  assert_eq(r2.solutions[0].get("X"), Some(@prolog.int(1)))
  assert_eq(r2.vars, ["X"])
}

///|
test "strings unify and display" {
  assert_eq(sols("", "X = \"hello\""), ["X = \"hello\""])
  assert_eq(sols("", "\"a\" = \"a\""), ["true"])
  assert_eq(sols("", "\"a\" = \"b\""), [])
}

///|
test "programs ignore directives and comments" {
  let p =
    #|% a comment
    #|:- op(500, xfy, fun).
    #|/* block
    #|   comment */
    #|likes(sam, apple).
  assert_eq(sols(p, "likes(sam, apple)"), ["true"])
}

///|
test "interpreter variables are hygienic" {
  // Clause renaming cannot collide with a query variable.
  assert_eq(sols("p(Y) :- Y = a.", "p(Z), Y_0 = b"), ["Z = a, Y_0 = b"])
  // Builtin-generated names cannot collide with a query variable.
  assert_eq(sols("", "length(L, 1), _g0 = a"), ["L = [_g0], _g0 = a"])
  // Renamed anonymous variables cannot collide with user variables.
  assert_eq(sols("p(Y) :- Y = f(_).", "p(X), _1_2 = z"), ["X = f(_1), _1_2 = z"])
}

///|
test "append unifies elements" {
  assert_eq(sols("", "append([X], [b], [a, b])"), ["X = a"])
  assert_eq(sols("", "append([X], Y, [a, b])"), ["X = a, Y = [b]"])
  assert_eq(sols("", "append([a], [X], [a, b])"), ["X = b"])
  assert_eq(sols("", "append([X], [b], [c, b])"), ["X = c"])
  assert_eq(sols("", "append([a], [b], [c, b])"), [])
}

///|
test "queries and terms require complete consumption" {
  assert_true(query_parse_error("X = 1. X = 2").contains("trailing"))
  assert_true(term_parse_error("a. b").contains("trailing"))
  assert_eq(@prolog.Term::parse("a.").to_string(), "a")
  assert_eq(@prolog.Term::parse("a").to_string(), "a")
}

///|
test "disjunction preserves goal depth" {
  let p = "p :- (q; r). r."
  let opts1 = @prolog.Options::make(1, false, 1_000_000, 10)
  let r1 = result_with(p, "p", opts1)
  assert_eq(r1.solutions.length(), 0)
  assert_true(r1.truncated)
  let opts2 = @prolog.Options::make(2, false, 1_000_000, 10)
  assert_eq(result_with(p, "p", opts2).answer_lines(), ["true"])
}

///|
test "negation is sound under bounds" {
  let p = "loop :- loop."
  let r = result_with(
    p,
    "\\+ loop",
    @prolog.Options::make(8, false, 100_000, 10),
  )
  assert_eq(r.solutions.length(), 0)
  assert_true(r.truncated)
  assert_eq(sols("", "\\+ member(3, [1, 2])"), ["true"])
  assert_eq(sols("", "\\+ member(1, [1, 2])"), [])
}

///|
test "limit boundaries are exact" {
  // A single builtin goal fits in a one-step budget.
  let r1 = result_with("", "true", @prolog.Options::make(32, false, 1, 10))
  assert_eq(r1.answer_lines(), ["true"])
  assert_false(r1.truncated)
  // A conjunction needs more than one step.
  let r2 = result_with(
    "",
    "X = 1, Y = 2",
    @prolog.Options::make(32, false, 1, 10),
  )
  assert_eq(r2.solutions.length(), 0)
  assert_true(r2.truncated)
  // Depth 0 allows builtins but rejects every clause.
  let r3 = result_with(
    "",
    "X = 1",
    @prolog.Options::make(0, false, 100_000, 10),
  )
  assert_eq(r3.answer_lines(), ["X = 1"])
  assert_false(r3.truncated)
  let r4 = result_with(
    "p(a).",
    "p(X)",
    @prolog.Options::make(0, false, 100_000, 10),
  )
  assert_eq(r4.solutions.length(), 0)
  assert_true(r4.truncated)
}

///|
test "negative options are rejected" {
  let msg = options_error(@prolog.Options::make(-1, false, 1_000, 10), "true")
  assert_true(msg.contains("non-negative"))
}
