function validateInputFixtureList(entries, checkFiles)
%VALIDATEINPUTFIXTURELIST Check an input-fixture manifest before any case is run.
%
%   VALIDATEINPUTFIXTURELIST(ENTRIES, CHECKFILES) errors with identifier
%   References:InvalidInputFixture on the first problem found:
%
%   - ENTRIES is not a list of entries, or an entry is not a scalar struct;
%   - an entry has no name, or a name that is not text matching
%     [A-Za-z][A-Za-z0-9_]* in full, or a name used twice;
%   - an entry's kind is missing, not text, or unknown;
%   - an entry lacks a field its kind requires;
%   - an inputset entry gives model, options or geometry other than as a
%     [file, id] pair of texts, or bc other than as a text;
%   - a sprintf or strcat entry's args is not a list of arguments with
%     exactly one known key each (double, logical, text, handle, strings,
%     uint8, matrix); a double or uint8 argument is not a list of texts; a
%     handle entry's z, an ismembertol entry's a or b, or a uint8 or sum
%     entry's values is not {"double": [...]}, a list of texts; a matrix
%     argument is not {"rows": R, "double": [...]} with R a positive
%     integer that divides the number of texts;
%   - an upper entry's "as" is not char, string, double, uint8 or
%     textscan; as double or uint8 without "values" given as
%     {"double": [...]} or {"uint8": [...]} (a list of texts); "values"
%     with any other "as";
%   - a num2str entry's format is not text; its values are not
%     {"double": [...]} (a list of texts) or {"text": ...} (a text, with
%     an empty format only); "valuesClass" other than uint8 for double
%     values or string for text values; "shape" other than row or column,
%     or with text values; "formatClass" with an empty format;
%   - a logcalls entry's logmode is not NONE, LOGTOFILEONLY, LOGTOCONSOLEONLY,
%     BOTH or null, its sessionName is not a text or null, or its calls is
%     not [] or a list of objects with exactly the keys op (log, warning,
%     openLog, openLogKeep, closeLog, readLog, readLogFilePath or
%     removeFolder) and args (a list of texts and one-key arguments, as for
%     sprintf, so that a number is a text);
%   - a sessionfs entry's logmode is not one of the four, dirName not a text,
%     overwrite not true or false, before not absent, folder, folderWithFile,
%     file or ownLogOpen, or parent not exists, missing, file or empty;
%   - an inputsetcall entry's logmode is not one of the four, or its args is
%     not a list of [name, value] pairs, the name a text and the value a text
%     or a one-key argument;
%   - an inputsetwarnings entry's logmode is not one of the four, its capture
%     is not console or files, or its model, options, geometry or bc is not
%     given as for inputset;
%   - an ismembertolsweep entry's calls is not a non-empty list of objects
%     with exactly the keys a, b (lists of decimal texts) and tol (a decimal
%     text); a decimal text is one that str2double reads as a number, or the
%     spelling NaN;
%   - an entry has a field its kind does not use. Besides name, kind,
%     exporterChange (a description only) and its required fields, a kind
%     may have only: upper values; sprintf formatClass; num2str shape,
%     valuesClass and formatClass; inputset and inputsetwarnings model,
%     options, geometry, bc;
%   - "formatClass" other than string;
%   - a default, listprops or write entry's class is not Model, Options,
%     Geometry or BoundaryConditions;
%   - a write entry's calls is not a non-empty list of objects, or a call
%     lacks or adds a key: id and values for Model, Options and Geometry;
%     time, pressure, hin, mflow and values for BoundaryConditions; a call
%     may also have mode, the fopen mode: w, a, r+ or a+;
%   - an ismembertol entry's tol is not a real numeric scalar;
%   - a sumsweep entry's lengths is not a non-empty list of positive
%     integers;
%   - only when CHECKFILES is true: a file the entry names does not exist
%     (paths relative to the current folder). The files an entry names are
%     those of its file, geometryFile, model, options, geometry and bc fields
%     (model, options, geometry and bc for the kinds inputset and
%     inputsetwarnings), and, for inputsetcall, the values of the arguments
%     modelFilePath, optionsFilePath, geometryFilePath and bcFilePath unless
%     the value is empty or holds the text <scratch>. The case named
%     read_missing is exempt: it reads a missing file on purpose.
%
%   ENTRIES is a struct array, or a cell array of structs as returned by
%   jsondecode when entries have different fields.

