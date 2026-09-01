///|
/// White-box tests for the CLI's statement-completeness scanner.
test "statement completeness" {
  assert_true(statement_complete("X = 1."))
  assert_true(statement_complete("f(a, b)."))
  assert_true(statement_complete("write(\"a.b\")."))
  assert_true(statement_complete("'it\\'s' = X."))
  assert_true(statement_complete("f(\n  a,\n  b\n)."))
  assert_true(statement_complete("X = 1. % trailing comment"))
  assert_false(statement_complete("X = 1"))
  assert_false(statement_complete("f(a."))
  assert_false(statement_complete("f(a). g("))
  assert_false(statement_complete("X = \"unterminated"))
  assert_false(statement_complete("(X = 1; X = 2"))
}
