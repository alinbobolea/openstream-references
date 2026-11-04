function result = runSessionCase(e)
%RUNSESSIONCASE The result of a logcalls, sessionfs, inputsetcall or inputsetwarnings case.
%
%   RESULT = RUNSESSIONCASE(E) runs the case E (a scalar struct as
%   jsondecode returns a manifest entry, valid by validateInputFixtureList)
%   in a new scratch folder, removed when the case is over, and returns what
%   it records. The scratch folder is the folder scratch of a new sandbox
%   folder (tempname), which is removed instead, so that the names . and ..
%   of a session folder, resolved against the scratch folder, stay inside the
%   sandbox. OpenSTREAM must be on the path. An error of the session, the
%   log or the input set is recorded, not thrown; an entry that cannot be
%   run (an unknown kind, a malformed argument) errors with
%   References:InvalidInputFixture.
%
%   The text <scratch> inside a text of the entry (a session name, a folder
%   name, an argument or a value) stands for the path of the scratch folder
%   and is replaced by it before the case runs. In every recorded text the
%   path is replaced by <scratch> again (and the path of the sandbox by
%   <sandbox>), so that a record does not depend on the run. Paths of files
%   are relative to the current folder; during a sessionfs case with the
%   empty text as parent the current folder is the scratch folder (a session
%   folder with a relative name then stays inside the sandbox). The caller's
%   folder is the current folder again before the files are listed and on
%   every exit, before the sandbox is removed.
%
%   The record is a struct. Its parts:
%
%   - error:    struct(identifier, message), both '' when there is no error;
%   - warnings: struct array (identifier, message), the warnings issued;
%   - console:  char, the text printed (evalc, warning backtraces off);
%   - files:    struct array (name, isFolder, text, hex): every file and
%               folder in the scratch folder at the end, sorted by name; name
%               is relative to the scratch folder with / as separator; for a
%               file, text is its text and hex the lower case hex of its
%               bytes (both with the scratch path replaced by <scratch>), for
%               a folder both are '';
%   - calls:    struct array (op, error, warnings), one per call of a
%               logcalls case, error and warnings as above;
%   - sandboxFiles: sessionfs only; the same listing for the sandbox, names
%               relative to the sandbox (so with the prefix scratch/).
%
%   By kind:
%
%   - logcalls:         the Session.Session("name", sessionName, "dirName",
%                       "run", "parentDir", scratch) is built (when
%                       sessionName is null there is no session and
%                       Session.Log(logmode) is called directly), setupLog
%                       (logmode) is called (not when logmode is null), then
%                       the calls in order; op log and warning call the
%                       method of the log with the arguments (a text, or a
%                       one-key argument converted by FixtureArguments),
%                       openLog, closeLog likewise, openLogKeep is openLog
%                       ("keepLogOpen", true), readLog reads session.log,
%                       readLogFilePath reads logFilePath of the log,
%                       removeFolder is rmdir(session.directory, "s"). The
%                       record has error (of the set-up), warnings (of the
%                       set-up), calls, console and files. The warnings of a
%                       call are lastwarn after it (reset before it): one at
%                       most. The error of a call is recorded for the call
%                       and the following calls still run. After the last
%                       call a log file still open is closed (an error of
%                       that is ignored), so that the text recorded for it
%                       is complete;
%   - sessionfs:        before the call, in the scratch folder, "before" is
%                       made at dirName (absent: nothing; folder: a folder;
%                       folderWithFile: a folder with the file old.txt; file:
%                       a file; ownLogOpen: the folder made by a first
%                       session of the same arguments with setupLog (BOTH),
%                       its log file then opened with openLog
%                       ("keepLogOpen", true) and kept open until the second
%                       session is set up). The session is built with the
%                       parent (exists: the scratch folder; missing: a
%                       folder that does not exist; file: a file; empty: the
%                       empty text) and "overwrite", and setupLog (logmode)
%                       is called; afterwards the logs still open are closed
%                       (errors ignored). The record has error, warnings,
%                       console, files and sandboxFiles. The warnings are
%                       those a WarningRecorder saw (every call of the
%                       function warning, in order, with identifier and
%                       formatted message; the recorder does not depend on
%                       the console, whose form of a displayed warning
%                       differs between hosts), plus the last warning of
%                       lastwarn when the recorder did not see it (a direct
%                       call of builtin('warning'), as the log makes). The
%                       notice that a function has the name of a built-in
%                       is dropped;
%   - inputsetcall:     Inputs.InputSet(args{:}) is called with the pairs of
%                       args (a text value, given as a string scalar, which
%                       the input set validates for the session names, or a
%                       one-key argument; the list of pairs, or one pair
%                       alone), after sessionParentDir (the scratch folder) and
%                       overwriteSessionFiles (true) unless args gives
%                       them, and LOGMODE. The scratch folder holds a file
%                       afile beforehand. No console is captured (evalc turns
%                       the diary of the session log off). The record has
%                       error, warnings (as for sessionfs) and files, also
%                       when the call failed;
%   - inputsetwarnings: Inputs.InputSet is built as the inputset case does
%                       it (model, options, geometry as [file, id] pairs, bc
%                       a file, LOGMODE, in the scratch folder, overwriting).
%                       With capture "console" it is built inside evalc and
%                       the record is struct(console); with "files" without
%                       evalc and the record is struct(files). An error of
%                       the build is not recorded: it propagates, with the
%                       scratch path replaced in its message.

