function validateDatasetCaseList(cases, databaseRoot)
%VALIDATEDATASETCASELIST Check a dataset case list before any case is run.
%
%   VALIDATEDATASETCASELIST(CASES, DATABASEROOT) checks, in this order, and
%   errors on the first problem found:
%
%   - every case has the required fields name, dataset, testID, solver,
%     model and options, and case names are unique (References:InvalidCase);
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
