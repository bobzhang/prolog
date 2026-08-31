///|
/// Term display: pretty-printing with round-trip safe parentheses.
/// In "write mode" (`quote=false`), atoms and strings are printed without
/// quotes, as `write/1` does.

///|
pub fn Term::to_string(self : Term) -> String {
  fmt_term(self, 0, true, Map([]))
}

///|
/// Render a term the way `write/1` does: atoms and strings unquoted,
/// variables shown by their base name.
fn term_write(t : Term) -> String {
  fmt_term(t, 0, false, Map([]))
}

///|
/// Infix display table: `(tightness, left-context, right-context)`.
fn infix_display(op : String) -> (Int, Int, Int)? {
  match op {
    ";" => Some((400, 401, 400))
    "," => Some((500, 501, 500))
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
    | "is" => Some((800, 801, 801))
    "+" | "-" => Some((1000, 1001, 1001))
    "*" | "/" | "//" | "mod" | "rem" => Some((1100, 1101, 1101))
    _ => None
  }
}

///|
fn is_prefix_functor(f : String) -> Bool {
  f == "-" || f == "+" || f == "\\+"
}

///|
fn fmt_term(
  t : Term,
  prec : Int,
  quote : Bool,
  rename : Map[String, String],
) -> String {
  match t {
    Var(n) =>
      match rename.get(n) {
        Some(r) => r
        None => if quote { n } else { base_name(n) }
      }
    Atom(a) =>
      if a == "[]" {
        "[]"
      } else if quote && needs_quotes(a) {
        "'\{escape_quoted(a)}'"
      } else {
        a
      }
    Int(n) => n.to_string()
    Float(f) => fmt_float(f)
    Str(s) => if quote { "\"\{escape_string(s)}\"" } else { s }
    Compound(f, args) =>
      if f == "." && args.length() == 2 {
        fmt_list(t, prec, quote, rename)
      } else if args.length() == 1 && is_prefix_functor(f) {
        let (tight, s) = match f {
          "-" => (1300, "-\{fmt_term(args[0], 1301, quote, rename)}")
          "+" => (1000, "+\{fmt_term(args[0], 1001, quote, rename)}")
          _ => (600, "\\+ \{fmt_term(args[0], 601, quote, rename)}")
        }
        if tight < prec {
          "(\{s})"
        } else {
          s
        }
      } else {
        match infix_display(f) {
          Some((tight, lp, rp)) if args.length() == 2 => {
            let s = match f {
              "," =>
                "\{fmt_term(args[0], lp, quote, rename)}, \{fmt_term(args[1], rp, quote, rename)}"
              ";" =>
                "\{fmt_term(args[0], lp, quote, rename)}; \{fmt_term(args[1], rp, quote, rename)}"
              _ =>
                "\{fmt_term(args[0], lp, quote, rename)} \{f} \{fmt_term(args[1], rp, quote, rename)}"
            }
            if tight < prec {
              "(\{s})"
            } else {
              s
            }
          }
          _ =>
            if args.is_empty() {
              functor_text(f, quote)
            } else {
              let inner = args
                .map(a => fmt_term(a, 501, quote, rename))
                .join(", ")
              "\{functor_text(f, quote)}(\{inner})"
            }
        }
      }
  }
}

///|
fn fmt_list(
  t : Term,
  _prec : Int,
  quote : Bool,
  rename : Map[String, String],
) -> String {
  let elems : Array[String] = []
  let mut cur = t
  let mut tail : Term = Atom("[]")
  while true {
    match cur {
      Compound(".", [h, tl]) => {
        elems.push(fmt_term(h, 501, quote, rename))
        cur = tl
        continue
      }
      other => {
        tail = other
        break
      }
    }
  }
  let s = match tail {
    Atom("[]") => "[\{elems.join(", ")}]"
    _ => "[\{elems.join(", ")}|\{fmt_term(tail, 501, quote, rename)}]"
  }
  s
}

///|
fn functor_text(f : String, quote : Bool) -> String {
  if quote && needs_quotes(f) {
    "'\{escape_quoted(f)}'"
  } else {
    f
  }
}

///|
fn needs_quotes(a : String) -> Bool {
  if a.is_empty() {
    return true
  }
  if a == "[]" {
    return false
  }
  let c0 = a[0]
  if c0 < 'a' || c0 > 'z' {
    return true
  }
  let n = a.length()
  let mut j = 1
  while j < n {
    if !is_word_char(a[j]) {
      return true
    }
    j += 1
  }
  false
}

///|
fn escape_quoted(s : String) -> String {
  let sb = StringBuilder()
  for c in s {
    match c {
      '\'' => sb.write_string("\\'")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\t' => sb.write_string("\\t")
      '\r' => sb.write_string("\\r")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn escape_string(s : String) -> String {
  let sb = StringBuilder()
  for c in s {
    match c {
      '"' => sb.write_string("\\\"")
      '\\' => sb.write_string("\\\\")
      '\n' => sb.write_string("\\n")
      '\t' => sb.write_string("\\t")
      '\r' => sb.write_string("\\r")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn fmt_float(f : Double) -> String {
  let s = f.to_string()
  if s.contains(".") ||
    s.contains("e") ||
    s.contains("E") ||
    s.contains("inf") ||
    s.contains("nan") {
    s
  } else {
    "\{s}.0"
  }
}

///|
/// Strip a trailing `_<digits>` suffix introduced by clause renaming:
/// `X_7` becomes `X` (the anonymous placeholder `_3` stays `_`).
fn base_name(name : String) -> String {
  let n = name.length()
  if n == 0 {
    return name
  }
  // Internal (interpreter-created) variables carry a leading `~`; strip it
  // so answers render cleanly.
  let start = if name[0] == '~' { 1 } else { 0 }
  let mut j = n - 1
  while j >= start {
    let c = name[j]
    if c < '0' || c > '9' {
      break
    }
    j -= 1
  }
  if j == start && name[start] == '_' {
    "_"
  } else if j >= start && j < n - 1 && name[j] == '_' {
    name[start:j].to_owned()
  } else {
    name[start:].to_owned()
  }
}
