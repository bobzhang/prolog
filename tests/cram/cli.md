# CLI transcript tests

Unification and arithmetic:

```mooncram
$ prolog.exe --query "X = 1, Y = 2"
X = 1, Y = 2
```

```mooncram
$ prolog.exe --query "member(X, [a, b, c])"
X = a
X = b
X = c
```

```mooncram
$ prolog.exe --query "append(X, Y, [1, 2, 3])"
X = [], Y = [1, 2, 3]
X = [1], Y = [2, 3]
X = [1, 2], Y = [3]
X = [1, 2, 3], Y = []
```

```mooncram
$ prolog.exe --query "X is 1 + 2 * 3"
X = 7
```

```mooncram
$ prolog.exe --query "member(d, [a, b])"
false.
```

Transitive closure over a family tree:

```mooncram
$ prolog.exe --program "parent(john, mary). parent(mary, ann). parent(mary, tom). parent(ann, sam). ancestor(X, Y) :- parent(X, Y). ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y)." --query "parent(X, mary)"
X = john
```

```mooncram
$ prolog.exe --program "parent(john, mary). parent(mary, ann). parent(mary, tom). parent(ann, sam). ancestor(X, Y) :- parent(X, Y). ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y)." --query "ancestor(john, X)"
X = mary
X = ann
X = tom
X = sam
```

```mooncram
$ prolog.exe --program "parent(john, mary). parent(mary, ann). parent(mary, tom). parent(ann, sam). ancestor(X, Y) :- parent(X, Y). ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y)." --query "ancestor(tom, X)"
false.
```

Cut and negation:

```mooncram
$ prolog.exe --query "\+ member(3, [1, 2])"
true
```

```mooncram
$ prolog.exe --query "(X = 1; X = 2), write(X), nl"
1
2
X = 1
X = 2
```

```mooncram
$ prolog.exe --program "a(1) :- !. a(2)." --query "a(X)"
X = 1
```

Four queens:

```mooncram
$ prolog.exe --program "select(X, [X|T], T). select(X, [H|T], [H|R]) :- select(X, T, R). range(N, N, [N]). range(Lo, Hi, [Lo|R]) :- Lo < Hi, Lo1 is Lo + 1, range(Lo1, Hi, R). queens(N, Qs) :- range(1, N, Ns), place(N, Ns, [], Qs). place(_, [], Qs, Qs). place(N, Cols, Acc, Qs) :- select(Q, Cols, Rest), \+ attack(Q, Acc, 1), place(N, Rest, [Q|Acc], Qs). attack(Q, [Q1|_], D) :- Q =:= Q1 + D. attack(Q, [Q1|_], D) :- Q =:= Q1 - D. attack(Q, [_|Qs], D) :- D1 is D + 1, attack(Q, Qs, D1)." --query "queens(4, Q)"
Q = [3, 1, 4, 2]
Q = [2, 4, 1, 3]
```

Search limits are reported on stderr and keep the exit code:

```mooncram
$ prolog.exe --program "nat(0). nat(N) :- nat(M), N is M + 1." --depth 3 --query "nat(N)"
N = 0
N = 1
N = 2
```

Repeated `--query` options run in order:

```mooncram
$ prolog.exe --query "X = 1" --query "X = 2"
X = 1
X = 2
```

Evaluation errors are reported on stderr and fail with a nonzero exit code:

```mooncram
$ prolog.exe --query "X is 1/0"
[1]
```

Invalid numeric flags fail with a usage error:

```mooncram
$ prolog.exe --depth=-1 --query "true"
[2]
```

The REPL collects a statement until its brackets are balanced and it ends in
`.`, so a query may span several lines and strings may contain newlines:

```mooncram
$ prolog.exe <<'EOF'
> (X = 1;
>  X = 2).
> write("hello.
> world").
> halt.
> EOF
X = 1
X = 2
hello.
worldtrue
```

