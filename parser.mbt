///|
/// Lexer token kinds.
enum TokKind {
  Atom(String)
  Var(String)
  NumInt(Int)
  NumFloat(Double)
  Str(String)
  LParen
  RParen
  LBracket
  RBracket
  Comma
  Pipe
  Cut
  Dot
  Op(String)
  Eof
} derive(Eq, Debug)

///|
priv struct Tok {
  kind : TokKind
  line : Int
  col : Int
}

///|
fn is_word_char(c : UInt16) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_'
}

///|
fn is_lower_start(c : UInt16) -> Bool {
  c >= 'a' && c <= 'z'
}

///|
fn is_upper_start(c : UInt16) -> Bool {
  (c >= 'A' && c <= 'Z') || c == '_'
}

///|
fn is_digit(c : UInt16) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn lex(src : StringView) -> Array[Tok] raise PrologError {
  let n = src.length()
  let toks : Array[Tok] = []
  let mut i = 0
  let mut line = 1
  let mut col = 1
  while i < n {
    let c = src[i]
    if c == ' ' || c == '\t' || c == '\r' {
      i += 1
      col += 1
      continue
    }
    if c == '\n' {
      i += 1
      line += 1
      col = 1
      continue
    }
    if c == '%' {
      while i < n && src[i] != '\n' {
        i += 1
        col += 1
      }
      continue
    }
    if c == '/' && i + 1 < n && src[i + 1] == '*' {
      i += 2
      col += 2
      let mut closed = false
      while i < n {
        if src[i] == '*' && i + 1 < n && src[i + 1] == '/' {
          i += 2
          col += 2
          closed = true
          break
        }
        if src[i] == '\n' {
          line += 1
          col = 1
        } else {
          col += 1
        }
        i += 1
      }
      if !closed {
        raise PrologError::Parse(
          "unterminated block comment (line \{line}, column \{col})",
        )
      }
      continue
    }
    if c == ';' {
      toks.push({ kind: Op(";"), line, col, })
      i += 1
      col += 1
      continue
    }
    if c == '(' {
      toks.push({ kind: LParen, line, col, })
      i += 1
      col += 1
      continue
    }
    if c == ')' {
      toks.push({ kind: RParen, line, col, })
      i += 1
      col += 1
      continue
    }
    if c == '[' {
      toks.push({ kind: LBracket, line, col, })
      i += 1
      col += 1
      continue
    }
    if c == ']' {
      toks.push({ kind: RBracket, line, col, })
      i += 1
      col += 1
      continue
    }
    if c == ',' {
      toks.push({ kind: Comma, line, col, })
      i += 1
      col += 1
      continue
    }
    if c == '|' {
      toks.push({ kind: Pipe, line, col, })
      i += 1
      col += 1
      continue
    }
    if c == '!' {
      toks.push({ kind: Cut, line, col, })
      i += 1
      col += 1
      continue
    }
    if c == '.' {
      toks.push({ kind: Dot, line, col, })
      i += 1
      col += 1
      continue
    }
    if c == '\'' || c == '"' {
      let (s, ni, nl, nc) = lex_quoted(src, i, line, col, c)
      toks.push({ kind: if c == '"' { Str(s) } else { Atom(s) }, line, col, })
      i = ni
      line = nl
      col = nc
      continue
    }
    if is_digit(c) {
      let mut j = i
      while j < n && is_digit(src[j]) {
        j += 1
      }
      let mut is_float = false
      if j < n && src[j] == '.' && j + 1 < n && is_digit(src[j + 1]) {
        is_float = true
        j += 1
        while j < n && is_digit(src[j]) {
          j += 1
        }
      }
      // Exponent notation: `e`/`E`, an optional sign, and at least one digit.
      if j < n && (src[j] == 'e' || src[j] == 'E') {
        let mut k = j + 1
        if k < n && (src[k] == '+' || src[k] == '-') {
          k += 1
        }
        if k < n && is_digit(src[k]) {
          is_float = true
          j = k
          while j < n && is_digit(src[j]) {
            j += 1
          }
        }
      }
      if is_float {
        let text = src[i:j].to_owned()
        let f : Double = @string.from_str(text) catch {
          _ =>
            raise PrologError::Parse(
              "invalid float literal '\{text}' (line \{line}, column \{col})",
            )
        }
        toks.push({ kind: NumFloat(f), line, col, })
        let len = j - i
        i = j
        col += len
        continue
      }
      let text = src[i:j].to_owned()
      let v : Int = @string.from_str(text) catch {
        _ =>
          raise PrologError::Parse(
            "invalid integer literal (line \{line}, column \{col})",
          )
      }
      toks.push({ kind: NumInt(v), line, col, })
      let len = j - i
      i = j
      col += len
      continue
    }
    if is_lower_start(c) {
      let mut j = i + 1
      while j < n && is_word_char(src[j]) {
        j += 1
      }
      toks.push({ kind: Atom(src[i:j].to_owned()), line, col, })
      let len = j - i
      i = j
      col += len
      continue
    }
    if is_upper_start(c) {
      let mut j = i + 1
      while j < n && is_word_char(src[j]) {
        j += 1
      }
      toks.push({ kind: Var(src[i:j].to_owned()), line, col, })
      let len = j - i
      i = j
      col += len
      continue
    }
    if c == ':' && i + 1 < n && src[i + 1] == '-' {
      toks.push({ kind: Op(":-"), line, col, })
      i += 2
      col += 2
      continue
    }
    if c == '=' {
      let op = if i + 2 < n && src[i + 1] == ':' && src[i + 2] == '=' {
        "=:="
      } else if i + 2 < n && src[i + 1] == '\\' && src[i + 2] == '=' {
        "=\\="
      } else if i + 1 < n && src[i + 1] == '=' {
        "=="
      } else if i + 1 < n && src[i + 1] == '<' {
        "=<"
      } else {
        "="
      }
      let len = op.length()
      toks.push({ kind: Op(op), line, col, })
      i += len
      col += len
      continue
    }
    if c == '<' {
      toks.push({ kind: Op("<"), line, col, })
      i += 1
      col += 1
      continue
    }
    if c == '>' {
      let len = if i + 1 < n && src[i + 1] == '=' { 2 } else { 1 }
      toks.push({ kind: Op(if len == 2 { ">=" } else { ">" }), line, col, })
      i += len
      col += len
      continue
    }
    if c == '\\' {
      let op = if i + 2 < n && src[i + 1] == '=' && src[i + 2] == '=' {
        "\\=="
      } else if i + 1 < n && src[i + 1] == '=' {
        "\\="
      } else if i + 1 < n && src[i + 1] == '+' {
        "\\+"
      } else {
        raise PrologError::Parse(
          "unexpected '\\' (line \{line}, column \{col})",
        )
      }
      let len = op.length()
      toks.push({ kind: Op(op), line, col, })
      i += len
      col += len
      continue
    }
    if c == '+' || c == '-' || c == '*' {
      toks.push({
        kind: Op(if c == '+' { "+" } else if c == '-' { "-" } else { "*" }),
        line,
        col,
      })
      i += 1
      col += 1
      continue
    }
    if c == '/' {
      let len = if i + 1 < n && src[i + 1] == '/' { 2 } else { 1 }
      toks.push({ kind: Op(if len == 2 { "//" } else { "/" }), line, col, })
      i += len
      col += len
      continue
    }
    raise PrologError::Parse(
      "unexpected character (line \{line}, column \{col})",
    )
  }
  toks.push({ kind: Eof, line, col, })
  toks
}

