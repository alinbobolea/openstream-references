function runDatasetCases(caseListFile, openstreamRoot, databaseRoot, outputDir)
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
%   It finally writes OUTPUTDIR/environment.json. Any error stops the run.

arguments
    caseListFile (1,1) string
    openstreamRoot (1,1) string
    databaseRoot (1,1) string
    outputDir (1,1) string
end

setupOpenstream(openstreamRoot);
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
    if isfield(c, 'relaxCondCoefficients')
        coefficients = c.relaxCondCoefficients;
        entryData = data.entryData;
        coolprop = CoolPropWrapper.CoolPropWrapper('water');
        viscosity = coolprop.viscosity('P', entryData.Pressure, 'Q', 0);
        reynolds = entryData.MassFlux * entryData.Diameter / viscosity;
        opts.model.RELAXCONDCOEF = ...
            [coefficients(1) / reynolds^coefficients(2), 1/3, 1.0e-4, 0.0];
    end

    % Generate the inputs and run, with warnings off as the paper does.
    data.makeInputFiles(inputOptions = opts, ...
        ioDirectory = fullfile(workDir, c.name));
    warningState = warning;
    warning('off', 'all');
    try
        data.runCase(c.solver, 'inputSetOpts', inputSetOpts, ...
            'saveResultsToFile', false);
    catch err
        warning(warningState);
        rethrow(err);
    end
    warning(warningState);

    result = exportSolver(data.results, c); %#ok<NASGU> saved below
    save(fullfile(outputDir, c.name + ".mat"), "result", "-v7");

    inputsDir = fullfile(outputDir, c.name + "-inputs");
    mkdir(inputsDir);
    for source = {data.modelFilePath, data.optionsFilePath, ...
            data.geometryFilePath, data.bcFilePath}
        copyfile(source{1}, inputsDir);
    end
end

environmentRecord(fullfile(outputDir, "environment.json"));

end
