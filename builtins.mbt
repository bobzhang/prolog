///|
/// Built-in predicates: arithmetic, numeric comparison, and list operations.

///|
/// An arithmetic value: integer or float.
enum Num {
  I(Int)
  F(Double)
} derive(Eq, Debug)

///|
fn Num::to_term(self : Num) -> Term {
  match self {
    I(n) => Int(n)
    F(f) => Float(f)
  }
}

///|
fn Num::to_float(self : Num) -> Double {
  match self {
    I(n) => n.to_double()
    F(f) => f
  }
}

///|
fn eval_arith(binds : Bindings, t : Term) -> Num raise PrologError {
  match binds.apply(t) {
    Int(n) => I(n)
    Float(f) => F(f)
    Compound("+", [a, b]) => num_add(eval_arith(binds, a), eval_arith(binds, b))
    Compound("-", [a]) => num_neg(eval_arith(binds, a))
    Compound("-", [a, b]) => num_sub(eval_arith(binds, a), eval_arith(binds, b))
    Compound("*", [a, b]) => num_mul(eval_arith(binds, a), eval_arith(binds, b))
    Compound("/", [a, b]) => num_div(eval_arith(binds, a), eval_arith(binds, b))
    Compound("//", [a, b]) =>
      num_idiv(eval_arith(binds, a), eval_arith(binds, b))
    Compound("mod", [a, b]) =>
      num_mod(eval_arith(binds, a), eval_arith(binds, b))
    Compound("rem", [a, b]) =>
      num_rem(eval_arith(binds, a), eval_arith(binds, b))
    Compound("abs", [a]) => num_abs(eval_arith(binds, a))
    Compound("min", [a, b]) =>
      num_min(eval_arith(binds, a), eval_arith(binds, b))
    Compound("max", [a, b]) =>
      num_max(eval_arith(binds, a), eval_arith(binds, b))
    Compound("sqrt", [a]) => num_sqrt(eval_arith(binds, a))
    Var(v) =>
      raise PrologError::Eval("uninstantiated arithmetic expression: \{v}")
    other =>
      raise PrologError::Eval(
        "not an arithmetic expression: \{other.to_string()}",
      )
  }
}

///|
fn num_add(a : Num, b : Num) -> Num {
  match (a, b) {
    (I(x), I(y)) => I(x + y)
    _ => F(a.to_float() + b.to_float())
  }
}

///|
fn num_sub(a : Num, b : Num) -> Num {
  match (a, b) {
    (I(x), I(y)) => I(x - y)
    _ => F(a.to_float() - b.to_float())
  }
}

///|
fn num_mul(a : Num, b : Num) -> Num {
  match (a, b) {
    (I(x), I(y)) => I(x * y)
    _ => F(a.to_float() * b.to_float())
  }
}

///|
fn num_neg(a : Num) -> Num {
  match a {
    I(x) => I(-x)
    F(f) => F(-f)
  }
}

///|
fn num_div(a : Num, b : Num) -> Num raise PrologError {
  if b.to_float() == 0.0 {
    raise PrologError::Eval("division by zero")
  }
  F(a.to_float() / b.to_float())
}

///|
fn num_idiv(a : Num, b : Num) -> Num raise PrologError {
  match (a, b) {
    (I(x), I(y)) => {
      if y == 0 {
        raise PrologError::Eval("division by zero")
      }
      I(x / y)
    }
    _ => raise PrologError::Eval("// requires integer arguments")
  }
}

///|
fn num_mod(a : Num, b : Num) -> Num raise PrologError {
  match (a, b) {
    (I(x), I(y)) => {
      if y == 0 {
        raise PrologError::Eval("division by zero")
      }
      let r = x % y
      I(if r == 0 || (r > 0) == (y > 0) { r } else { r + y })
    }
    _ => raise PrologError::Eval("mod requires integer arguments")
  }
}

///|
fn num_rem(a : Num, b : Num) -> Num raise PrologError {
  match (a, b) {
    (I(x), I(y)) => {
      if y == 0 {
        raise PrologError::Eval("division by zero")
      }
      I(x % y)
    }
    _ => raise PrologError::Eval("rem requires integer arguments")
  }
}

///|
fn num_abs(a : Num) -> Num {
  match a {
    I(x) => I(if x < 0 { -x } else { x })
    F(f) => F(if f < 0.0 { -f } else { f })
  }
}

