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

for k = 1:numel(cases)
    requireValidOverrides(names(k), cases{k});
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

function requireValidOverrides(caseName, c)
% The optional override fields: model, options and geometry are structs of
% key-value pairs (no ID key, values formatInputValue accepts);
% boundaryConditions is a list of entries (boundaryConditionLines rules).
for kind = ["model" "options" "geometry"]
    if ~isfield(c, kind)
        continue
    end
    value = c.(kind);
    if ~isstruct(value) || ~isscalar(value)
        error('References:InvalidCase', ...
            'Case %s: %s must be a struct of key-value pairs', caseName, kind);
    end
    fields = reshape(string(fieldnames(value)), 1, []);
    if any(upper(fields) == "ID")
        error('References:InvalidCase', 'Case %s: %s cannot override ID', caseName, kind);
    end
    if numel(unique(upper(fields))) < numel(fields)
        error('References:InvalidCase', ...
            'Case %s: %s gives a key twice', caseName, kind);
    end
    for field = fields
        try
            formatInputValue(value.(field));
        catch err
            error('References:InvalidCase', 'Case %s: %s.%s: %s', ...
                caseName, kind, field, err.message);
        end
    end
end
if isfield(c, 'boundaryConditions')
    try
        boundaryConditionLines(c.boundaryConditions);
    catch err
        error('References:InvalidCase', 'Case %s: boundaryConditions: %s', ...
            caseName, err.message);
    end
end
end
