///|
/// The resolution engine: unification, SLD search with iterative deepening,
/// cut, negation-as-failure, and the built-in predicate dispatch.

///|
/// Internal search state, shared through the continuation-passing search.
priv struct SearchState {
  mut steps : Int
  mut next_var : Int
  mut solutions : Array[Bindings]
  mut out : Array[String]
  mut completion : Completion
  /// The search was cut off by the depth limit (as opposed to the step or
  /// solution budgets), so a deeper round may find more.
  mut truncated_by_depth : Bool
  /// Monotonic counter bumped each time a bound cuts the search short; lets
  /// nested searches (negation-as-failure) detect their own truncation.
  mut truncation_epoch : Int
}

///|
/// Resolve a term fully: dereference the term itself and every subterm.
pub fn Bindings::apply_deep(self : Bindings, t : Term) -> Term {
  match self.apply(t) {
    Compound(f, args) => Compound(f, args.map(a => self.apply_deep(a)))
    other => other
  }
}

///|
/// Resolve a term through the bindings, chasing variable chains.
pub fn Bindings::apply(self : Bindings, t : Term) -> Term {
  match t {
    Var(n) =>
      match self.get(n) {
        Some(v) => self.apply(v)
        None => t
      }
    _ => t
  }
}

///|
/// Unify two terms under the current bindings, with occurs check.
fn unify(binds : Bindings, a : Term, b : Term) -> Bindings? {
  let a = binds.apply(a)
  let b = binds.apply(b)
  match (a, b) {
    (Var(x), Var(y)) => if x == y { Some(binds) } else { Some(binds.set(x, b)) }
    (Var(x), _) =>
      if occurs(binds, x, b) {
        None
      } else {
        Some(binds.set(x, b))
      }
    (_, Var(y)) =>
      if occurs(binds, y, a) {
        None
      } else {
        Some(binds.set(y, a))
      }
    (Atom(x), Atom(y)) => if x == y { Some(binds) } else { None }
    (Int(x), Int(y)) => if x == y { Some(binds) } else { None }
    (Float(x), Float(y)) => if x == y { Some(binds) } else { None }
    (Str(x), Str(y)) => if x == y { Some(binds) } else { None }
    (Compound(f1, a1), Compound(f2, a2)) =>
      if f1 != f2 || a1.length() != a2.length() {
        None
      } else {
        unify_args(binds, a1, a2)
      }
    _ => None
  }
}

///|
fn unify_args(
  binds : Bindings,
  xs : Array[Term],
  ys : Array[Term],
) -> Bindings? {
  fn go(i : Int, b : Bindings) -> Bindings? {
    if i >= xs.length() {
      Some(b)
    } else {
      match unify(b, xs[i], ys[i]) {
        None => None
        Some(b2) => go(i + 1, b2)
      }
    }
  }
  go(0, binds)
}

///|
fn occurs(binds : Bindings, name : String, t : Term) -> Bool {
  match binds.apply(t) {
    Var(m) => name == m
    Compound(_, args) => {
      let mut found = false
      for a in args {
        if occurs(binds, name, a) {
          found = true
          break
        }
      }
      found
    }
    _ => false
  }
}

///|
/// Term identity (`==`): dereferences bound variables, compares structure,
/// and distinguishes unbound variables by name.
fn identical(binds : Bindings, a : Term, b : Term) -> Bool {
  let a = binds.apply(a)
  let b = binds.apply(b)
  match (a, b) {
    (Var(x), Var(y)) => x == y
    (Atom(x), Atom(y)) => x == y
    (Int(x), Int(y)) => x == y
    (Float(x), Float(y)) => x == y
    (Str(x), Str(y)) => x == y
    (Compound(f1, a1), Compound(f2, a2)) =>
      if f1 != f2 || a1.length() != a2.length() {
        false
      } else {
        let mut ok = true
        for i in (0).until(a1.length()) {
          if !identical(binds, a1[i], a2[i]) {
            ok = false
            break
          }
        }
        ok
      }
    _ => false
  }
}

///|
fn is_atomic(t : Term) -> Bool {
  match t {
    Atom(_) | Int(_) | Float(_) | Str(_) => true
    _ => false
  }
}

///|
fn is_ground(binds : Bindings, t : Term) -> Bool {
  match t {
    Var(_) => false
    Compound(_, args) => {
      let mut g = true
      for a in args {
        if !is_ground(binds, binds.apply(a)) {
          g = false
          break
        }
      }
      g
    }
    _ => true
  }
}

///|
fn rename_clause(c : Clause, id : Int) -> Clause {
  fn go(t : Term) -> Term {
    match t {
      Var(n) => Var("~\{n}_\{id}")
      Compound(f, args) => Compound(f, args.map(go))
      _ => t
    }
  }
  { head: go(c.head), body: go(c.body), }
}

///|
/// Run a query with the default search options.
pub fn Program::query(
  self : Program,
  goal : String,
) -> QueryResult raise PrologError {
  self.query_with(goal, Options::new())
}

