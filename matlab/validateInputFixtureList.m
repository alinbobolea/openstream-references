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
%   - only when CHECKFILES is true: a file the entry names does not exist
%     (paths relative to the current folder). The case named read_missing
%     is exempt: it reads a missing file on purpose.
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
    'inputset', {{'logmode'}});
kinds = fieldnames(required);

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
    if strcmp(char(e.kind), 'inputset')
        checkInputSetShape(e, names(k));
    end
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

function paths = namedFiles(e)
% The files an entry names, as a string row (input-set pairs are checked
% before this is called).
paths = strings(1, 0);
for field = {'file', 'geometryFile'}
    if isfield(e, field{1})
        paths(end+1) = string(e.(field{1})); %#ok<AGROW>
    end
end
if strcmp(char(e.kind), 'inputset')
    for field = {'model', 'options', 'geometry'}
        if isfield(e, field{1})
            pair = e.(field{1});
            paths(end+1) = string(pair{1}); %#ok<AGROW>
        end
    end
    if isfield(e, 'bc')
        paths(end+1) = string(e.bc);
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