if ~isstruct(e) || ~isscalar(e) || ~isfield(e, 'kind')
    error('References:InvalidInputFixture', 'A case must be an object with a kind');
end
kind = char(e.kind);
if ~ismember(kind, {'logcalls', 'sessionfs', 'inputsetcall', 'inputsetwarnings'})
    error('References:InvalidInputFixture', 'No session case for kind %s', kind);
end

sandbox = tempname;
scratch = fullfile(sandbox, 'scratch');
mkdir(scratch);
callerFolder = pwd;
cleanup = onCleanup(@() leave(callerFolder, sandbox));
previousWarnings = warning('off', 'backtrace');
restoreWarnings = onCleanup(@() warning(previousWarnings));

switch kind
    case 'logcalls'
        result = logCalls(e, scratch);
    case 'sessionfs'
        result = sessionFs(e, scratch);
    case 'inputsetcall'
        result = inputSetCall(e, scratch);
    case 'inputsetwarnings'
        result = inputSetWarnings(e, scratch);
end

end

% ----- logcalls -----

function result = logCalls(e, scratch)
ops = FixtureArguments.list(e.calls);
calls = cell(1, numel(ops));
for k = 1:numel(ops)
    c = ops{k};
    if ~isstruct(c) || ~isscalar(c) || ~isfield(c, 'op') || ~isfield(c, 'args')
        error('References:InvalidInputFixture', 'Call %d needs an op and args', k);
    end
    calls{k} = struct('op', char(c.op), 'args', {callArguments(c.args, scratch)});
end
mode = optionalText(e.logmode);
sessionName = optionalText(e.sessionName);
if ischar(sessionName)
    sessionName = markerToScratch(sessionName, scratch);
end
if ~ischar(sessionName) && ~ischar(mode)
    error('References:InvalidInputFixture', ...
        'A logcalls case needs a log mode or a session name');
end

guarded = @() logBody(mode, sessionName, calls, scratch);
[console, state] = evalc('guarded()');

result = struct();
result.error = state.error;
result.warnings = state.warnings;
result.calls = state.calls;
result.console = recordedText(console, scratch);
result.files = listFiles(scratch, scratch);
result = markScratch(result, scratch);
end

function state = logBody(mode, sessionName, calls, scratch)
% Set up the log and make the calls; never throws.
state = struct();
state.error = noError();
state.warnings = noWarnings();
state.calls = struct('op', {}, 'error', {}, 'warnings', {});
session = [];
logObj = [];
lastwarn('', '');
try
    if ischar(sessionName)
        session = Session.Session("name", string(sessionName), "dirName", "run", ...
            "parentDir", scratch);
        if ischar(mode)
            session.setupLog(mode);
        end
        logObj = session.log;
    else
        logObj = Session.Log(mode);
    end
catch err
    state.error = errorRecord(err);
    state.warnings = lastWarning();
    return
end
state.warnings = lastWarning();