///|
/// Run a query with explicit search options.
///
/// Iterative deepening (default) re-runs bounded depth-first search with
/// increasing depth limits until a round completes without hitting a bound
/// (or `max_depth` is reached), then returns that round's solutions: the
/// search is fair and terminates on finite programs, while complete
/// searches yield the same answers, in the same order, as plain
/// depth-first search. With `ilds = false` a single bounded depth-first
/// pass is used. Either way the search is bounded by `max_depth`,
/// `max_steps`, and `max_solutions`; when a bound cuts the search space
/// off, the result's `completion` reports the bound.
pub fn Program::query_with(
  self : Program,
  goal : String,
  opts : Options,
) -> QueryResult raise PrologError {
  if opts.max_depth < 0 || opts.max_steps < 0 || opts.max_solutions < 0 {
    raise PrologError::Eval("search options must be non-negative")
  }
  let (g, vars) = parse_goal(goal)
  let st : SearchState = {
    steps: 0,
    next_var: 0,
    solutions: [],
    out: [],
    completion: Completion::Complete,
    truncated_by_depth: false,
    truncation_epoch: 0,
  }
  let emit = (b : Bindings) => {
    if st.solutions.length() >= opts.max_solutions {
      st.completion = Completion::Solutions
      st.truncation_epoch += 1
      return false
    }
    st.solutions.push(b)
    true
  }
  let mut best : (Array[Bindings], Array[String], Completion)? = None
  fn run_round(limit : Int) -> Unit raise PrologError {
    st.solutions = []
    st.out = []
    st.completion = Completion::Complete
    st.truncated_by_depth = false
    run_search(self, [(g, 0)], Bindings::empty(), limit, opts, st, emit)
    if !st.solutions.is_empty() {
      best = Some((st.solutions, st.out, st.completion))
    }
  }
  if opts.ilds {
    let mut d = 0
    while d <= opts.max_depth {
      run_round(d)
      // Stop when the round completed, or when the search budget (rather
      // than the depth bound) cut it short: deeper rounds would add
      // nothing.
      if st.completion == Completion::Complete || !st.truncated_by_depth {
        break
      }
      d += 1
    }
  } else {
    run_round(opts.max_depth)
  }
  // When the search budget cuts every round short, fall back to the best
  // round that did find solutions rather than returning nothing.
  if st.solutions.is_empty() {
    match best {
      Some((sols, out, completion)) => {
        st.solutions = sols
        st.out = out
        st.completion = completion
      }
      None => ()
    }
  }
  {
    solutions: st.solutions,
    vars,
    output: join_strings(st.out),
    completion: st.completion,
  }
}

///|
fn join_strings(parts : Array[String]) -> String {
  let sb = StringBuilder()
  for p in parts {
    sb.write_string(p)
  }
  sb.to_string()
}

///|
/// Format each solution as one line, e.g. `X = 1, Y = f(2)`; a query
/// without variables yields `true`.
pub fn QueryResult::answer_lines(self : QueryResult) -> Array[String] {
  let display_vars = self.vars.filter(v => !is_anon_var(v))
  self.solutions.map(b => {
    let bound = display_vars.filter(v => {
      match b.apply(Var(v)) {
        Var(w) => w != v
        _ => true
      }
    })
    if bound.is_empty() {
      "true"
    } else {
      let rename = rename_map(b, bound)
      bound
      .map(v => {
        let t = b.apply_deep(Var(v))
        "\{v} = \{fmt_term(t, 0, true, rename)}"
      })
      .join(", ")
    }
  })
}

///|
fn is_anon_var(name : String) -> Bool {
  if name.length() <= 1 {
    name == "_"
  } else {
    name[0] == '_' &&
    (1)
    .until(name.length())
    .all(i => {
      let c = name[i]
      c >= '0' && c <= '9'
    })
  }
}

///|
/// Build a display-renaming map for the free variables of a solution:
/// clause-renaming suffixes (`X_7`) are stripped, and collisions are kept
/// unambiguous by leaving the original names.
fn rename_map(
  binds : Bindings,
  display_vars : Array[String],
) -> Map[String, String] {
  let mut frees : Array[String] = []
  for v in display_vars {
    frees = collect_free(binds.apply_deep(Var(v)), frees)
  }
  let clash : Array[String] = []
  let seen : Array[(String, String)] = []
  for f in frees {
    let base = base_name(f)
    let mut hit = false
    for kv in seen {
      let (b0, f0) = kv
      if b0 == base && f0 != f {
        hit = true
        break
      }
    }
    if hit {
      if !clash.iter().any(b => b == base) {
        clash.push(base)
      }
    } else {
      seen.push((base, f))
    }
  }
  let m : Map[String, String] = Map([])
  for f in frees {
    let base = base_name(f)
    m.set(f, if clash.iter().any(b => b == base) { f } else { base })
  }
  m
}

///|
fn collect_free(t : Term, acc : Array[String]) -> Array[String] {
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
        a = collect_free(x, a)
      }
      a
    }
    _ => acc
  }
}