arguments
    entries
    checkFiles (1,1) logical
end

if iscell(entries) && ~isempty(entries)
    entries = reshape(entries, 1, []);
elseif isstruct(entries) && ~isempty(entries)
    entries = num2cell(reshape(entries, 1, []));
else
    fail('the manifest must be a non-empty list of entries');
end

required = struct( ...
    'read', {{'file'}}, ...
    'convert2json', {{'file'}}, ...
    'model', {{'file', 'id'}}, ...
    'options', {{'file', 'id'}}, ...
    'geometry', {{'file', 'id'}}, ...
    'bc', {{'file', 'geometryFile', 'geometryId'}}, ...
    'default', {{'class'}}, ...
    'listprops', {{'class'}}, ...
    'write', {{'class', 'calls'}}, ...
    'handle', {{'text', 'z'}}, ...
    'textscan', {{'text'}}, ...
    'upper', {{'text', 'as'}}, ...
    'sprintf', {{'format', 'args'}}, ...
    'num2str', {{'values', 'format'}}, ...
    'readlines', {{'file'}}, ...
    'ismembertol', {{'a', 'b', 'tol'}}, ...
    'uint8', {{'values'}}, ...
    'sum', {{'values'}}, ...
    'sumsweep', {{'lengths'}}, ...
    'legalpath', {{'path'}}, ...
    'inputset', {{'logmode'}}, ...
    'strcat', {{'args'}}, ...
    'logcalls', {{'logmode', 'sessionName', 'calls'}}, ...
    'sessionfs', {{'logmode', 'dirName', 'overwrite', 'before', 'parent'}}, ...
    'inputsetcall', {{'logmode', 'args'}}, ...
    'inputsetwarnings', {{'logmode', 'capture'}}, ...
    'ismembertolsweep', {{'calls'}});
kinds = fieldnames(required);
% Fields a kind may have besides its required ones. Every entry may also
% have name, kind and exporterChange (a text describing the form of call
% the entry needs; the scripts ignore it).
optional = struct('upper', {{'values'}}, ...
    'sprintf', {{'formatClass'}}, ...
    'num2str', {{'shape', 'valuesClass', 'formatClass'}}, ...
    'inputset', {{'model', 'options', 'geometry', 'bc'}}, ...
    'inputsetwarnings', {{'model', 'options', 'geometry', 'bc'}});
common = {'name', 'kind', 'exporterChange'};
logModes = {'NONE', 'LOGTOFILEONLY', 'LOGTOCONSOLEONLY', 'BOTH'};

names = strings(1, numel(entries));
for k = 1:numel(entries)
    e = entries{k};
    if ~isstruct(e) || ~isscalar(e)
        fail('entry %d is not an object', k);
    end
    if ~isfield(e, 'name')
        fail('entry %d has no name', k);
    end
    if ~isValidName(e.name)
        fail('entry %d has an invalid name', k);
    end
    names(k) = string(e.name);
    if ~isfield(e, 'kind') || ~isTextScalar(e.kind) || ~ismember(char(e.kind), kinds)
        fail('entry %s has a missing or unknown kind', names(k));
    end
    need = required.(char(e.kind));
    missing = need(~isfield(e, need));
    if ~isempty(missing)
        fail('entry %s is missing field(s): %s', names(k), strjoin(missing, ', '));
    end
    allowed = [common, need];
    if isfield(optional, char(e.kind))
        allowed = [allowed, optional.(char(e.kind))];
    end
    unknown = setdiff(fieldnames(e), allowed, 'stable');
    if ~isempty(unknown)
        fail('entry %s has unknown field(s): %s', names(k), ...
            strjoin(reshape(unknown, 1, []), ', '));
    end
    switch char(e.kind)
        case 'inputset'
            checkInputSetShape(e, names(k));
        case 'inputsetwarnings'
            checkChoice(e, 'logmode', logModes, names(k));
            checkChoice(e, 'capture', {'console', 'files'}, names(k));
            checkInputSetShape(e, names(k));
        case 'logcalls'
            checkLogcalls(e, logModes, names(k));
        case 'sessionfs'
            checkChoice(e, 'logmode', logModes, names(k));
            if ~isTextScalar(e.dirName)
                fail('entry %s: dirName must be text', names(k));
            end
            if ~(islogical(e.overwrite) && isscalar(e.overwrite))
                fail('entry %s: overwrite must be true or false', names(k));
            end
            checkChoice(e, 'before', ...
                {'absent', 'folder', 'folderWithFile', 'file', 'ownLogOpen'}, names(k));
            checkChoice(e, 'parent', {'exists', 'missing', 'file', 'empty'}, names(k));
        case 'inputsetcall'
            checkChoice(e, 'logmode', logModes, names(k));
            checkCallArguments(e.args, names(k));
        case 'ismembertolsweep'
            checkSweepCalls(e.calls, names(k));
        case {'default', 'listprops', 'write'}
            if ~isOneOf(e.class, {'Model', 'Options', 'Geometry', 'BoundaryConditions'})
                fail(['entry %s: class must be Model, Options, Geometry or ' ...
                    'BoundaryConditions'], names(k));
            end
            if strcmp(char(e.kind), 'write')
                checkWriteCalls(e, names(k));
            end
        case 'sumsweep'
            checkLengths(e.lengths, names(k));
        case {'sprintf', 'strcat'}
            checkArguments(e.args, names(k));
        case 'upper'
            checkUpper(e, names(k));
        case 'num2str'
            checkNum2str(e, names(k));
        case {'handle', 'ismembertol', 'uint8', 'sum'}
            checkNumberLists(e, names(k));
            if strcmp(char(e.kind), 'ismembertol') && ~(isnumeric(e.tol) ...
                    && isscalar(e.tol) && isreal(e.tol))
                fail('entry %s: tol must be a number', names(k));
            end
    end
    checkFormatClass(e, names(k));
