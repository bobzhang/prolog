///|
/// A Prolog program: parsed clauses indexed by predicate.
pub struct Program {
  clauses : Map[String, Array[Clause]]
}

///|
/// A clause `Head :- Body`; facts have body `true`.
pub struct Clause {
  head : Term
  body : Term
}

///|
/// Search options.
pub struct Options {
  /// Maximum resolution depth: the number of clause applications allowed in
  /// a derivation (default 32).
  max_depth : Int
  /// Iterative deepening search (fair; default). When `false`, a single
  /// bounded depth-first pass is used.
  ilds : Bool
  /// Maximum inference steps per search (safety bound; default 1 000 000).
  max_steps : Int
  /// Maximum number of solutions collected (default 1000).
  max_solutions : Int
}

///|
/// Default search options.
pub fn Options::new() -> Options {
  { max_depth: 32, ilds: true, max_steps: 1_000_000, max_solutions: 1_000, }
}

///|
/// Build search options explicitly.
pub fn Options::make(
  max_depth : Int,
  ilds : Bool,
  max_steps : Int,
  max_solutions : Int,
) -> Options {
  { max_depth, ilds, max_steps, max_solutions, }
}

///|
/// Variable bindings produced by unification.
/// Bindings are persistent: extending them creates a new value, so they
/// can be snapshotted for backtracking safely. Lookups are hash-bucketed
/// for speed.
pub struct Bindings {
  buckets : Array[Array[(String, Term)]]
}

///|
/// The number of hash buckets used by bindings.
const BINDING_BUCKETS : Int = 8

///|
fn bucket_of(name : String) -> Int {
  let mut h = 7
  for c in name {
    h = h * 31 + c.to_int()
  }
  // Two's-complement mask keeps the bucket index in [0, 8) for any h.
  h & 7
}

///|
pub fn Bindings::empty() -> Bindings {
  let buckets : Array[Array[(String, Term)]] = []
  for _i in (0).until(BINDING_BUCKETS) {
    buckets.push([])
  }
  { buckets, }
}

///|
/// Look up a variable's binding.
pub fn Bindings::get(self : Bindings, name : String) -> Term? {
  for kv in self.buckets[bucket_of(name)] {
    let (k, v) = kv
    if k == name {
      return Some(v)
    }
  }
  None
}

///|
/// The names of the variables currently bound.
pub fn Bindings::names(self : Bindings) -> Array[String] {
  let seen : Array[String] = []
  for bucket in self.buckets {
    for kv in bucket {
      let (k, _v) = kv
      if !seen.iter().any(x => x == k) {
        seen.push(k)
      }
    }
  }
  seen
}

///|
fn Bindings::set(self : Bindings, name : String, t : Term) -> Bindings {
  let i = bucket_of(name)
  let copy : Array[Array[(String, Term)]] = []
  for j in (0).until(BINDING_BUCKETS) {
    if j == i {
      copy.push([(name, t), ..self.buckets[j]])
    } else {
      copy.push(self.buckets[j])
    }
  }
  { buckets: copy, }
}

///|

///|
/// Why a search stopped short of full exploration.
pub enum Completion {
  /// Every reachable answer was emitted.
  Complete
  /// Cut off by the resolution-depth bound.
  Depth
  /// Cut off by the inference-step budget.
  Steps
  /// Cut off by the solution-count cap.
  Solutions
  /// A negated sub-search was cut off, so the result is unknown.
  IncompleteNegation
} derive(Eq, Debug)

///|
/// The result of running a query.
pub struct QueryResult {
  /// Solutions in search order.
  solutions : Array[Bindings]
  /// Names of the variables occurring in the query, in order of appearance.
  vars : Array[String]
  /// Output produced by `write/1` and `nl/0` during the search.
  output : String
  /// Why the search stopped; `Complete` when every answer was emitted.
  completion : Completion
}

///|
/// True when the search explored everything reachable.
pub fn QueryResult::is_complete(self : QueryResult) -> Bool {
  self.completion == Completion::Complete
}

///|
/// A short name for the completion reason: `"complete"`, `"depth"`,
/// `"steps"`, `"solutions"`, or `"incomplete-negation"`.
pub fn QueryResult::completion_name(self : QueryResult) -> String {
  match self.completion {
    Completion::Complete => "complete"
    Completion::Depth => "depth"
    Completion::Steps => "steps"
    Completion::Solutions => "solutions"
    Completion::IncompleteNegation => "incomplete-negation"
  }
}