for k = 1:numel(calls)
    op = calls{k}.op;
    args = calls{k}.args;
    lastwarn('', '');
    callError = noError();
    try
        switch op
            case 'log'
                logObj.log(args{:});
            case 'warning'
                logObj.warning(args{:});
            case 'openLog'
                logObj.openLog(args{:});
            case 'openLogKeep'
                logObj.openLog("keepLogOpen", true);
            case 'closeLog'
                logObj.closeLog(args{:});
            case 'readLog'
                unused = session.log; %#ok<NASGU>
            case 'readLogFilePath'
                unused = logObj.logFilePath; %#ok<NASGU>
            case 'removeFolder'
                rmdir(session.directory, 's');
            otherwise
                error('References:InvalidInputFixture', 'Unknown op %s', op);
        end
    catch err
        if strcmp(err.identifier, 'References:InvalidInputFixture')
            rethrow(err);
        end
        callError = errorRecord(err);
    end
    state.calls(k) = struct('op', op, 'error', callError, 'warnings', lastWarning());
end
% A log file still open would be read before MATLAB has written all of it.
closeQuietly(logObj);
end

function closeQuietly(logObj)
% Close the file of a log object, ignoring any error (the file may be closed,
% the folder gone, or there may be no log).
try
    logObj.closeLog();
catch
end
end

function args = callArguments(list, scratch)
% The arguments of a call as a 1xN cell: a text (the marker replaced) or the
% value of a one-key argument.
items = FixtureArguments.list(list);
args = cell(1, numel(items));
for k = 1:numel(items)
    item = items{k};
    if ischar(item)
        args{k} = markerToScratch(item, scratch);
    elseif isstruct(item)
        args{k} = FixtureArguments.value(item);
    else
        error('References:InvalidInputFixture', ...
            'An argument must be a text or an object with one key');
    end
end
end

% ----- sessionfs -----

function result = sessionFs(e, scratch)
dirName = markerToScratch(char(e.dirName), scratch);
target = fullfile(scratch, dirName);
switch char(e.parent)
    case 'exists'
        parentDir = scratch;
    case 'missing'
        parentDir = fullfile(scratch, 'missing');
    case 'file'
        parentDir = fullfile(scratch, 'parentfile');
        makeFile(parentDir, 'x');
    case 'empty'
        parentDir = '';
    otherwise
        error('References:InvalidInputFixture', 'Unknown parent %s', char(e.parent));
end
overwrite = logical(e.overwrite);
mode = char(e.logmode);
before = char(e.before);

callerFolder = pwd;
guarded = @() sessionBody(before, target, dirName, parentDir, overwrite, mode);
% The recorder is made before evalc and sees each warning with its
% identifier, whatever the console shows. It is released at the end, and by
% the cleanup on an error exit.
recorder = WarningRecorder();
releaseRecorder = onCleanup(@() releaseIfValid(recorder));
% A session folder with a relative name (an empty parent) is made in the
% current folder: for that one case the scratch folder is the current
% folder during the case. runSessionCase returns to the caller's folder on
% every exit.
if isempty(parentDir)
    cd(scratch);
end
lastwarn('', '');
[console, state] = evalc('guarded()');
[lastMessage, lastId] = lastwarn;
cd(callerFolder);
warnings = WarningRecorder.complete(recorder.recorded(), lastMessage, lastId);
releaseIfValid(recorder);

result = struct();
result.error = state.error;
result.warnings = warnings;
result.console = recordedText(console, scratch);
result.files = listFiles(scratch, scratch);
result.sandboxFiles = listFiles(fileparts(scratch), scratch);
result = markScratch(result, scratch);
end

function state = sessionBody(before, target, dirName, parentDir, overwrite, mode)
% Prepare the folder, build the session and set the log up; never throws.
% The session of the case "ownLogOpen" is returned in the state so that its
% log file stays open until the state is dropped.
state = struct('error', noError(), 'first', []);
try
    switch before
        case 'absent'
        case 'folder'
            makeFolder(target);
        case 'folderWithFile'
            makeFolder(target);
            makeFile(fullfile(target, 'old.txt'), 'old');
        case 'file'
            makeFolder(fileparts(target));
            makeFile(target, 'x');
        case 'ownLogOpen'
            state.first = Session.Session("dirName", string(dirName), ...
                "parentDir", parentDir, "overwriteFiles", false);
            state.first.setupLog('BOTH');
            state.first.log.openLog("keepLogOpen", true);
        otherwise
            error('References:InvalidInputFixture', 'Unknown before %s', before);
    end
    session = Session.Session("dirName", string(dirName), "parentDir", parentDir, ...
        "overwriteFiles", overwrite);
    session.setupLog(mode);
    closeQuietly(session.log);
