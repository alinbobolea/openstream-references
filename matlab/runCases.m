function runCases(caseListFile, openstreamRoot, outputDir, options)
%RUNCASES Run every case of a case list and save the exported results.
%
%   RUNCASES(CASELISTFILE, OPENSTREAMROOT, OUTPUTDIR) validates the case list
%   before any solve, then for each case builds the input set the way
%   upstream's tests/integration/SolverIntegrationTest.m does, solves it,
%   and saves exportSolver's result as OUTPUTDIR/<name>.mat (variable
%   "result", MAT-file version 7). It finally writes
%   OUTPUTDIR/environment.json. Any error stops the run.
%
%   RUNCASES(..., ContinueOnError = true) goes on after a case whose solve or
%   export errors: the failure is recorded (runGuarded), the input files of
%   the case are copied to OUTPUTDIR/<name>-inputs, and OUTPUTDIR/failures.json
%   lists every failed case (an empty list when none failed). An error in the
%   case list, the input files or the overrides still stops the run: those are
%   mistakes of the list, not failures of upstream.

arguments
    caseListFile (1,1) string
    openstreamRoot (1,1) string
    outputDir (1,1) string
    options.ContinueOnError (1,1) logical = false
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

failures = {};
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

    % The solve and the export are the work of the case that may fail.
    files = string({prepared.modelFilePath, prepared.optionsFilePath, ...
        prepared.geometryFilePath, prepared.bcFilePath});
    failures = runGuarded( ...
        @() solveExportAndSave(c, inputSet, root, outputDir), ...
        string(c.name), files, outputDir, options.ContinueOnError, failures);
end

if options.ContinueOnError
    writeFailures(outputDir, failures);
    fprintf('\n%d of %d cases failed (failures.json)\n', numel(failures), ...
        numel(cases));
end

environmentRecord(fullfile(outputDir, "environment.json"));

end

function solveExportAndSave(c, inputSet, root, outputDir)
% Construction and solve run under the profiler; so does the export of the
% derived outputs, with its own record of executed lines.
[solver, coverage] = runProfiled( ...
    @() constructAndSolve(c.solver, inputSet), root);
result = exportSolver(solver, c);
result.coverage = coverage;
[derived, coverageDerived] = runProfiled(@() exportDerived(solver), root);
result.derived = toPlain(derived);
result.coverageDerived = coverageDerived; %#ok<STRNU> saved below
% The direct calls of the Mixture classes that the solve never makes, with their
% own record of executed lines (an empty record for the other solvers).
[probes, coverageProbes] = runProfiled(@() exportProbes(solver), root);
result.probes = toPlain(probes);
result.coverageProbes = coverageProbes; %#ok<STRNU> saved below
save(fullfile(outputDir, c.name + ".mat"), "result", "-v7");
end

function solver = constructAndSolve(solverClass, inputSet)
solver = feval(solverClass, inputSet);
solver.solve();
end
