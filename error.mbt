///|
/// Errors raised by the Prolog parser and evaluator.
#derive(Debug)
pub suberror PrologError {
  /// Parse error message, including line and column information.
  Parse(String)
  /// Evaluation error: arithmetic, instantiation, or type failures.
  Eval(String)
}

///|
pub extend PrologError with Debug::{to_repr}

///|
/// The human-readable error message.
pub fn PrologError::message(self : PrologError) -> String {
  match self {
    Parse(m) => m
    Eval(m) => m
  }
}
