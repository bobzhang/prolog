edge(a, b). edge(b, c). edge(c, a). edge(b, d).
path(X, Y) :- path(X, Y, [X]).
path(X, Y, _) :- edge(X, Y).
path(X, Y, V) :- edge(X, Z), \+ member(Z, V), path(Z, Y, [Z|V]).
