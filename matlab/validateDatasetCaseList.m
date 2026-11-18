function validateDatasetCaseList(cases, databaseRoot)
%VALIDATEDATASETCASELIST Check a dataset case list before any case is run.
%
%   VALIDATEDATASETCASELIST(CASES, DATABASEROOT) checks, in this order, and
%   errors on the first problem found:
%
%   - every case has the required fields name, dataset, testID, solver,
%     model and options, and case names are unique; the optional fields
%     geometry and boundaryConditions, when present, are scalar structs of
%     key-value pairs without an ID key and with values that
%     formatInputValue accepts (References:InvalidCase);
%   - the dataset package folder DATABASEROOT/+<dataset> exists
%     (References:MissingInput);
%   - the solver is one of Mixture, TwoFluid, ThreeField, FourField
%     (References:UnknownSolver).
%
%   CASES is a struct array, or a cell array of structs as returned by
%   jsondecode when entries have different fields.

arguments
    cases
    databaseRoot (1,1) string
end

if iscell(cases)
    cases = reshape(cases, 1, []);
else
    cases = num2cell(reshape(cases, 1, []));
end

required = {'name', 'dataset', 'testID', 'solver', 'model', 'options'};
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
    for kind = ["geometry" "boundaryConditions"]
        if isfield(cases{k}, kind)
            requireOverrideStruct(names(k), kind, cases{k}.(kind));
        end
    end
end

solvers = ["Mixture" "TwoFluid" "ThreeField" "FourField"];
for k = 1:numel(cases)
    c = cases{k};
    folder = fullfile(databaseRoot, "+" + string(c.dataset));
    if ~isfolder(folder)
        error('References:MissingInput', 'Case %s: %s not found', ...
            names(k), folder);
    end
    if ~ismember(string(c.solver), solvers)
        error('References:UnknownSolver', 'Case %s: unknown solver %s', ...
            names(k), string(c.solver));
    end
end

end

function requireOverrideStruct(caseName, kind, value)
% An optional override: a scalar struct of key-value pairs, no ID key, values
% that formatInputValue accepts.
if ~isstruct(value) || ~isscalar(value)
    error('References:InvalidCase', ...
        'Case %s: %s must be a struct of key-value pairs', caseName, kind);
end
fields = reshape(string(fieldnames(value)), 1, []);
if any(upper(fields) == "ID")
    error('References:InvalidCase', 'Case %s: %s cannot override ID', caseName, kind);
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
