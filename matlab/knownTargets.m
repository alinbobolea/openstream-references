function names = knownTargets()
%KNOWNTARGETS The names of the targets runTarget accepts.
%
%   NAMES = KNOWNTARGETS() returns the target names as a string row. The
%   choices of the workflow input "target" are these names, except
%   "input-fixture-windows", which only the Windows job of the workflow runs.

names = ["tutorial1" "nuthos15-bartolomey" "input-fixture" "semantics-fixture" ...
    "extension" "input-fixture-windows"];

end
