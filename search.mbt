///|
/// The iterative resolution engine: an explicit-stack SLD interpreter.
/// No recursion on the search path: backtracking state lives in an
/// explicit choice-point stack, and each goal carries its own depth, so
/// deep searches use constant stack space and depth cannot leak between
/// branches. The only recursion is the nested sub-search for
/// negation-as-failure.

///|
/// A pending alternative on the choice-point stack.
priv enum Choice {
  /// Try clause `idx` of predicate f/arity for goal `g`, restoring the
  /// bindings, depth, and remaining goals captured when it was pushed.
  Clause(String, Int, Int, Term, Array[(Term, Int)], Bindings, Int)
  /// Continue with an alternative goal (disjunction branch / call), at its
  /// original depth.
  Goal(Term, Array[(Term, Int)], Bindings, Int)
  /// Try the `idx`-th precomputed solution of a built-in predicate.
  Solutions(Array[Bindings], Int, Array[(Term, Int)])
  /// Cut barrier: cut removes choice points up to and including it.
  Barrier
}

///|
/// Run a bounded depth-first search over `goals` (each goal paired with
/// its depth), calling `emit` for every solution in search order. `emit`
/// returning `false` stops the search immediately.
fn run_search(
  prog : Program,
  goals0 : Array[(Term, Int)],
  binds0 : Bindings,
  limit : Int,
  opts : Options,
  st : SearchState,
  emit : (Bindings) -> Bool,
) -> Unit raise PrologError {
  let mut goals = goals0
  let mut gi = 0
  let mut binds = binds0
  let choices : Array[Choice] = []
  // A clause to try next: functor, arity, clause index, goal, remaining
  // goals, bindings to restore, dispatch depth.
  let mut pending : (String, Int, Int, Term, Array[(Term, Int)], Bindings, Int)? = None
  let mut done = false

  fn backtrack() -> Unit {
    while !choices.is_empty() {
      match choices.pop().unwrap() {
        Barrier => continue
        Clause(f, ar, idx, g, rest, b0, d0) => {
          pending = Some((f, ar, idx, g, rest, b0, d0))
          return
        }
        Goal(g, rest, b0, gd0) => {
          binds = b0
          goals = [(g, gd0), ..rest]
          gi = 0
          return
        }
        Solutions(sols, idx, rest) => {
          binds = sols[idx]
          goals = rest
          gi = 0
          return
        }
      }
    }
    done = true
  }

  fn do_cut() -> Unit {
    while !choices.is_empty() {
      match choices.pop().unwrap() {
        Barrier => break
        _ => ()
      }
    }
  }

  fn multi_solutions(
    sols : Array[Bindings],
    rest : Array[(Term, Int)],
  ) -> Unit {
    if sols.is_empty() {
      backtrack()
      return
    }
    let n = sols.length()
    let mut i = n - 1
    while i >= 1 {
      choices.push(Solutions(sols, i, rest))
      i -= 1
    }
    binds = sols[0]
  }

  fn call_user_pred(
    f : String,
    args : Array[Term],
    g : Term,
    rest : Array[(Term, Int)],
    gdepth : Int,
  ) -> Unit {
    let arity = args.length()
    let clauses = prog.clauses.get("\{f}/\{arity}").unwrap_or([])
    if clauses.is_empty() {
      backtrack()
      return
    }
    choices.push(Barrier)
    pending = Some((f, arity, 0, g, rest, binds, gdepth))
  }

  while true {
    // Resume a pending clause.
    match pending {
      Some((f, ar, idx, g, rest, b0, d0)) => {
        pending = None
        let clauses = prog.clauses.get("\{f}/\{ar}").unwrap_or([])
        if idx >= clauses.length() {
          backtrack()
          if done {
            return
          }
          continue
        }
        if d0 >= limit {
          st.truncated = true
          st.truncated_by_depth = true
          pending = Some((f, ar, idx + 1, g, rest, b0, d0))
          continue
        }
        let id = st.next_var
        st.next_var += 1
        let c = rename_clause(clauses[idx], id)
        match unify(b0, g, c.head) {
          None => {
            pending = Some((f, ar, idx + 1, g, rest, b0, d0))
            continue
          }
          Some(b2) => {
            if idx + 1 < clauses.length() {
              choices.push(Clause(f, ar, idx + 1, g, rest, b0, d0))
            }
            binds = b2
            let ng : Array[(Term, Int)] = [(c.body, d0 + 1)]
            for r in rest {
              ng.push(r)
            }
            goals = ng
            gi = 0
            continue
          }
        }
      }
      None => ()
    }
    // Take the next goal.
    if gi >= goals.length() {
      if !emit(binds) {
        return
      }
      backtrack()
      if done {
        return
      }
      continue
    }
    if st.steps >= opts.max_steps {
      st.truncated = true
      return
    }
    st.steps += 1
    let (g0, gd) = goals[gi]
    gi += 1
    let rest = goals[gi:]
    let g = binds.apply(g0)
    match g {
      Var(v) => raise PrologError::Eval("uninstantiated goal: \{v}")
      Atom("true") => continue
      Atom("fail") | Atom("false") => {
        backtrack()
        if done {
          return
        }
        continue
      }
      Atom("!") => {
        do_cut()
        continue
      }
      Atom("nl") => {
        st.out.push("\n")
        continue
      }
      Atom(f) => {
        call_user_pred(f, [], g, rest.to_owned(), gd)
        if done {
          return
        }
        continue
      }
      Compound(f, args) =>
        match (f, args.length()) {
          (",", 2) => {
            goals = [(args[0], gd), (args[1], gd), ..rest]
            gi = 0
            continue
          }
          (";", 2) => {
            choices.push(Goal(args[1], rest.to_owned(), binds, gd))
            goals = [(args[0], gd), ..rest]
            gi = 0
            continue
          }
          ("call", 1) => {
            goals = [(args[0], gd), ..rest]
            gi = 0
            continue
          }
          ("!", 0) => {
            do_cut()
            continue
          }
          ("true", 0) => continue
          ("fail", 0) | ("false", 0) => {
            backtrack()
            if done {
              return
            }
            continue
          }
          ("nl", 0) => {
            st.out.push("\n")
            continue
          }
          ("=", 2) =>
            match unify(binds, args[0], args[1]) {
              None => {
                backtrack()
                if done {
                  return
                }
                continue
              }
              Some(b2) => {
                binds = b2
                continue
              }
            }
          ("\\=", 2) =>
            match unify(binds, args[0], args[1]) {
              None => continue
              Some(_) => {
                backtrack()
                if done {
                  return
                }
                continue
              }
            }
          ("==", 2) => {
            if !identical(binds, args[0], args[1]) {
              backtrack()
              if done {
                return
              }
            }
            continue
          }
          ("\\==", 2) => {
            if identical(binds, args[0], args[1]) {
              backtrack()
              if done {
                return
              }
            }
            continue
          }
          ("is", 2) => {
            let v = eval_arith(binds, args[1])
            let lhs = binds.apply(args[0])
            let b2 : Bindings? = match lhs {
              Var(n) => Some(binds.set(n, v.to_term()))
              _ =>
                if num_equal(eval_arith(binds, lhs), v) {
                  Some(binds)
                } else {
                  None
                }
            }
            match b2 {
              None => {
                backtrack()
                if done {
                  return
                }
              }
              Some(b3) => binds = b3
            }
            continue
          }
          ("=:=", 2)
          | ("=\\=", 2)
          | ("<", 2)
          | (">", 2)
          | ("=<", 2)
          | (">=", 2) => {
            let x = eval_arith(binds, args[0])
            let y = eval_arith(binds, args[1])
            let ok = match f {
              "=:=" => num_equal(x, y)
              "=\\=" => !num_equal(x, y)
              "<" => num_lt(x, y)
              ">" => num_gt(x, y)
              "=<" => num_le(x, y)
              _ => num_ge(x, y)
            }
            if !ok {
              backtrack()
              if done {
                return
              }
            }
            continue
          }
          ("var", 1) => {
            if !(binds.apply(args[0]) is Var(_)) {
              backtrack()
              if done {
                return
              }
            }
            continue
          }
          ("nonvar", 1) => {
            if binds.apply(args[0]) is Var(_) {
              backtrack()
              if done {
                return
              }
            }
            continue
          }
          ("atom", 1) => {
            if !(binds.apply(args[0]) is Atom(_)) {
              backtrack()
              if done {
                return
              }
            }
            continue
          }
          ("integer", 1) => {
            if !(binds.apply(args[0]) is Int(_)) {
              backtrack()
              if done {
                return
              }
            }
            continue
          }
          ("float", 1) => {
            if !(binds.apply(args[0]) is Float(_)) {
              backtrack()
              if done {
                return
              }
            }
            continue
          }
          ("number", 1) => {
            let t = binds.apply(args[0])
            if !(t is Int(_) || t is Float(_)) {
              backtrack()
              if done {
                return
              }
            }
            continue
          }
          ("string", 1) => {
            if !(binds.apply(args[0]) is Str(_)) {
              backtrack()
              if done {
                return
              }
            }
            continue
          }
          ("atomic", 1) => {
            if !is_atomic(binds.apply(args[0])) {
              backtrack()
              if done {
                return
              }
            }
            continue
          }
          ("compound", 1) => {
            if !(binds.apply(args[0]) is Compound(_, _)) {
              backtrack()
              if done {
                return
              }
            }
            continue
          }
          ("ground", 1) => {
            if !is_ground(binds, binds.apply(args[0])) {
              backtrack()
              if done {
                return
              }
            }
            continue
          }
          ("is_list", 1) => {
            if !binds.apply(args[0]).is_list() {
              backtrack()
              if done {
                return
              }
            }
            continue
          }
          ("write", 1) => {
            st.out.push(term_write(binds.apply_deep(args[0])))
            continue
          }
          ("\\+", 1) | ("not", 1) => {
            let found : Ref[Bool] = { val: false, }
            let naf_emit = (_b : Bindings) => {
              found.val = true
              false
            }
            let truncated_before = st.truncated
            run_search(prog, [(args[0], gd)], binds, limit, opts, st, naf_emit)
            // An incomplete negation (the sub-search hit a bound without a
            // proof) is not a proof of absence: fail rather than succeed.
            let incomplete = !found.val && st.truncated && !truncated_before
            if found.val || incomplete {
              backtrack()
              if done {
                return
              }
            }
            continue
          }
          ("member", 2) => {
            multi_solutions(
              member_solutions(binds, args[0], args[1]),
              rest.to_owned(),
            )
            if done {
              return
            }
            continue
          }
          ("append", 3) => {
            multi_solutions(
              append_solutions(binds, args[0], args[1], args[2]),
              rest.to_owned(),
            )
            if done {
              return
            }
            continue
          }
          ("reverse", 2) => {
            multi_solutions(
              reverse_solutions(binds, args[0], args[1]),
              rest.to_owned(),
            )
            if done {
              return
            }
            continue
          }
          ("length", 2) => {
            multi_solutions(
              length_solutions(st, binds, args[0], args[1]),
              rest.to_owned(),
            )
            if done {
              return
            }
            continue
          }
          ("nth0", 3) => {
            multi_solutions(
              nth0_solutions(binds, args[0], args[1], args[2]),
              rest.to_owned(),
            )
            if done {
              return
            }
            continue
          }
          ("between", 3) => {
            multi_solutions(
              between_solutions(binds, args[0], args[1], args[2]),
              rest.to_owned(),
            )
            if done {
              return
            }
            continue
          }
          _ => {
            call_user_pred(f, args, g, rest.to_owned(), gd)
            if done {
              return
            }
            continue
          }
        }
      _ => raise PrologError::Eval("not a callable goal: \{g.to_string()}")
    }
  }
}
