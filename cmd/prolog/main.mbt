///|
/// A small Prolog interpreter: loads an optional program file and answers
/// queries given with `--query` or read from standard input.
suberror CliError {
  Msg(String)
} derive(Debug)

///|
async fn main {
  let code = run() catch {
    CliError::Msg(msg) => {
      ignore(@stdio.stderr.write("\{msg}\n") catch { _ => () })
      @sys.exit(2)
      fail("unreachable")
    }
  }
  @sys.exit(code)
}

///|
async fn run() -> Int raise CliError {
  let matches = @argparse.parse(
    @argparse.Command(
      "prolog",
      about="A small Prolog interpreter in MoonBit.",
      flags=[
        @argparse.FlagArg(
          "dfs",
          long="dfs",
          action=@argparse.FlagAction::SetTrue,
          about="Plain depth-first search instead of iterative deepening.",
        ),
      ],
      options=[
        @argparse.OptionArg(
          "query",
          short='q',
          long="query",
          action=@argparse.OptionAction::Append,
          about="Run one query and exit instead of reading stdin (repeatable).",
        ),
        @argparse.OptionArg(
          "program",
          long="program",
          about="Prolog program text (alternative to a program file).",
        ),
        @argparse.OptionArg(
          "depth",
          long="depth",
          default_values=["32"],
          about="Maximum resolution depth (default 32).",
        ),
        @argparse.OptionArg(
          "max-steps",
          long="max-steps",
          default_values=["1000000"],
          about="Maximum inference steps per query (default 1000000).",
        ),
        @argparse.OptionArg(
          "max-solutions",
          long="max-solutions",
          default_values=["1000"],
          about="Maximum solutions per query (default 1000).",
        ),
      ],
      positionals=[
        @argparse.PositionArg("file", about="Prolog program file (optional)."),
      ],
    ),
  ) catch {
    e => raise CliError::Msg(e.to_string())
  }
  let file = match matches.values.get("file") {
    Some([f, ..]) => f
    _ => ""
  }
  let opts = opts_from_matches(matches)
  let text = if file == "" {
    match matches.values.get("program") {
      Some([p, ..]) => p
      _ => ""
    }
  } else {
    @fs.read_file(file).text() catch {
      e => raise CliError::Msg("cannot read \{file}: \{e.to_string()}")
    }
  }
  let program = @lib.Program::parse(text) catch {
    e => raise CliError::Msg(e.message())
  }
  let queries = match matches.values.get("query") {
    Some(qs) => qs
    _ => []
  }
  if queries.is_empty() {
    repl(program, opts)
    0
  } else {
    // Run every supplied query in order; a failing query is reported but
    // does not stop the remaining ones from running.
    let mut failed = false
    for q in queries {
      if run_query(program, opts, q) != 0 {
        failed = true
      }
    }
    if failed {
      1
    } else {
      0
    }
  }
}

///|
fn opts_from_matches(
  matches : @argparse.Matches,
) -> @lib.Options raise CliError {
  let base = @lib.Options::new()
  fn int_opt(name : String, default : Int) -> Int raise CliError {
    match matches.values.get(name) {
      Some([v, ..]) => {
        let x : Int = @string.from_str(v) catch {
          _ => raise CliError::Msg("invalid integer for --\{name}: \{v}")
        }
        if x < 0 {
          raise CliError::Msg("--\{name} must be non-negative")
        }
        x
      }
      _ => default
    }
  }
  @lib.Options::make(
    int_opt("depth", base.max_depth),
    !matches.flags.get("dfs").unwrap_or(false),
    int_opt("max-steps", base.max_steps),
    int_opt("max-solutions", base.max_solutions),
  )
}

///|
/// Write to stdout, reporting I/O failure instead of raising.
async fn stdout_write(text : String) -> Bool noraise {
  @stdio.stdout.write(text) catch {
    _ => return false
  }
  true
}

///|
/// Write to stderr, reporting I/O failure instead of raising.
async fn stderr_write(text : String) -> Bool noraise {
  @stdio.stderr.write(text) catch {
    _ => return false
  }
  true
}

///|
/// Run one query and print its output and answers. Returns 0 on success and
/// 1 on parse/evaluation/I/O failure.
async fn run_query(
  program : @lib.Program,
  opts : @lib.Options,
  text : String,
) -> Int noraise {
  let result = program.query_with(text, opts) catch {
    e => {
      ignore(stderr_write("error: \{e.message()}\n"))
      return 1
    }
  }
  let mut ok = true
  if result.output != "" {
    if !stdout_write(result.output) {
      ok = false
    }
  }
  if result.solutions.is_empty() {
    if !stdout_write("false.\n") {
      ok = false
    }
  } else {
    for line in result.answer_lines() {
      if !stdout_write("\{line}\n") {
        ok = false
      }
    }
  }
  if result.truncated {
    if !stderr_write("% note: search truncated by limits\n") {
      ok = false
    }
  }
  if ok {
    0
  } else {
    1
  }
}

///|
/// True when `text` is a complete statement: brackets balanced, not inside a
/// quoted string or comment, and the last significant character is `.`.
fn statement_complete(text : String) -> Bool {
  let n = text.length()
  let mut i = 0
  let mut depth = 0
  let mut in_squote = false
  let mut in_dquote = false
  let mut saw_dot = false
  while i < n {
    let c = text[i]
    if in_squote {
      if c == '\\' && i + 1 < n {
        i += 2
        continue
      }
      if c == '\'' {
        in_squote = false
      }
      i += 1
      continue
    }
    if in_dquote {
      if c == '\\' && i + 1 < n {
        i += 2
        continue
      }
      if c == '"' {
        in_dquote = false
      }
      i += 1
      continue
    }
    if c == '%' {
      while i < n && text[i] != '\n' {
        i += 1
      }
      continue
    }
    if c == '/' && i + 1 < n && text[i + 1] == '*' {
      i += 2
      while i + 1 < n && !(text[i] == '*' && text[i + 1] == '/') {
        i += 1
      }
      i += 2
      continue
    }
    if c == '\'' {
      in_squote = true
      saw_dot = false
      i += 1
      continue
    }
    if c == '"' {
      in_dquote = true
      saw_dot = false
      i += 1
      continue
    }
    if c == '(' || c == '[' {
      depth += 1
      saw_dot = false
      i += 1
      continue
    }
    if c == ')' || c == ']' {
      depth -= 1
      saw_dot = false
      i += 1
      continue
    }
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      i += 1
      continue
    }
    if c == '.' {
      saw_dot = true
      i += 1
      continue
    }
    saw_dot = false
    i += 1
  }
  depth == 0 && !in_squote && !in_dquote && saw_dot
}

///|
/// Interactive mode: read queries from standard input. A statement is complete
/// only when its brackets are balanced and its last significant character is
/// `.`, so a query may span several lines. `halt.` quits.
async fn repl(program : @lib.Program, opts : @lib.Options) -> Unit noraise {
  let mut buffer : Array[String] = []
  while true {
    let line = @stdio.stdin.read_until("\n") catch { _ => None }
    match line {
      None => {
        if !buffer.is_empty() {
          ignore(run_query(program, opts, buffer.join("\n")))
        }
        break
      }
      Some(l) => {
        let trimmed = l.trim()
        if trimmed == "" {
          continue
        }
        if trimmed == "halt" || trimmed == "halt." {
          break
        }
        buffer.push(l)
        if statement_complete(buffer.join("\n")) {
          ignore(run_query(program, opts, buffer.join("\n")))
          buffer = []
        }
      }
    }
  }
}
