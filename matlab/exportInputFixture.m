function exportInputFixture(manifestFile, openstreamRoot, outputDir)
%EXPORTINPUTFIXTURE Record what OpenSTREAM and MATLAB do with input cases.
%
%   EXPORTINPUTFIXTURE(MANIFESTFILE, OPENSTREAMROOT, OUTPUTDIR) puts
%   OpenSTREAM on the path, reads the manifest MANIFESTFILE (a JSON array of
%   cases, see validateInputFixtureList) and validates it before any case
%   runs. It then runs every case and saves OUTPUTDIR/input_fixture.mat
%   (MAT-file version 7) holding one variable, "fixture", a struct whose
%   field "cases" is a 1xN cell array, one struct per manifest entry:
%
%   - name, kind:         from the manifest entry;
%   - input:              the manifest entry (toPlain);
%   - ok:                 true when the case finished without error;
%   - errorId,
%     errorMessage:       the error ('' when ok);
%   - console:            everything the case printed, warnings included
%                         (evalc, warning backtraces off). For inputset
%                         cases the console is not captured ('') because
%                         evalc disables the diary the session log writes;
%   - lastWarningId,
%     lastWarningMessage: lastwarn after the case (reset to '' before it);
%   - result:             the case's result, per kind ([] when not ok).
%
%   Every case runs inside try/catch with the same warning state, so one
%   failing case never stops the run or changes the next one. File paths
%   in the manifest are relative to the current folder. Numbers are given
%   as text lists {"double": [...]} and converted with str2double; every
%   argument is converted by FixtureArguments, and upper, sprintf, num2str
%   and strcat cases run through runFunctionCase (the call that
%   functionCall describes), handle, ismembertol, uint8 and sum cases
%   through runNumberCase. The run
%   then writes OUTPUTDIR/environment.json and finally errors
%   (checkInputFixtureCases) if a case failed because of the manifest
%   itself, so that a manifest typo cannot pass for an intended failure.

arguments
    manifestFile (1,1) string
    openstreamRoot (1,1) string
    outputDir (1,1) string
end

setupOpenstream(openstreamRoot);
entries = jsondecode(fileread(manifestFile));
validateInputFixtureList(entries, true);
entries = FixtureArguments.list(entries);

if ~isfolder(outputDir)
    mkdir(outputDir);
end

previousWarnings = warning;
restoreWarnings = onCleanup(@() warning(previousWarnings));
warning('off', 'backtrace');
caseWarnings = warning;

cases = cell(1, numel(entries));
for k = 1:numel(entries)
    warning(caseWarnings);
    cases{k} = runCase(entries{k});
    fprintf('%s (%s): ok=%d\n', cases{k}.name, cases{k}.kind, cases{k}.ok);
end
clear restoreWarnings

fixture = struct();
fixture.cases = cases;
save(fullfile(outputDir, "input_fixture.mat"), "fixture", "-v7");

environmentRecord(fullfile(outputDir, "environment.json"));

checkInputFixtureCases(cases);

end

function c = runCase(entry)
% One case, with its console output, last warning and error recorded.
c = struct();
c.name = char(entry.name);
c.kind = char(entry.kind);
c.input = toPlain(entry);

% evalc disables diary, which the session log of an input set writes, so
% inputset cases run without console capture (console is then '').
captureConsole = ~strcmp(c.kind, 'inputset');
lastwarn('', '');
[console, result, err] = runCaptured(@() runGuarded(entry), captureConsole);
[warningMessage, warningId] = lastwarn;

c.ok = isempty(err);
if c.ok
    c.errorId = '';
    c.errorMessage = '';
else
    c.errorId = err.identifier;
    c.errorMessage = err.message;
    result = [];
end
c.console = console;
c.lastWarningId = warningId;
c.lastWarningMessage = warningMessage;
c.result = result;
end

function [console, result, err] = runCaptured(guarded, captureConsole)
% Call GUARDED (which never throws) for its two outputs, with evalc
% capturing the console when CAPTURECONSOLE is true; console is '' when not.
console = '';
if captureConsole
    try
        % Outputs named in the evalc call, as the evalc documentation advises.
        [console, result, err] = evalc('guarded()');
    catch evalcError
        % runGuarded catches every error of the case; this guards evalc itself.
        console = '';
        result = [];
        err = evalcError;
    end
else
    [result, err] = guarded();
end
end

function [result, err] = runGuarded(entry)
% Run one case; return its error instead of throwing it.
result = [];
err = [];
try
    result = runKind(entry);
catch caught
    err = caught;
end
end

