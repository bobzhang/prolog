% N-queens with pruning
select(X, [X|T], T).
select(X, [H|T], [H|R]) :- select(X, T, R).

range(N, N, [N]).
range(Lo, Hi, [Lo|R]) :- Lo < Hi, Lo1 is Lo + 1, range(Lo1, Hi, R).

queens(N, Qs) :- range(1, N, Ns), place(N, Ns, [], Qs).
place(_, [], Qs, Qs).
place(N, Cols, Acc, Qs) :-
    select(Q, Cols, Rest),
    \+ attack(Q, Acc, 1),
    place(N, Rest, [Q|Acc], Qs).
attack(Q, [Q1|_], D) :- Q =:= Q1 + D.
attack(Q, [Q1|_], D) :- Q =:= Q1 - D.
attack(Q, [_|Qs], D) :- D1 is D + 1, attack(Q, Qs, D1).
