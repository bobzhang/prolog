///|
/// Errors raised by the Prolog parser and evaluator.
pub suberror PrologError {
  /// Parse error message, including line and column information.
  Parse(String)
  /// Evaluation error: arithmetic, instantiation, or type failures.
  Eval(String)
} derive(Debug)

///|
/// The human-readable error message.
pub fn PrologError::message(self : PrologError) -> String {
  match self {
    Parse(m) => m
    Eval(m) => m
  }
}
