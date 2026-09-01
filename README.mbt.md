# Prolog in MoonBit

A small, well-tested [Prolog](https://en.wikipedia.org/wiki/Prolog) interpreter
written in MoonBit. It parses Prolog programs, runs queries by SLD
resolution, and returns answers as variable bindings.

## Features

- **Terms**: atoms, variables, integers, floats, strings, lists (`[a, b|T]`),
  and compound terms, with a parser for the standard operator set
  (`:-`, `;`, `,`, `\+`, `=`, `\=`, `==`, `\==`, `is`, comparisons,
  arithmetic operators) and round-trip safe pretty printing.
- **Resolution**: bounded depth-first search with **iterative deepening**
  (default — fair and terminating on finite programs), **cut** (`!`), and
  **negation-as-failure** (`\+` / `not`). The engine is iterative, so deep
  searches use constant stack space.
- **Unification** with occurs check.
- **Arithmetic** (`is/2`): `+ - * / // mod rem abs min max sqrt`, and the
  numeric comparisons `=:= =\= < > =< >=`.
- **Term inspection**: `var/1 nonvar/1 atom/1 integer/1 float/1 number/1
  string/1 atomic/1 compound/1 ground/1 is_list/1`.
- **List built-ins**: `member/2`, `append/3`, `reverse/2`, `length/2`,
  `nth0/3`, `between/3`.
- **Output**: `write/1` and `nl/0`, collected into the query result.

## Quick start

Parse a program and run a query:

```mbt check
///|
test {
  let program_text =
    #|parent(john, mary).
    #|parent(mary, ann).
    #|parent(mary, tom).
    #|ancestor(X, Y) :- parent(X, Y).
    #|ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).
  let p = Program::parse(program_text) catch { e => fail(e.message()) }
  assert_eq(p.query("ancestor(john, X)").answer_lines(), [
    "X = mary", "X = ann", "X = tom",
  ])
}
```

Unification, arithmetic, and list built-ins:

```mbt check
///|
test {
  let p = Program::parse("") catch { e => fail(e.message()) }
  assert_eq(p.query("X = f(Y), Y = 2").answer_lines(), ["X = f(2), Y = 2"])
  assert_eq(p.query("X is 1 + 2 * 3").answer_lines(), ["X = 7"])
  assert_eq(p.query("append(X, Y, [1, 2])").answer_lines(), [
    "X = [], Y = [1, 2]", "X = [1], Y = [2]", "X = [1, 2], Y = []",
  ])
}
```

`write/1` output is collected into the result:

```mbt check
///|
test {
  let p = Program::parse("") catch { e => fail(e.message()) }
  let r = p.query("(X = 1; X = 2), write(X), nl")
  assert_eq(r.output, "1\n2\n")
  assert_eq(r.answer_lines(), ["X = 1", "X = 2"])
}
```

## Search semantics

Queries run a **bounded** search (see `Options`). By default:

- iterative deepening: the depth limit grows until a round completes
  without hitting a bound (or `max_depth` is reached), so terminating
  searches produce the same answers, in the same order, as classic
  depth-first Prolog, while left-recursive programs cannot loop forever;
- at most `max_steps` inference steps and `max_solutions` answers per
  query; `QueryResult::completion` reports whether (and why) a bound cut the
  search space off.

## Command line

The `cmd/prolog` executable loads a program file (or `--program` text) and
answers queries:

```
$ moon run cmd/prolog -- --query "member(X, [a, b, c])"
X = a
X = b
X = c
```

Or interactively: pipe one query per line (a query may span lines until one
ends with `.`), and `halt.` quits.

## Known limitations

- `\+` searches within the current depth budget (bounded negation).
- Open-list generation is bounded (see `length/2`, `member/2`).
- The occurs check is always on, so `X = f(X)` fails.
- Strings are terms, not lists of character codes.

## License

Apache-2.0