///|
fn num_min(a : Num, b : Num) -> Num {
  match (a, b) {
    (I(x), I(y)) => if x <= y { I(x) } else { I(y) }
    _ => if a.to_float() <= b.to_float() { a } else { b }
  }
}

///|
fn num_max(a : Num, b : Num) -> Num {
  match (a, b) {
    (I(x), I(y)) => if x >= y { I(x) } else { I(y) }
    _ => if a.to_float() >= b.to_float() { a } else { b }
  }
}

///|
fn num_sqrt(a : Num) -> Num raise PrologError {
  if a.to_float() < 0.0 {
    raise PrologError::Eval("sqrt of a negative number")
  }
  F(@math.pow(a.to_float(), 0.5))
}

///|
fn num_equal(a : Num, b : Num) -> Bool {
  match (a, b) {
    (I(x), I(y)) => x == y
    _ => a.to_float() == b.to_float()
  }
}

///|
fn num_lt(a : Num, b : Num) -> Bool {
  match (a, b) {
    (I(x), I(y)) => x < y
    _ => a.to_float() < b.to_float()
  }
}

///|
fn num_gt(a : Num, b : Num) -> Bool {
  match (a, b) {
    (I(x), I(y)) => x > y
    _ => a.to_float() > b.to_float()
  }
}

///|
fn num_le(a : Num, b : Num) -> Bool {
  !num_gt(a, b)
}

///|
fn num_ge(a : Num, b : Num) -> Bool {
  !num_lt(a, b)
}

///|
/// Walk a (dereferenced) term as a proper list; `None` if it is not one.
fn proper_list(binds : Bindings, t : Term) -> Array[Term]? {
  let elems : Array[Term] = []
  let mut cur = binds.apply(t)
  let mut ok = true
  while true {
    match cur {
      Atom("[]") => break
      Compound(".", [h, tl]) => {
        elems.push(h)
        cur = binds.apply(tl)
        continue
      }
      _ => {
        ok = false
        break
      }
    }
  }
  if ok {
    Some(elems)
  } else {
    None
  }
}

///|
/// Generate a proper list of `k` fresh variables.
fn fresh_list(st : SearchState, k : Int) -> Term {
  let elems : Array[Term] = []
  for _i in (0).until(k) {
    elems.push(Var("_g\{st.next_var}"))
    st.next_var += 1
  }
  list(elems)
}

///|
fn member_solutions(binds : Bindings, x : Term, l : Term) -> Array[Bindings] {
  let sols : Array[Bindings] = []
  let mut cur = binds.apply(l)
  while true {
    match cur {
      Atom("[]") => break
      Compound(".", [h, tl]) => {
        match unify(binds, x, h) {
          Some(b2) => sols.push(b2)
          None => ()
        }
        cur = binds.apply(tl)
        continue
      }
      _ => break
    }
  }
  sols
}

///|
fn append_solutions(
  binds : Bindings,
  a : Term,
  b : Term,
  c : Term,
) -> Array[Bindings] {
  let dc = binds.apply(c)
  match proper_list(binds, a) {
    Some(elems_a) =>
      match proper_list(binds, c) {
        Some(elems_c) => {
          // A and C proper: check the prefix and bind B to the suffix.
          if elems_a.length() > elems_c.length() {
            return []
          }
          let mut ok = true
          for i in (0).until(elems_a.length()) {
            if !(elems_a[i] == elems_c[i]) {
              ok = false
              break
            }
          }
          if !ok {
            return []
          }
          let suffix = list(elems_c[elems_a.length():])
          match unify(binds, b, suffix) {
            None => []
            Some(b2) => [b2]
          }
        }
        None =>
          // A proper, C unbound: C = A ++ B (open list allowed).
          match dc {
            Var(_) => {
              let mut t = binds.apply(b)
              for e in elems_a.rev() {
                t = Compound(".", [e, t])
              }
              match unify(binds, c, t) {
                None => []
                Some(b2) => [b2]
              }
            }
            _ => []
          }
      }
    None =>
      match proper_list(binds, c) {
        Some(elems_c) => {
          // A unbound and C proper: enumerate splits.
          let sols : Array[Bindings] = []
          for i in (0).until(elems_c.length() + 1) {
            let prefix = list(elems_c[:i])
            let suffix = list(elems_c[i:])
            match unify(binds, a, prefix) {
              None => ()
              Some(b2) =>
                match unify(b2, b, suffix) {
                  None => ()
                  Some(b3) => sols.push(b3)
                }
            }
          }
          sols
        }
        None => []
      }
  }
}