function result = runKind(e)
kind = char(e.kind);
switch kind
    case 'read'
        result = describeValue(InputFileReader.read(e.file));
    case 'convert2json'
        result = toPlain(Inputs.Input.convert2JSON(e.file));
    case {'model', 'options', 'geometry'}
        obj = constructInput(kind, e.file, e.id);
        result = struct();
        result.object = toPlain(obj);
        result.extra = describeValue(obj.extra);
        if strcmp(kind, 'geometry')
            derived = struct();
            derived.HDIAM = describeValue(obj.HDIAM());
            derived.ADIAM = describeValue(obj.ADIAM());
            derived.NWALL = describeValue(obj.NWALL());
            derived.RWALL = describeValue(obj.RWALL());
            result.derived = derived;
        end
    case 'bc'
        g = Inputs.Geometry(e.geometryFile, e.geometryId);
        objs = Inputs.BoundaryConditions(e.file, g);
        extra = cell(size(objs));
        for k = 1:numel(objs)
            extra{k} = describeValue(objs(k).extra);
        end
        result = struct();
        result.objects = toPlain(objs);
        result.extra = extra;
    case 'default'
        obj = defaultInput(e.class);
        result = toPlain(obj);
    case 'listprops'
        obj = defaultInput(e.class);
        [n, d, s] = obj.listInputProperties();
        result = struct();
        result.names = describeValue(n);
        result.defaults = describeValue(d);
        result.nameValue = describeValue(s);
    case 'write'
        result = toPlain(writeCalls(e));
    case {'handle', 'ismembertol', 'uint8', 'sum'}
        result = runNumberCase(e);
    case 'textscan'
        scanned = textscan(string(e.text), '%f');
        result = describeValue(scanned{1});
    case {'upper', 'sprintf', 'num2str', 'strcat'}
        result = runFunctionCase(e);
    case 'readlines'
        result = describeValue(readlines(e.file));
    case 'sumsweep'
        result = describeValue(sumSweep(reshape(e.lengths, 1, [])));
    case 'legalpath'
        result = Session.isLegalPath(e.path);
    case 'inputset'
        result = inputSetCase(e);
    otherwise
        error('References:InvalidInputFixture', 'Unknown kind %s', kind);
end
end

function obj = constructInput(kind, file, id)
% The constructor call assigned to a variable (nargout = 1), as the input
% set does it.
switch kind
    case 'model'
        obj = Inputs.Model(file, id);
    case 'options'
        obj = Inputs.Options(file, id);
    case 'geometry'
        obj = Inputs.Geometry(file, id);
end
end

function obj = defaultInput(className)
switch char(className)
    case 'Model'
        obj = Inputs.Model();
    case 'Options'
        obj = Inputs.Options();
    case 'Geometry'
        obj = Inputs.Geometry();
    case 'BoundaryConditions'
        obj = Inputs.BoundaryConditions();
    otherwise
        error('References:InvalidInputFixture', 'Unknown class %s', className);
end
end

function text = writeCalls(e)
% Successive writeInputFile calls into one new temporary file; its text.
file = [tempname '.inp'];
cleanup = onCleanup(@() deleteIfPresent(file));
calls = FixtureArguments.list(e.calls);
for k = 1:numel(calls)
    args = FixtureArguments.writeArguments(e.class, calls{k});
    switch char(e.class)
        case 'Model'
            Inputs.Model.writeInputFile(file, args{:});
        case 'Options'
            Inputs.Options.writeInputFile(file, args{:});
        case 'Geometry'
            Inputs.Geometry.writeInputFile(file, args{:});
        case 'BoundaryConditions'
            Inputs.BoundaryConditions.writeInputFile(file, args{:});
        otherwise
            % Guards a class that writeArguments accepts but this switch
            % does not, which would otherwise write nothing.
            error('References:InvalidInputFixture', 'Unknown class %s', e.class);
    end
end
text = fileread(file);
clear cleanup
end

function s = sumSweep(lengths)
% For each n: the sum, in MATLAB's order, of 0.1*k for k = 1..n with
% every fifth value from k = 1 replaced by 1e16 and from k = 2 by -1e16.
s = zeros(1, max(lengths));
for n = lengths
    k = 1:n;
    v = 0.1 * k;
    v(mod(k, 5) == 1) = 1e16;
    v(mod(k, 5) == 2) = -1e16;
    s(n) = sum(v);
end
end

function result = inputSetCase(e)
% Build an input set in a new temporary session parent folder.
parent = tempname;
mkdir(parent);
cleanup = onCleanup(@() removeFolder(parent));

args = {'sessionParentDir', parent, 'overwriteSessionFiles', true, ...
    'LOGMODE', char(e.logmode)};
parts = {'model', 'modelFilePath', 'modelID'; ...
    'options', 'optionsFilePath', 'optionsID'; ...
    'geometry', 'geometryFilePath', 'geometryID'};
for k = 1:size(parts, 1)
    if isfield(e, parts{k, 1})
        pair = FixtureArguments.list(e.(parts{k, 1}));
        args = [args, {parts{k, 2}, char(pair{1}), parts{k, 3}, char(pair{2})}]; %#ok<AGROW>
    end
end
if isfield(e, 'bc')
    args = [args, {'bcFilePath', char(e.bc)}];
end

inputSet = Inputs.InputSet(args{:});

plain = toPlain(inputSet);
if isstruct(plain.session) && isfield(plain.session, 'parentDir')
    plain.session = rmfield(plain.session, 'parentDir');
end
% The solver names as the solvers pass them (AbstractSolver).
vaporFric = struct();
for solver = {'Mixture', 'TwoFluid', 'ThreeField', 'FourField'}
    applied = inputSet.applySolverDependentProps(solver{1});
    vaporFric.(upper(solver{1})) = toPlain(applied.model.VAPORFRIC);
end

result = struct();
result.inputSet = plain;
result.vaporFric = vaporFric;
result.files = sessionFiles(char(inputSet.session.directory));
clear cleanup
end

function files = sessionFiles(folder)
% Name and text of every file in FOLDER, sorted by name; empty when the
% folder does not exist.
files = struct('name', {}, 'text', {});
if ~isfolder(folder)
    return
end
listing = dir(folder);
names = sort({listing(~[listing.isdir]).name});
for k = 1:numel(names)
    files(k).name = names{k};
    files(k).text = fileread(fullfile(folder, names{k}));
end
end

function deleteIfPresent(file)
if isfile(file)
    delete(file);
end
end

function removeFolder(folder)
if isfolder(folder)
    try
        rmdir(folder, 's');
    catch
        % A file still open in the folder must not fail the case.
    end
end
end