end

[uniqueNames, ~, index] = unique(names);
counts = accumarray(index(:), 1);
if any(counts > 1)
    fail('duplicate name(s): %s', strjoin(uniqueNames(counts > 1), ', '));
end

if ~checkFiles
    return
end
for k = 1:numel(entries)
    if names(k) == "read_missing"
        continue
    end
    for file = namedFiles(entries{k})
        if ~isfile(file)
            fail('entry %s: %s not found', names(k), file);
        end
    end
end

end

function checkInputSetShape(e, name)
for field = {'model', 'options', 'geometry'}
    if isfield(e, field{1}) && ~isPair(e.(field{1}))
        fail('entry %s: %s must be a [file, id] pair', name, field{1});
    end
end
if isfield(e, 'bc') && ~isTextScalar(e.bc)
    fail('entry %s: bc must be a file name', name);
end
end

function checkArguments(args, name)
% A JSON list of arguments: [] decodes as an empty double, objects with the
% same keys as a struct array, others as a cell.
if isempty(args) && (isnumeric(args) || iscell(args))
    return
elseif isstruct(args)
    list = num2cell(reshape(args, 1, []));
elseif iscell(args)
    list = reshape(args, 1, []);
else
    fail('entry %s: args must be a list of arguments', name);
end
for k = 1:numel(list)
    checkOneArgument(list{k}, name, k);
end
end

function checkOneArgument(a, name, k)
% One argument: an object with exactly one known key.
if ~isstruct(a) || ~isscalar(a) || numel(fieldnames(a)) ~= 1
    fail('entry %s: argument %d must have exactly one key', name, k);
end
key = fieldnames(a);
key = key{1};
switch key
    case {'logical', 'text', 'handle', 'strings'}
    case {'double', 'uint8'}
        if ~isTextList(a.(key))
            fail('entry %s: argument %d: %s must be a list of texts', name, k, key);
        end
    case 'matrix'
        if ~isMatrixSpec(a.matrix)
            fail(['entry %s: argument %d: matrix must be {"rows": R, ' ...
                '"double": [...]} with R a positive integer dividing ' ...
                'the number of texts'], name, k);
        end
    otherwise
        fail('entry %s: argument %d has an unknown key %s', name, k, key);
end
end

function checkChoice(e, field, allowed, name)
% The field of the entry is one of the texts ALLOWED.
if ~isOneOf(e.(field), allowed)
    fail('entry %s: %s must be %s', name, field, strjoin(allowed, ', '));
end
end

function checkLogcalls(e, logModes, name)
% logmode: a log mode or null (jsondecode: []); sessionName: a text or null;
% calls: no calls ([]) or a list of objects with exactly the keys op and
% args, op one of the eight operations, args a list of texts and arguments.
if ~(isnumeric(e.logmode) && isempty(e.logmode)) && ~isOneOf(e.logmode, logModes)
    fail('entry %s: logmode must be %s or null', name, strjoin(logModes, ', '));
