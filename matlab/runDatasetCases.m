function runDatasetCases(caseListFile, openstreamRoot, databaseRoot, outputDir, options)
%RUNDATASETCASES Run dataset-driven cases and save the exported results.
%
%   RUNDATASETCASES(CASELISTFILE, OPENSTREAMROOT, DATABASEROOT, OUTPUTDIR)
%   validates the case list before any solve. For each case it:
%
%   - finds the record of the database dataset whose TestID is testID;
%   - starts from the dataset's default input options and copies the case's
%     model and options fields into them;
%   - when relaxCondCoefficients = [c1 c2] is given, sets
%     RELAXCONDCOEF = [c1/Re^c2 1/3 1.0e-4 0.0], with
%     Re = MassFlux*Diameter/viscosity of saturated liquid at the record's
%     pressure (the runBartolomey function of the database's NUTHOS-15
%     project);
%   - generates the input files with the database's makeInputFiles, solves
%     with runCase, and saves exportSolver's result as
%     OUTPUTDIR/<name>.mat (variable "result", MAT-file version 7);
%   - copies the four generated input files to OUTPUTDIR/<name>-inputs.
%
%   - when a case has cbtElevationFromRecord = true, sets
%     model.CBTELEVATION to the record's dryout elevation ZBO (the runBecker
%     function of the same project), and errors when the record has none;
%
%   It finally writes OUTPUTDIR/environment.json. Any error stops the run.
%
%   RUNDATASETCASES(..., ContinueOnError = true) goes on after a case whose
%   solve or export errors: the failure is recorded (runGuarded), the four
%   generated input files of the case are copied to OUTPUTDIR/<name>-inputs,
%   and OUTPUTDIR/failures.json lists every failed case (an empty list when
%   none failed). An error in the case list, the record or the options still
%   stops the run.

arguments
    caseListFile (1,1) string
    openstreamRoot (1,1) string
    databaseRoot (1,1) string
    outputDir (1,1) string
    options.ContinueOnError (1,1) logical = false
end

root = setupOpenstream(openstreamRoot);
databasePath = char(databaseRoot);
if ~startsWith(databasePath, filesep)
    databasePath = fullfile(pwd, databasePath);
end
addpath(databasePath);

cases = jsondecode(fileread(caseListFile));
validateDatasetCaseList(cases, databasePath);
if ~iscell(cases)
    cases = num2cell(cases);
end

if ~isfolder(outputDir)
    mkdir(outputDir);
end
workDir = tempname;
mkdir(workDir);
inputSetOpts = {'overwriteSessionFiles', true, 'LOGMODE', 'BOTH'};

failures = {};
for k = 1:numel(cases)
    c = cases{k};
    fprintf('\n=== %s (%s, TestID %d, %s) ===\n', c.name, c.dataset, ...
        c.testID, c.solver);

    % Find the record in the dataset.
    constructor = [char(c.dataset) '.' char(c.dataset)];
    allRecords = feval(constructor);
    index = find(allRecords.dataset.TestID == c.testID);
    if numel(index) ~= 1
        error('References:InvalidCase', ...
            'Case %s: %d records with TestID %d in %s', ...
            c.name, numel(index), c.testID, c.dataset);
    end
    data = feval(constructor, index);

    % Build the options.
    opts = data.inputOptions();
    for field = fieldnames(c.model)'
        opts.model.(field{1}) = c.model.(field{1});
    end
    for field = fieldnames(c.options)'
        opts.options.(field{1}) = c.options.(field{1});
    end
    for kind = ["geometry" "boundaryConditions"]
        if isfield(c, kind)
            for field = fieldnames(c.(kind))'
                opts.(kind).(field{1}) = c.(kind).(field{1});
            end
        end
    end
    if isfield(c, 'relaxCondCoefficients')
        coefficients = c.relaxCondCoefficients;
        entryData = data.entryData;
        coolprop = CoolPropWrapper.CoolPropWrapper('water');
        viscosity = coolprop.viscosity('P', entryData.Pressure, 'Q', 0);
        reynolds = entryData.MassFlux * entryData.Diameter / viscosity;
        opts.model.RELAXCONDCOEF = ...
            [coefficients(1) / reynolds^coefficients(2), 1/3, 1.0e-4, 0.0];
    end

    if isfield(c, 'cbtElevationFromRecord') && c.cbtElevationFromRecord
        elevation = data.entryData.ZBO;
        if ~isnumeric(elevation) || ~isscalar(elevation) || ~isfinite(elevation)
            error('References:InvalidCase', ...
                'Case %s: the record has no dryout elevation (ZBO)', c.name);
        end
        opts.model.CBTELEVATION = elevation;
    end

    % Generate the inputs and run, with warnings off as the paper does.
    data.makeInputFiles(inputOptions = opts, ...
        ioDirectory = fullfile(workDir, c.name));
    files = string({data.modelFilePath, data.optionsFilePath, ...
        data.geometryFilePath, data.bcFilePath});
    failures = runGuarded( ...
        @() runAndExport(c, data, root, inputSetOpts, outputDir, files), ...
        string(c.name), files, outputDir, options.ContinueOnError, failures);
end

if options.ContinueOnError
    writeFailures(outputDir, failures);
    fprintf('\n%d of %d cases failed (failures.json)\n', numel(failures), ...
        numel(cases));
end

environmentRecord(fullfile(outputDir, "environment.json"));

end

function runAndExport(c, data, root, inputSetOpts, outputDir, files)
% The run and the export of one case, the work that may fail.
% The run (construction and solve) is under the profiler, and so is the
% export of the derived outputs, with its own record of executed lines.
warningState = warning;
warning('off', 'all');
try
    [~, coverage] = runProfiled(@() runCaseOf(data, c.solver, inputSetOpts), root);
catch err
    warning(warningState);
    rethrow(err);
end
warning(warningState);

result = exportSolver(data.results, c);
result.coverage = coverage;
[derived, coverageDerived] = runProfiled(@() exportDerived(data.results), root);
result.derived = toPlain(derived);
result.coverageDerived = coverageDerived; %#ok<STRNU> saved below
save(fullfile(outputDir, c.name + ".mat"), "result", "-v7");

inputsDir = fullfile(outputDir, c.name + "-inputs");
mkdir(inputsDir);
for source = files
    copyfile(source, inputsDir);
end

end

function ok = runCaseOf(data, solverName, inputSetOpts)
% The dataset's own run; the value only gives runProfiled something to return.
data.runCase(solverName, 'inputSetOpts', inputSetOpts, 'saveResultsToFile', false);
ok = true;
end
