function validateCaseList(cases, openstreamRoot)
%VALIDATECASELIST Check a case list before any case is run.
%
%   VALIDATECASELIST(CASES, OPENSTREAMROOT) checks, in this order, and
%   errors on the first problem found:
%
%   - every case has the required fields, and case names are unique
%     (References:InvalidCase);
%   - the input files exist under OPENSTREAMROOT/inputs, and an optional
%     non-empty upstreamReference exists under OPENSTREAMROOT
%     (References:MissingInput);
%   - the solver class exists on the path (References:UnknownSolver).
%
%   CASES is a struct array, or a cell array of structs as returned by
%   jsondecode when entries have different fields.

arguments
    cases
    openstreamRoot (1,1) string
end

if iscell(cases)
    cases = reshape(cases, 1, []);
else
    cases = num2cell(reshape(cases, 1, []));
end

required = {'name', 'solver', 'modelFile', 'modelID', 'optionsFile', ...
    'optionsID', 'geometryFile', 'geometryID', 'bcFile'};
names = strings(1, numel(cases));
for k = 1:numel(cases)
    missing = required(~isfield(cases{k}, required));
    if ~isempty(missing)
        error('References:InvalidCase', 'Case %d is missing field(s): %s', ...
            k, strjoin(missing, ', '));
    end
    names(k) = string(cases{k}.name);
end
[uniqueNames, ~, index] = unique(names);
counts = accumarray(index(:), 1);
if any(counts > 1)
    error('References:InvalidCase', 'Duplicate case name(s): %s', ...
        strjoin(uniqueNames(counts > 1), ', '));
end

inputFields = {'modelFile', 'optionsFile', 'geometryFile', 'bcFile'};
for k = 1:numel(cases)
    c = cases{k};
    for j = 1:numel(inputFields)
        requireFile(names(k), fullfile(openstreamRoot, "inputs", c.(inputFields{j})));
    end
    if isfield(c, 'upstreamReference') && strlength(string(c.upstreamReference)) > 0
        requireFile(names(k), fullfile(openstreamRoot, c.upstreamReference));
    end
    if isempty(meta.class.fromName(char(c.solver)))
        error('References:UnknownSolver', 'Case %s: unknown solver class %s', ...
            names(k), c.solver);
    end
end

end

function requireFile(caseName, path)
if ~isfile(path)
    error('References:MissingInput', 'Case %s: %s not found', caseName, path);
end
end
