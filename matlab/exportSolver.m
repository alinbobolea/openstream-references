function result = exportSolver(solver, caseDef)
%EXPORTSOLVER Export a solved OpenSTREAM solver as plain MATLAB data.
%
%   RESULT = EXPORTSOLVER(SOLVER, CASEDEF) returns a struct with fields:
%
%   - caseDef:     the case-list entry
%   - solverClass: the solver class name
%   - state:       the solver state name, e.g. 'INITIALSTEPCONVERGED'
%   - solver:      every stored property of SOLVER, each exported in full
%                  (toPlain with independentProperties=true)
%   - compared:    W, U and H for each field path below that exists, one
%                  struct element per stored state of the path's root array
%                  ([] where a quantity is absent). Path dots become
%                  underscores in the field names.
%
%   The field paths and the way quantities are read (a property if the
%   object has one, else a zero-input method) follow upstream's
%   tests/integration/SolverIntegrationTest.m. Upstream's list has
%   "film.basefilm", which never matches: the four-field film property is
%   named "base". "film.base" is therefore added here.

COMPARED = ["mixture" "mixture.liquid" "mixture.vapor" "liquid" "vapor" ...
    "film" "drop" "film.basefilm" "film.wave" "film.base"];
QUANTITIES = {'W', 'U', 'H'};

result = struct();
result.caseDef = toPlain(caseDef);
result.solverClass = class(solver);
result.state = toPlain(solver.STATE);
result.solver = toPlain(solver, independentProperties = true);

compared = struct();
for fieldPath = COMPARED
    parts = cellstr(split(fieldPath, "."));
    if ~isprop(solver, parts{1}) || isempty(solver.(parts{1}))
        continue
    end
    states = solver.(parts{1});
    entries = repmat(struct('W', [], 'U', [], 'H', []), 1, numel(states));
    exists = true;
    for k = 1:numel(states)
        obj = states(k);
        for j = 2:numel(parts)
            if ~isprop(obj, parts{j}) || isempty(obj.(parts{j}))
                exists = false;
                break
            end
            obj = obj.(parts{j});
        end
        if ~exists
            break
        end
        for q = 1:numel(QUANTITIES)
            entries(k).(QUANTITIES{q}) = fieldValue(obj, QUANTITIES{q});
        end
    end
    if exists
        compared.(char(strrep(fieldPath, ".", "_"))) = entries;
    end
end
result.compared = compared;

end

function value = fieldValue(obj, name)
% A stored or dependent property, else a zero-input method, else [].
value = [];
if isprop(obj, name)
    value = obj.(name);
elseif ismethod(obj, name)
    value = feval(name, obj);
end
end
