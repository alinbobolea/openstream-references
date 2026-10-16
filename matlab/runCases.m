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

for k = 1:numel(cases)
    c = cases{k};
    fprintf('\n=== %s (%s) ===\n', c.name, c.solver);

    % Upstream's test suppresses input-default warnings only while the
    % input set is built.
    warningState = warning;
    warning('off', 'all');
    try
        inputSet = Inputs.InputSet( ...
            modelFilePath         = fullfile(inputFolder, c.modelFile), ...
            modelID               = c.modelID, ...
            optionsFilePath       = fullfile(inputFolder, c.optionsFile), ...
            optionsID             = c.optionsID, ...
            geometryFilePath      = fullfile(inputFolder, c.geometryFile), ...
            geometryID            = c.geometryID, ...
            bcFilePath            = fullfile(inputFolder, c.bcFile), ...
            sessionParentDir      = workDir, ...
            overwriteSessionFiles = true, ...
            LOGMODE               = 'BOTH');
    catch err
        warning(warningState);
        rethrow(err);
    end
    warning(warningState);

    solver = feval(c.solver, inputSet);
    solver.solve();

    result = exportSolver(solver, c); %#ok<NASGU> saved below
    save(fullfile(outputDir, c.name + ".mat"), "result", "-v7");
end

environmentRecord(fullfile(outputDir, "environment.json"));

end
