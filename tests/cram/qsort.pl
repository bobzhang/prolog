qsort([], []).
qsort([X|Xs], S) :- split(X, Xs, Lo, Hi), qsort(Lo, S1), qsort(Hi, S2), append(S1, [X|S2], S).

split(_, [], [], []).
split(P, [Y|Ys], [Y|Lo], Hi) :- Y =< P, split(P, Ys, Lo, Hi).
split(P, [Y|Ys], Lo, [Y|Hi]) :- Y > P, split(P, Ys, Lo, Hi).