///|
fn lex_quoted(
  src : StringView,
  start : Int,
  line : Int,
  col : Int,
  quote : UInt16,
) -> (String, Int, Int, Int) raise PrologError {
  let n = src.length()
  let mut j = start + 1
  let mut l = line
  let mut c = col + 1
  let sb = StringBuilder()
  let mut seg_start = start + 1
  while j < n {
    let ch = src[j]
    if ch == quote {
      sb.write_string(src[seg_start:j].to_owned())
      return (sb.to_string(), j + 1, l, c + 1)
    }
    if ch == '\\' && j + 1 < n {
      let e = src[j + 1]
      sb.write_string(src[seg_start:j].to_owned())
      match e {
        'n' => sb.write_string("\n")
        't' => sb.write_string("\t")
        'r' => sb.write_string("\r")
        '\\' => sb.write_string("\\")
        '\'' => sb.write_string("'")
        '"' => sb.write_string("\"")
        _ => raise PrologError::Parse("invalid escape (line \{l}, column \{c})")
      }
      j += 2
      c += 2
      seg_start = j
      continue
    }
    if ch == '\n' {
      l += 1
      c = 1
    } else {
      c += 1
    }
    j += 1
  }
  raise PrologError::Parse("unterminated quoted token (line \{l}, column \{c})")
}

///|
/// Pratt parser over the token stream.
priv struct Parser {
  toks : Array[Tok]
  mut pos : Int
  mut anon : Int
}