end
if ~(isnumeric(e.sessionName) && isempty(e.sessionName)) && ~isTextScalar(e.sessionName)
    fail('entry %s: sessionName must be text or null', name);
end
calls = e.calls;
if isnumeric(calls) && isempty(calls)
    return
end
list = objectList(calls);
if isempty(list)
    fail('entry %s: calls must be a list of objects', name);
end
ops = {'log', 'warning', 'openLog', 'openLogKeep', 'closeLog', 'readLog', ...
    'readLogFilePath', 'removeFolder'};
for k = 1:numel(list)
    c = list{k};
    if ~isstruct(c) || ~isscalar(c)
        fail('entry %s: call %d is not an object', name, k);
    end
    need = {'op', 'args'};
    missing = need(~isfield(c, need));
    if ~isempty(missing)
        fail('entry %s: call %d is missing key(s): %s', name, k, strjoin(missing, ', '));
    end
    unknown = setdiff(fieldnames(c), need, 'stable');
    if ~isempty(unknown)
        fail('entry %s: call %d has unknown key(s): %s', name, k, ...
            strjoin(reshape(unknown, 1, []), ', '));
    end
    if ~isOneOf(c.op, ops)
        fail('entry %s: call %d: op must be %s', name, k, strjoin(ops, ', '));
    end
    checkLogArguments(c.args, name, k);
end
end

function list = objectList(x)
% A JSON list of objects as a 1xN cell: a struct array, or a cell; {} for
% anything else (and for an empty list).
if isstruct(x) && ~isempty(x)
    list = num2cell(reshape(x, 1, []));
elseif iscell(x) && ~isempty(x)
    list = reshape(x, 1, []);
else
    list = {};
end
end

function checkLogArguments(args, name, k)
% The args of a log call: [] or a list whose items are texts or objects with
% one known key.
if (isnumeric(args) || iscell(args)) && isempty(args)
    return
elseif isstruct(args)
    list = num2cell(reshape(args, 1, []));
elseif iscell(args)
    list = reshape(args, 1, []);
else
    fail('entry %s: call %d: args must be a list', name, k);
end
for j = 1:numel(list)
    if ~isTextScalar(list{j})
        checkOneArgument(list{j}, name, j);
    end
end
end

function pairs = argumentPairs(args)
% The [name, value] pairs of an inputsetcall args as a 1xN cell of 1x2
% cells, or {} for an empty list; a list of pairs decodes as a cell of
% 2-element cells or as an N-by-2 cell, and a single pair may come back
% unwrapped, as the 2-element cell {name; value} (the shapes FixtureArguments
% accepts for the pairs of a write call). Anything else gives [].
if (isnumeric(args) || iscell(args)) && isempty(args)
    pairs = {};
elseif iscell(args) && numel(args) == 2 && ~iscell(args{1}) && ~iscell(args{2})
    pairs = {args};
elseif iscell(args) && all(cellfun(@iscell, args(:)))
    pairs = reshape(args, 1, []);
elseif iscell(args) && ismatrix(args) && size(args, 2) == 2
    pairs = reshape(num2cell(args, 2), 1, []);
else
    pairs = [];
end
end

function checkCallArguments(args, name)
% The args of an inputsetcall entry: a list of [name, value] pairs, the
% name a text, the value a text or an object with one known key.
pairs = argumentPairs(args);
if ~iscell(pairs)
    fail('entry %s: args must be a list of [name, value] pairs', name);
end
for k = 1:numel(pairs)
    p = pairs{k};
    if numel(p) ~= 2 || ~isTextScalar(p{1})
        fail('entry %s: args item %d must be a [name, value] pair', name, k);
    end
    if ~isTextScalar(p{2})
        checkOneArgument(p{2}, name, k);
    end
end
end

function checkSweepCalls(calls, name)
% The calls of an ismembertolsweep entry: a non-empty list of objects with
% exactly the keys a, b and tol; a and b lists of decimal texts, tol one
% decimal text.
list = objectList(calls);
if isempty(list)
    fail('entry %s: calls must be a non-empty list of objects', name);
