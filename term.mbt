///|
/// A Prolog term.
pub enum Term {
  /// Named variable.
  Var(String)
  /// Atom.
  Atom(String)
  /// Integer number.
  Int(Int)
  /// Floating-point number.
  Float(Double)
  /// String.
  Str(String)
  /// Compound term `functor(arg1, arg2, ...)`.
  Compound(String, Array[Term])
} derive(Eq, Debug)

///|
/// The empty list `[]`.
pub fn empty_list() -> Term {
  Atom("[]")
}

///|
/// Build a proper list `[a, b, c]` from elements.
pub fn list(elems : ArrayView[Term]) -> Term {
  fn go(i : Int) -> Term {
    if i >= elems.length() {
      Atom("[]")
    } else {
      Compound(".", [elems[i], go(i + 1)])
    }
  }
  go(0)
}

///|
/// Build a cons cell `[Head | Tail]`.
pub fn cons(head : Term, tail : Term) -> Term {
  Compound(".", [head, tail])
}

///|
/// Is this term a proper list?
pub fn Term::is_list(self : Term) -> Bool {
  fn go(t : Term) -> Bool {
    match t {
      Atom("[]") => true
      Compound(".", [_, tl]) => go(tl)
      _ => false
    }
  }
  go(self)
}

///|
/// Variables occurring in the term, in order of first occurrence.
pub fn Term::free_vars(self : Term) -> Array[String] {
  fn go(t : Term, acc : Array[String]) -> Array[String] {
    match t {
      Var(n) => {
        if !acc.iter().any(x => x == n) {
          acc.push(n)
        }
        acc
      }
      Compound(_, args) => {
        let mut a = acc
        for x in args {
          a = go(x, a)
        }
        a
      }
      _ => acc
    }
  }
  go(self, [])
}

///|
/// Construct a variable term.
pub fn variable(name : String) -> Term {
  Var(name)
}

///|
/// Construct an atom term.
pub fn atom(name : String) -> Term {
  Atom(name)
}

///|
/// Construct an integer term.
pub fn int(value : Int) -> Term {
  Int(value)
}

///|
/// Construct a float term.
pub fn float(value : Double) -> Term {
  Float(value)
}

///|
/// Construct a string term.
pub fn str(value : String) -> Term {
  Str(value)
}

///|
/// Construct a compound term.
pub fn compound(functor : String, args : Array[Term]) -> Term {
  Compound(functor, args)
}