///|
fn Parser::peek(self : Parser) -> TokKind {
  self.toks[self.pos].kind
}

///|
fn Parser::next(self : Parser) -> TokKind {
  let k = self.toks[self.pos].kind
  self.pos += 1
  k
}

///|
fn Parser::cur_line(self : Parser) -> Int {
  self.toks[self.pos - 1].line
}

///|
fn Parser::cur_col(self : Parser) -> Int {
  self.toks[self.pos - 1].col
}

///|
/// Infix operator table: `(operator, tightness, right-operand tightness)`.
/// Higher tightness binds tighter (ISO Prolog precedences inverted).
fn infix_info(op : String) -> (String, Int, Int)? {
  match op {
    ";" => Some((op, 400, 399))
    "," => Some((op, 500, 499))
    "="
    | "\\="
    | "=="
    | "\\=="
    | "=:="
    | "=\\="
    | "<"
    | ">"
    | "=<"
    | ">="
    | "is" => Some((op, 800, 801))
    "+" | "-" => Some((op, 1000, 1001))
    "*" | "/" | "//" | "mod" | "rem" => Some((op, 1100, 1101))
    _ => None
  }
}

///|
fn is_non_assoc(op : String) -> Bool {
  op == "=" ||
  op == "\\=" ||
  op == "==" ||
  op == "\\==" ||
  op == "=:=" ||
  op == "=\\=" ||
  op == "<" ||
  op == ">" ||
  op == "=<" ||
  op == ">=" ||
  op == "is"
}

///|
fn Parser::peek_op(self : Parser) -> String {
  match self.peek() {
    Op(op) => op
    Atom(a) => a
    Comma => ","
    _ => ""
  }
}

///|
fn Parser::parse_term(self : Parser, min_tight : Int) -> Term raise PrologError {
  let mut left = self.parse_primary()
  while true {
    let info : (String, Int, Int)? = match self.peek() {
      Op(op) => infix_info(op)
      Atom(a) => infix_info(a)
      Comma => infix_info(",")
      _ => None
    }
    match info {
      None => break
      Some((op, tight, rbp)) => {
        if tight <= min_tight {
          break
        }
        ignore(self.next())
        let rhs = self.parse_term(rbp)
        left = Compound(op, [left, rhs])
        if is_non_assoc(op) && is_non_assoc(self.peek_op()) {
          raise PrologError::Parse(
            "operator '\{op}' is not associative (line \{self.cur_line()}, column \{self.cur_col()})",
          )
        }
      }
    }
  }
  left
}

///|
fn Parser::parse_args(self : Parser) -> Array[Term] raise PrologError {
  let args : Array[Term] = []
  if self.peek() is RParen {
    ignore(self.next())
    return args
  }
  while true {
    args.push(self.parse_term(500))
    match self.next() {
      Comma => continue
      RParen => break
      _ =>
        raise PrologError::Parse(
          "expected ',' or ')' in arguments (line \{self.cur_line()}, column \{self.cur_col()})",
        )
    }
  }
  args
}

///|
fn Parser::parse_primary(self : Parser) -> Term raise PrologError {
  match self.next() {
    Atom(a) =>
      if self.peek() is LParen {
        ignore(self.next())
        Compound(a, self.parse_args())
      } else {
        Atom(a)
      }
    Var(v) =>
      if v == "_" {
        self.anon += 1
        Var("_\{self.anon}")
      } else {
        Var(v)
      }
    NumInt(n) => Int(n)
    NumFloat(f) => Float(f)
    Str(s) => Str(s)
    LParen => {
      let t = self.parse_term(0)
      match self.next() {
        RParen => t
        _ =>
          raise PrologError::Parse(
            "expected ')' (line \{self.cur_line()}, column \{self.cur_col()})",
          )
      }
    }
    LBracket => self.parse_list(500)
    Op("\\+") => Compound("\\+", [self.parse_term(601)])
    Op("+") => Compound("+", [self.parse_term(1001)])
    Op("-") => Compound("-", [self.parse_term(1301)])
    Op(op) =>
      raise PrologError::Parse(
        "unexpected operator '\{op}' (line \{self.cur_line()}, column \{self.cur_col()})",
      )
    Cut => Atom("!")
    Eof =>
      raise PrologError::Parse(
        "unexpected end of input (line \{self.cur_line()}, column \{self.cur_col()})",
      )
    _ =>
      raise PrologError::Parse(
        "unexpected token (line \{self.cur_line()}, column \{self.cur_col()})",
      )
  }
}

