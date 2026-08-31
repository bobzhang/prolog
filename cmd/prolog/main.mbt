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
  match matches.values.get("query") {
    Some([q, ..]) => {
      run_query(program, opts, q)
      0
    }
    _ => {
      repl(program, opts)
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
/// Run one query and print its output and answers.
async fn run_query(
  program : @lib.Program,
  opts : @lib.Options,
  text : String,
) -> Unit noraise {
  let result = program.query_with(text, opts) catch {
    e => {
      ignore(@stdio.stderr.write("error: \{e.message()}\n") catch { _ => () })
      return
    }
  }
  if result.output != "" {
    ignore(@stdio.stdout.write(result.output) catch { _ => () })
  }
  if result.solutions.is_empty() {
    ignore(@stdio.stdout.write("false.\n") catch { _ => () })
  } else {
    for line in result.answer_lines() {
      ignore(@stdio.stdout.write("\{line}\n") catch { _ => () })
    }
  }
  if result.truncated {
    ignore(
      @stdio.stderr.write("% note: search truncated by limits\n") catch {
        _ => ()
      },
    )
  }
}

///|
/// Interactive mode: read queries from standard input, one per line (a query
/// may span lines until one ends with `.`). `halt.` quits.
async fn repl(program : @lib.Program, opts : @lib.Options) -> Unit noraise {
  let mut buffer : Array[String] = []
  while true {
    let line = @stdio.stdin.read_until("\n") catch { _ => None }
    match line {
      None => {
        if !buffer.is_empty() {
          run_query(program, opts, buffer.join(""))
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
        if trimmed.has_suffix(".") {
          run_query(program, opts, buffer.join(""))
          buffer = []
        }
      }
    }
  }
}
