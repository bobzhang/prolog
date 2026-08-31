% family relationships
parent(john, mary).
parent(mary, ann).
parent(mary, tom).
parent(ann, sam).

ancestor(X, Y) :- parent(X, Y).
ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).

% natural numbers via backtracking
nat(0).
nat(N) :- nat(M), N is M + 1.