///|
fn Parser::parse_list(self : Parser, min_tight : Int) -> Term raise PrologError {
  match self.peek() {
    RBracket => {
      ignore(self.next())
      Atom("[]")
    }
    _ => {
      let head = self.parse_term(min_tight)
      match self.next() {
        Comma => {
          let tail = self.parse_list(min_tight)
          Compound(".", [head, tail])
        }
        Pipe => {
          let tail = self.parse_term(min_tight)
          match self.next() {
            RBracket => Compound(".", [head, tail])
            _ =>
              raise PrologError::Parse(
                "expected ']' after list tail (line \{self.cur_line()}, column \{self.cur_col()})",
              )
          }
        }
        RBracket => Compound(".", [head, Atom("[]")])
        _ =>
          raise PrologError::Parse(
            "expected ',', '|' or ']' in list (line \{self.cur_line()}, column \{self.cur_col()})",
          )
      }
    }
  }
}

///|
fn Parser::expect_dot(self : Parser) -> Unit raise PrologError {
  match self.next() {
    Dot => ()
    Eof =>
      raise PrologError::Parse(
        "expected '.' before end of input (line \{self.cur_line()}, column \{self.cur_col()})",
      )
    _ =>
      raise PrologError::Parse(
        "expected '.' (line \{self.cur_line()}, column \{self.cur_col()})",
      )
  }
}

///|
/// Parse a program: a sequence of clauses (facts and rules) ending in `.`.
pub fn Program::parse(text : String) -> Program raise PrologError {
  let p : Parser = { toks: lex(text), pos: 0, anon: 0, }
  p.parse_program()
}

///|
fn Parser::parse_program(self : Parser) -> Program raise PrologError {
  let clauses : Array[Clause] = []
  while self.pos < self.toks.length() - 1 {
    match self.peek() {
      Op(":-") =>
        raise PrologError::Parse(
          "unsupported directive (line \{self.toks[self.pos].line}, column \{self.toks[self.pos].col})",
        )
      _ => ()
    }
    let head = self.parse_term(0)
    let body = match self.peek() {
      Op(":-") => {
        ignore(self.next())
        self.parse_term(0)
      }
      Dot => Atom("true")
      _ =>
        raise PrologError::Parse(
          "expected '.' or ':-' after clause head (line \{self.cur_line()}, column \{self.cur_col()})",
        )
    }
    match head {
      Atom(_) | Compound(_, _) => ()
      _ =>
        raise PrologError::Parse(
          "clause head must be callable (line \{self.cur_line()}, column \{self.cur_col()})",
        )
    }
    self.expect_dot()
    clauses.push({ head, body, })
  }
  let map : Map[String, Array[Clause]] = Map([])
  for c in clauses {
    let (f, arity) = match c.head {
      Atom(a) => (a, 0)
      Compound(functor, args) => (functor, args.length())
      _ => raise PrologError::Parse("internal: non-callable clause head")
    }
    let key = "\{f}/\{arity}"
    let entry = map.get(key).unwrap_or([])
    entry.push(c)
    map.set(key, entry)
  }
  { clauses: map, }
}

///|
/// Parse a query: an optional `?-` prefix, a goal term, and an optional
/// trailing `.`. Returns the goal together with its variables in order of
/// first occurrence.
fn parse_goal(text : String) -> (Term, Array[String]) raise PrologError {
  let n = text.length()
  let mut i = 0
  while i < n &&
        (
          text[i] == ' ' ||
          text[i] == '\t' ||
          text[i] == '\r' ||
          text[i] == '\n'
        ) {
    i += 1
  }
  let core = if i + 1 < n && text[i] == '?' && text[i + 1] == '-' {
    text[i + 2:]
  } else {
    text[i:]
  }
  let p : Parser = { toks: lex(core), pos: 0, anon: 0, }
  let goal = p.parse_term(0)
  match p.peek() {
    Dot => ignore(p.next())
    Eof => ()
    _ =>
      raise PrologError::Parse(
        "expected '.' after query (line \{p.cur_line()}, column \{p.cur_col()})",
      )
  }
  if !(p.peek() is Eof) {
    raise PrologError::Parse(
      "unexpected trailing input after query (line \{p.cur_line()}, column \{p.cur_col()})",
    )
  }
  (goal, goal.free_vars())
}

///|
/// Parse a single term.
pub fn Term::parse(text : String) -> Term raise PrologError {
  parse_goal(text).0
}
