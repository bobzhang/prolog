///|
/// Whitebox tests for internals: unification, arithmetic, lexer, display.
test "unify with occurs check" {
  let b = Bindings::empty()
  assert_true(unify(b, Var("X"), Int(1)) is Some(_))
  assert_true(unify(b, Var("X"), Compound("f", [Var("X")])) is None)
  assert_true(unify(b, Int(1), Float(1.0)) is None)
  let b2 = unify(
    b,
    Compound("f", [Var("X"), Int(2)]),
    Compound("f", [Int(1), Var("Y")]),
  ).unwrap()
  assert_eq(b2.get("X"), Some(Int(1)))
  assert_eq(b2.get("Y"), Some(Int(2)))
}

///|
test "identical and apply_deep" {
  let b = Bindings::empty()
  assert_true(identical(b, Var("X"), Var("X")))
  assert_false(identical(b, Var("X"), Var("Y")))
  assert_false(identical(b, Int(1), Float(1.0)))
  let b2 = b.set("X", Compound("f", [Var("Y")])).set("Y", Int(1))
  assert_eq(b2.apply_deep(Var("X")), Compound("f", [Int(1)]))
}

///|
test "arithmetic evaluation" {
  let b = Bindings::empty()
  assert_eq(eval_arith(b, Term::parse("1 + 2 * 3")), Num::I(7))
  assert_eq(eval_arith(b, Term::parse("- 2 * 3")), Num::I(-6))
  assert_eq(eval_arith(b, Term::parse("7 mod 3")), Num::I(1))
  assert_eq(eval_arith(b, Term::parse("10 / 4")), Num::F(2.5))
  assert_eq(eval_arith(b, Term::parse("min(4, 3)")), Num::I(3))
}

///|
test "lexer produces expected tokens" {
  let toks = lex("f(X, 1.5) :- g(Y); h.")
  assert_eq(toks[0].kind, Atom("f"))
  assert_eq(toks[1].kind, LParen)
  assert_eq(toks[2].kind, Var("X"))
  assert_eq(toks[3].kind, Comma)
  assert_eq(toks[4].kind, NumFloat(1.5))
  assert_eq(toks[5].kind, RParen)
  assert_eq(toks[6].kind, Op(":-"))
  assert_eq(toks[7].kind, Atom("g"))
  assert_eq(toks[8].kind, LParen)
  assert_eq(toks[9].kind, Var("Y"))
  assert_eq(toks[10].kind, RParen)
  assert_eq(toks[11].kind, Op(";"))
  assert_eq(toks[12].kind, Atom("h"))
  assert_eq(toks[13].kind, Dot)
  assert_eq(toks[14].kind, Eof)
}

///|
test "base names strip renaming suffixes" {
  assert_eq(base_name("X_7"), "X")
  assert_eq(base_name("X"), "X")
  assert_eq(base_name("_3"), "_")
  assert_eq(base_name("X_"), "X_")
  assert_eq(base_name("_g0"), "_g0")
}