///|
fn reverse_solutions(binds : Bindings, a : Term, b : Term) -> Array[Bindings] {
  match proper_list(binds, a) {
    Some(elems) =>
      match unify(binds, b, list(elems.rev())) {
        None => []
        Some(b2) => [b2]
      }
    None =>
      match proper_list(binds, b) {
        Some(elems) =>
          match unify(binds, a, list(elems.rev())) {
            None => []
            Some(b2) => [b2]
          }
        None => []
      }
  }
}

///|
fn length_solutions(
  st : SearchState,
  binds : Bindings,
  l : Term,
  n : Term,
) -> Array[Bindings] {
  let dn = binds.apply(n)
  match proper_list(binds, l) {
    Some(elems) =>
      match dn {
        Var(v) => [binds.set(v, Int(elems.length()))]
        Int(k) => if k == elems.length() { [binds] } else { [] }
        _ => []
      }
    None =>
      match binds.apply(l) {
        Var(_) =>
          match dn {
            Var(nv) => {
              // Both unbound: enumerate short lists (bounded generation).
              let sols : Array[Bindings] = []
              for k in (0).until(21) {
                let gen = fresh_list(st, k)
                match unify(binds.set(nv, Int(k)), l, gen) {
                  None => ()
                  Some(b2) => sols.push(b2)
                }
              }
              sols
            }
            Int(k) =>
              if k < 0 || k > 1000 {
                []
              } else {
                let gen = fresh_list(st, k)
                match unify(binds, l, gen) {
                  None => []
                  Some(b2) => [b2]
                }
              }
            _ => []
          }
        _ => {
          // Open list ending in a variable: extend the tail to length N.
          let elems : Array[Term] = []
          let mut cur = binds.apply(l)
          let mut tail_var : String? = None
          let mut broken = false
          while true {
            match cur {
              Atom("[]") => break
              Compound(".", [h, tl]) => {
                elems.push(h)
                cur = binds.apply(tl)
                continue
              }
              Var(v) => {
                tail_var = Some(v)
                break
              }
              _ => {
                broken = true
                break
              }
            }
          }
          if broken {
            return []
          }
          match tail_var {
            None => []
            Some(v) =>
              match dn {
                Var(nv) =>
                  match unify(binds, Var(v), Atom("[]")) {
                    None => []
                    Some(b2) => [b2.set(nv, Int(elems.length()))]
                  }
                Int(k) => {
                  let need = k - elems.length()
                  if need < 0 || need > 1000 {
                    []
                  } else {
                    let gen = fresh_list(st, need)
                    match unify(binds, Var(v), gen) {
                      None => []
                      Some(b2) => [b2]
                    }
                  }
                }
                _ => []
              }
          }
        }
      }
  }
}

///|
fn nth0_solutions(
  binds : Bindings,
  n : Term,
  l : Term,
  x : Term,
) -> Array[Bindings] {
  match proper_list(binds, l) {
    Some(elems) =>
      match binds.apply(n) {
        Var(v) => {
          let sols : Array[Bindings] = []
          for i in (0).until(elems.length()) {
            match unify(binds.set(v, Int(i)), x, elems[i]) {
              None => ()
              Some(b2) => sols.push(b2)
            }
          }
          sols
        }
        Int(k) =>
          if k < 0 || k >= elems.length() {
            []
          } else {
            match unify(binds, x, elems[k]) {
              None => []
              Some(b2) => [b2]
            }
          }
        _ => []
      }
    None => []
  }
}

///|
fn between_solutions(
  binds : Bindings,
  lo : Term,
  hi : Term,
  x : Term,
) -> Array[Bindings] raise PrologError {
  match (binds.apply(lo), binds.apply(hi)) {
    (Int(a), Int(b)) => {
      if b - a > 1_000_000 {
        raise PrologError::Eval("between/3 range too large")
      }
      let sols : Array[Bindings] = []
      for v in a.until(b + 1) {
        match unify(binds, x, Int(v)) {
          None => ()
          Some(b2) => sols.push(b2)
        }
      }
      sols
    }
    _ => []
  }
}