catch err
    if strcmp(err.identifier, 'References:InvalidInputFixture')
        rethrow(err);
    end
    state.error = errorRecord(err);
end
if ~isempty(state.first)
    closeQuietly(state.first.log);
end
end

function releaseIfValid(recorder)
% Release a recorder that has not been released yet.
if isvalid(recorder)
    delete(recorder);
end
end

function leave(callerFolder, sandbox)
% Back to the caller's folder, then the sandbox goes (in this order: a
% folder cannot be removed on every host while it is the current folder).
cd(callerFolder);
removeFolder(sandbox);
end

% ----- inputsetcall -----

function result = inputSetCall(e, scratch)
makeFile(fullfile(scratch, 'afile'), 'x');
pairs = argumentPairs(e.args, scratch);
args = {};
given = cellfun(@(p) p{1}, pairs, 'UniformOutput', false);
if ~ismember('sessionParentDir', given)
    args = [args, {'sessionParentDir', scratch}];
end
if ~ismember('overwriteSessionFiles', given)
    args = [args, {'overwriteSessionFiles', true}];
end
args = [args, {'LOGMODE', char(e.logmode)}];
for k = 1:numel(pairs)
    args = [args, pairs{k}]; %#ok<AGROW>
end

recorder = WarningRecorder();
releaseRecorder = onCleanup(@() releaseIfValid(recorder));
lastwarn('', '');
err = [];
try
    inputSet = Inputs.InputSet(args{:}); %#ok<NASGU>
catch caught
    err = caught;
end
[lastMessage, lastId] = lastwarn;
warnings = WarningRecorder.complete(recorder.recorded(), lastMessage, lastId);
releaseIfValid(recorder);
result = struct();
if isempty(err)
    result.error = noError();
else
    result.error = errorRecord(err);
end
result.warnings = warnings;
result.files = listFiles(scratch, scratch);
result = markScratch(result, scratch);
end

function pairs = argumentPairs(args, scratch)
% The [name, value] pairs of args as a 1xN cell of {name, value}: the name
% char, the value a char (marker replaced) or the value of a one-key
% argument. A list of pairs decodes as a cell of 2-element cells, or as an
% N-by-2 cell.
if isempty(args)
    pairs = {};
    return
end
if iscell(args) && numel(args) == 2 && ~iscell(args{1}) && ~iscell(args{2})
    % One pair, not wrapped in a list.
    items = {args};
elseif iscell(args) && all(cellfun(@iscell, args(:)))
    items = reshape(args, 1, []);
elseif iscell(args) && size(args, 2) == 2 && ismatrix(args)
    items = reshape(num2cell(args, 2), 1, []);
else
    error('References:InvalidInputFixture', 'args must be a list of [name, value] pairs');
end
pairs = cell(1, numel(items));
for k = 1:numel(items)
    item = items{k};
    if numel(item) ~= 2 || ~ischar(item{1})
        error('References:InvalidInputFixture', ...
            'Argument %d must be a [name, value] pair with a text name', k);
    end
    value = item{2};
    if ischar(value)
        % A string scalar: the input set validates the session names with
        % isStringScalar, which is false for a char row, and accepts a
        % string wherever it accepts a char (file paths, identifiers).
        value = string(markerToScratch(value, scratch));
    elseif isstruct(value)
        value = FixtureArguments.value(value);
    else
        error('References:InvalidInputFixture', ...
            'The value of argument %d must be a text or an object with one key', k);
    end
    pairs{k} = {item{1}, value};
end
end

% ----- inputsetwarnings -----