end
need = {'a', 'b', 'tol'};
for k = 1:numel(list)
    c = list{k};
    if ~isstruct(c) || ~isscalar(c)
        fail('entry %s: call %d is not an object', name, k);
    end
    missing = need(~isfield(c, need));
    if ~isempty(missing)
        fail('entry %s: call %d is missing key(s): %s', name, k, strjoin(missing, ', '));
    end
    unknown = setdiff(fieldnames(c), need, 'stable');
    if ~isempty(unknown)
        fail('entry %s: call %d has unknown key(s): %s', name, k, ...
            strjoin(reshape(unknown, 1, []), ', '));
    end
    for field = {'a', 'b'}
        texts = c.(field{1});
        if ~isTextList(texts) || (iscell(texts) && ~all(cellfun(@isDecimal, texts(:))))
            fail('entry %s: call %d: %s must be a list of decimal texts', ...
                name, k, field{1});
        end
    end
    if ~isDecimal(c.tol)
        fail('entry %s: call %d: tol must be a decimal text', name, k);
    end
end
end

function tf = isDecimal(v)
% A text that reads as a number: str2double of it is not NaN, or it is the
% spelling NaN.
tf = isTextScalar(v) && (strcmp(char(v), 'NaN') || ~isnan(str2double(char(v))));
end

function checkUpper(e, name)
if ~isOneOf(e.as, {'char', 'string', 'double', 'uint8', 'textscan'})
    fail('entry %s: as must be char, string, double, uint8 or textscan', name);
end
as = char(e.as);
switch as
    case {'double', 'uint8'}
        if ~isfield(e, 'values') || ~isListArgument(e.values, as)
            fail('entry %s: values must be {"%s": [...]}, a list of texts', name, as);
        end
    otherwise
        if isfield(e, 'values')
            fail('entry %s: values applies only when as is double or uint8', name);
        end
end
end

function checkNum2str(e, name)
if ~isTextScalar(e.format)
    fail('entry %s: format must be text', name);
end
emptyFormat = strlength(e.format) == 0;
if isListArgument(e.values, 'double')
    if isfield(e, 'valuesClass') && ~isOneOf(e.valuesClass, {'uint8'})
        fail('entry %s: valuesClass must be uint8 for double values', name);
    end
    if isfield(e, 'shape') && ~isOneOf(e.shape, {'row', 'column'})
        fail('entry %s: shape must be row or column', name);
    end
elseif isOneKey(e.values, 'text') && isTextScalar(e.values.text)
    if ~emptyFormat
        fail('entry %s: text values need an empty format', name);
    end
    if isfield(e, 'valuesClass') && ~isOneOf(e.valuesClass, {'string'})
        fail('entry %s: valuesClass must be string for text values', name);
    end
    if isfield(e, 'shape')
        fail('entry %s: shape applies to double values only', name);
    end
else
    fail('entry %s: values must be {"double": [...]} or {"text": ...}', name);
end
if emptyFormat && isfield(e, 'formatClass')
    fail('entry %s: formatClass needs a format', name);
end
end

function checkWriteCalls(e, name)
% The calls of a write entry: a non-empty list of objects, each with
% exactly the keys FixtureArguments.writeArguments reads for the class.
calls = e.calls;
if isstruct(calls) && ~isempty(calls)
    list = num2cell(reshape(calls, 1, []));
elseif iscell(calls) && ~isempty(calls)
    list = reshape(calls, 1, []);
else
    fail('entry %s: calls must be a non-empty list of objects', name);
end
if strcmp(char(e.class), 'BoundaryConditions')
    keys = {'time', 'pressure', 'hin', 'mflow', 'values'};
else
    keys = {'id', 'values'};
end
for k = 1:numel(list)
    c = list{k};
    if ~isstruct(c) || ~isscalar(c)
        fail('entry %s: call %d is not an object', name, k);
    end
    missing = keys(~isfield(c, keys));
    if ~isempty(missing)
        fail('entry %s: call %d is missing key(s): %s', name, k, strjoin(missing, ', '));
    end
    unknown = setdiff(fieldnames(c), [keys, {'mode'}], 'stable');
    if ~isempty(unknown)
        fail('entry %s: call %d has unknown key(s): %s', name, k, ...
            strjoin(reshape(unknown, 1, []), ', '));
    end
    if isfield(c, 'mode') && ~isOneOf(c.mode, {'w', 'a', 'r+', 'a+'})
        fail('entry %s: call %d: mode must be w, a, r+ or a+', name, k);
    end
end
end

