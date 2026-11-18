function runCases(caseListFile, openstreamRoot, outputDir)
%RUNCASES Run every case of a case list and save the exported results.
%
%   RUNCASES(CASELISTFILE, OPENSTREAMROOT, OUTPUTDIR) validates the case list
%   before any solve, then for each case builds the input set the way
%   upstream's tests/integration/SolverIntegrationTest.m does, solves it,
%   and saves exportSolver's result as OUTPUTDIR/<name>.mat (variable
%   "result", MAT-file version 7). It finally writes
%   OUTPUTDIR/environment.json. Any error stops the run.

arguments
    caseListFile (1,1) string
    openstreamRoot (1,1) string
    outputDir (1,1) string
end

root = setupOpenstream(openstreamRoot);
cases = jsondecode(fileread(caseListFile));
validateCaseList(cases, root);
if ~iscell(cases)
    cases = num2cell(cases);
end

if ~isfolder(outputDir)
    mkdir(outputDir);
end
workDir = tempname;
mkdir(workDir);
inputFolder = fullfile(root, 'inputs');

% What the profiler reports for the lines of a class with known executed
% lines, so that the lines an upstream file requires are decided from MATLAB's
% own output.
calibration = calibrateProfiler(); %#ok<NASGU> saved below
save(fullfile(outputDir, "profiler-calibration.mat"), "calibration", "-v7");

for k = 1:numel(cases)
    c = cases{k};
    fprintf('\n=== %s (%s) ===\n', c.name, c.solver);

    % The files of the case: the upstream ones, or, when the case overrides
    % keys or boundary conditions, files written for it.
    prepared = prepareCaseInputs(c, inputFolder, fullfile(workDir, "inputs-" + c.name));

    % Upstream's test suppresses input-default warnings only while the
    % input set is built.
    warningState = warning;
    warning('off', 'all');
    try
        inputSet = Inputs.InputSet( ...
            modelFilePath         = prepared.modelFilePath, ...
            modelID               = prepared.modelID, ...
            optionsFilePath       = prepared.optionsFilePath, ...
            optionsID             = prepared.optionsID, ...
            geometryFilePath      = prepared.geometryFilePath, ...
            geometryID            = prepared.geometryID, ...
            bcFilePath            = prepared.bcFilePath, ...
            sessionParentDir      = workDir, ...
            overwriteSessionFiles = true, ...
            LOGMODE               = 'BOTH');
    catch err
        warning(warningState);
        rethrow(err);
    end
    warning(warningState);
    requireOverridesUsed(inputSet, prepared.overrides);

    % Construction and solve run under the profiler; so does the export of
    % the derived outputs, with its own record of executed lines.
    [solver, coverage] = runProfiled( ...
        @() constructAndSolve(c.solver, inputSet), root);
    result = exportSolver(solver, c);
    result.coverage = coverage;
    [derived, coverageDerived] = runProfiled(@() exportDerived(solver), root);
    result.derived = toPlain(derived);
    result.coverageDerived = coverageDerived; %#ok<STRNU> saved below
    save(fullfile(outputDir, c.name + ".mat"), "result", "-v7");
end

environmentRecord(fullfile(outputDir, "environment.json"));

end

function solver = constructAndSolve(solverClass, inputSet)
solver = feval(solverClass, inputSet);
solver.solve();
end