function result = inputSetWarnings(e, scratch)
args = {'sessionParentDir', scratch, 'overwriteSessionFiles', true, ...
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

result = struct();
switch char(e.capture)
    case 'console'
        guarded = @() buildInputSet(args);
        [console, err] = evalc('guarded()');
        if ~isempty(err)
            throwClean(err, scratch);
        end
        result.console = recordedText(console, scratch);
    case 'files'
        err = buildInputSet(args);
        if ~isempty(err)
            throwClean(err, scratch);
        end
        result.files = listFiles(scratch, scratch);
    otherwise
        error('References:InvalidInputFixture', 'Unknown capture %s', char(e.capture));
end
result = markScratch(result, scratch);
end

function err = buildInputSet(args)
% Build an input set; return its error instead of throwing it.
err = [];
try
    inputSet = Inputs.InputSet(args{:}); %#ok<NASGU>
catch caught
    err = caught;
end
end

% ----- helpers -----

function throwClean(err, scratch)
% Throw the error again with the scratch path replaced in its message, as in
% every recorded text; the identifier stays.
message = recordedText(err.message, scratch);
if isempty(err.identifier)
    error('%s', message);
else
    error(err.identifier, '%s', message);
end
end

function value = optionalText(v)
% A text field that may be null (jsondecode gives []): char, or [] for null.
if ischar(v) || (isstring(v) && isscalar(v))
    value = char(v);
elseif isnumeric(v) && isempty(v)
    value = [];
else
    error('References:InvalidInputFixture', 'Expected a text or null');
end
end

function s = noError()
s = struct('identifier', '', 'message', '');
end

function s = noWarnings()
s = struct('identifier', {}, 'message', {});
end

function s = errorRecord(err)
s = struct('identifier', err.identifier, 'message', err.message);
end

function w = lastWarning()
% The last warning (lastwarn) as a struct array of zero or one element.
[message, id] = lastwarn;
w = noWarnings();
if ~isempty(message) || ~isempty(id)
    w(1) = struct('identifier', id, 'message', message);
end
end

function text = markerToScratch(text, scratch)
text = strrep(text, '<scratch>', scratch);
end

function text = recordedText(text, scratch)
% The scratch path becomes <scratch>, then the path of the sandbox (the
% folder that holds the scratch folder) becomes <sandbox>.
text = strrep(text, scratch, '<scratch>');
text = strrep(text, fileparts(scratch), '<sandbox>');
end

function s = markScratch(s, scratch)
% Replace the scratch path by <scratch> in every recorded text of S (the
% messages of errors and warnings, the console, the names and texts of the
% files). The hex of a file is made from the text after the replacement.
if ischar(s)
    s = recordedText(s, scratch);
elseif isstruct(s)
    for k = 1:numel(s)
        for name = reshape(fieldnames(s), 1, [])
            s(k).(name{1}) = markScratch(s(k).(name{1}), scratch);
        end
    end
end
end

function files = listFiles(root, scratch)
% Every file and folder under ROOT (the scratch folder, or the sandbox),
% sorted by relative name; the texts have the path SCRATCH replaced.
files = struct('name', {}, 'isFolder', {}, 'text', {}, 'hex', {});
files = collectFiles(files, root, '', scratch);
if ~isempty(files)
    [~, order] = sort({files.name});
    files = files(order);
end
end

function files = collectFiles(files, root, relative, scratch)
listing = dir(fullfile(root, relative));
for k = 1:numel(listing)
    item = listing(k);
    if strcmp(item.name, '.') || strcmp(item.name, '..')
        continue
    end
    name = [relative item.name];
    entry = struct('name', name, 'isFolder', logical(item.isdir), 'text', '', 'hex', '');
    if ~item.isdir
        [entry.text, entry.hex] = fileTextAndHex(fullfile(root, name), scratch);
    end
    files(end+1) = entry; %#ok<AGROW>
    if item.isdir
        files = collectFiles(files, root, [name '/'], scratch);
    end
end
end

function [text, hex] = fileTextAndHex(file, scratch)
% The text of FILE and the lower case hex of its bytes, two digits per byte,
% both with the scratch path replaced by <scratch> (the hex is made from the
% bytes read as characters, after the replacement).
fid = fopen(file, 'r');
bytes = fread(fid, Inf, '*uint8');
fclose(fid);
text = recordedText(fileread(file), scratch);
byteText = recordedText(char(reshape(bytes, 1, [])), scratch);
if isempty(byteText)
    hex = '';
else
    digits = dec2hex(double(byteText), 2);
    hex = lower(reshape(digits.', 1, []));
end
end

function makeFolder(folder)
if ~isfolder(folder)
    mkdir(folder);
end
end

function makeFile(file, content)
fid = fopen(file, 'w');
fprintf(fid, '%s', content);
fclose(fid);
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