function checkLengths(lengths, name)
% The lengths of a sumsweep entry: a non-empty list of positive integers
% (each is an index of the sums).
% isvector is true for a 1x0 or 0x1 value, so emptiness is checked too.
if ~(isnumeric(lengths) && isreal(lengths) && isvector(lengths) ...
        && ~isempty(lengths) && all(isfinite(lengths)) && all(lengths >= 1) ...
        && all(lengths == fix(lengths)))
    fail('entry %s: lengths must be a non-empty list of positive integers', name);
end
end

function checkNumberLists(e, name)
% The number fields of the handle, ismembertol, uint8 and sum kinds.
fields = struct('handle', {{'z'}}, 'ismembertol', {{'a', 'b'}}, ...
    'uint8', {{'values'}}, 'sum', {{'values'}});
for field = fields.(char(e.kind))
    if ~isListArgument(e.(field{1}), 'double')
        fail('entry %s: %s must be {"double": [...]}, a list of texts', ...
            name, field{1});
    end
end
end

function checkFormatClass(e, name)
% Only sprintf and num2str entries get here with a formatClass (the
% allowed-field table rejects it on other kinds).
if isfield(e, 'formatClass') && ~isOneOf(e.formatClass, {'string'})
    fail('entry %s: formatClass must be string', name);
end
end

function tf = isListArgument(v, key)
% {"KEY": [...]}, a list of texts, and nothing else.
tf = isOneKey(v, key) && isTextList(v.(key));
end

function tf = isOneKey(v, key)
tf = isstruct(v) && isscalar(v) && numel(fieldnames(v)) == 1 && isfield(v, key);
end

function tf = isTextList(v)
% A JSON list of texts: a cell of texts, or [] for an empty list.
tf = (iscell(v) && all(cellfun(@isTextScalar, v(:)))) || (isnumeric(v) && isempty(v));
end

function tf = isMatrixSpec(m)
tf = isstruct(m) && isscalar(m) && numel(fieldnames(m)) == 2 ...
    && all(isfield(m, {'rows', 'double'})) && isTextList(m.double);
if ~tf
    return
end
rows = m.rows;
tf = isnumeric(rows) && isscalar(rows) && isreal(rows) && isfinite(rows) ...
    && rows >= 1 && rows == fix(rows) && mod(numel(m.double), rows) == 0;
end

function tf = isOneOf(v, allowed)
tf = isTextScalar(v) && ismember(char(v), allowed);
end

function paths = namedFiles(e)
% The files an entry names, as a string row (input-set pairs are checked
% before this is called).
paths = strings(1, 0);
for field = {'file', 'geometryFile'}
    if isfield(e, field{1})
        paths(end+1) = string(e.(field{1})); %#ok<AGROW>
    end
end
if any(strcmp(char(e.kind), {'inputset', 'inputsetwarnings'}))
    for field = {'model', 'options', 'geometry'}
        if isfield(e, field{1})
            pair = e.(field{1});
            paths(end+1) = string(pair{1}); %#ok<AGROW>
        end
    end
    if isfield(e, 'bc')
        paths(end+1) = string(e.bc);
    end
elseif strcmp(char(e.kind), 'inputsetcall')
    % The file arguments, unless empty or holding the scratch marker.
    pairs = argumentPairs(e.args);
    for k = 1:numel(pairs)
        p = pairs{k};
        if isTextScalar(p{2}) ...
                && ismember(char(p{1}), {'modelFilePath', 'optionsFilePath', ...
                'geometryFilePath', 'bcFilePath'}) ...
                && strlength(p{2}) > 0 && ~contains(char(p{2}), '<scratch>')
            paths(end+1) = string(p{2}); %#ok<AGROW>
        end
    end
end
end

function tf = isPair(v)
tf = iscell(v) && numel(v) == 2 && isTextScalar(v{1}) && isTextScalar(v{2});
end

function tf = isValidName(v)
% Text matching [A-Za-z][A-Za-z0-9_]* in full (no anchors, so a trailing
% newline cannot slip past "$").
tf = isTextScalar(v) && strlength(v) > 0 && ...
    strcmp(regexp(char(v), '[A-Za-z][A-Za-z0-9_]*', 'match', 'once'), char(v));
end

function tf = isTextScalar(v)
tf = (ischar(v) && (isrow(v) || isempty(v))) || (isstring(v) && isscalar(v));
end

function fail(varargin)
error('References:InvalidInputFixture', varargin{:});
end
