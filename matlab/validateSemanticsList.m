function validateSemanticsList(entries, checkFiles)
%VALIDATESEMANTICSLIST Check a semantics-fixture manifest before any case is run.
%
%   VALIDATESEMANTICSLIST(ENTRIES, CHECKFILES) errors with identifier
%   References:InvalidSemanticsFixture on the first problem found:
%
%   - ENTRIES is not a non-empty list of entries, or an entry is not a
%     scalar struct;
%   - an entry has no name, or a name that is not sem_<family>_<nn> in full
%     (family one of semanticsKinds().families, nn at least two digits, zero
%     padded, from 01), or a name used twice;
%   - an entry's kind is missing, not text, unknown, or not a kind its family
%     allows;
%   - an entry lacks a field its kind requires or has a field its kind does
%     not use (the fields are semanticsKinds().required and .optional; there
%     is no other common field than name and kind);
%   - an mcall entry's callee is not on the allowlist (or not one its family
%     allows), its args is not a list of arguments, its nargout is not an
%     integer from 1 to 4, or its number of arguments does not fit the
%     family (maxmin1 one, maxmin2 two, maxminall three with 'all' last);
%   - an argument is not an object with exactly one key out of double,
%     logical, text, handle, strings, uint8, matrix, empty, cellstr, array,
%     or the value of the key is malformed: double and uint8 hold a list of
%     decimal strings; logical is true, false or a non-empty list of them;
%     text a string; handle a string starting with @; strings and cellstr a
%     list of strings (possibly empty); matrix {"rows": R, "double": [...]}
%     with R a positive integer that divides the number of values; empty
%     [rows, cols] with non-negative integers; array {"dims": [...],
%     "double": [...]} with at least two non-negative integer dims whose
%     product is the number of values;
%   - a sumsweep2 entry's along is not columns or rows, its lengths is not
%     a non-empty list of positive integers, or its other is not a positive
%     integer;
%   - a fluid, fluidmethods or bcfluid entry's modelFile or modelId is not a
%     non-empty text; a fluid entry's pressures, or a fluidmethods entry's
%     pressure, is not a (non-empty list of) positive finite decimal
%     string(s); a fluidmethods entry's grid is not one of the two forms
%     {"type": "anchors", "quantity", "offsets", "interior"} or
%     {"type": "shape", "quantity", "shape", "values"} with quantity
%     enthalpy or temperature, offsets a non-empty list of decimal strings,
%     interior a positive integer, shape scalar, row, column or empty and
%     values a list of decimal strings with 1, at least 1, at least 1 or 0
%     items; a bcfluid entry does not give either default (true) or all of
%     file, geometryFile and geometryId (non-empty texts);
%   - only when CHECKFILES is true: a file the entry names does not exist
%     (paths relative to the current folder), the model modelId is not in
%     the model file, or its PROPERTIES (SATURATED when the block has none)
%     is not SATURATED or PSYSTEM.
%
%   A decimal string is accepted when str2double reads it as a real number
%   (complex results are refused), or as NaN when the text is a spelling of
%   nan (any letter case). A text that str2double reads as NaN is refused
%   otherwise.
%
%   ENTRIES is a struct array, or a cell array of structs as returned by
%   jsondecode when entries have different fields.

arguments
    entries
    checkFiles (1,1) logical
end

kinds = semanticsKinds();

if iscell(entries) && ~isempty(entries)
    entries = reshape(entries, 1, []);
elseif isstruct(entries) && ~isempty(entries)
    entries = num2cell(reshape(entries, 1, []));
else
    fail('the manifest must be a non-empty list of entries');
end

names = strings(1, numel(entries));
families = strings(1, numel(entries));
for k = 1:numel(entries)
    e = entries{k};
    if ~isstruct(e) || ~isscalar(e)
        fail('entry %d is not an object', k);
    end
    if ~isfield(e, 'name')
        fail('entry %d has no name', k);
    end
    [valid, family] = parseName(e.name, kinds);
    if ~valid
        fail('entry %d has an invalid name (sem_<family>_<nn> expected)', k);
    end
    names(k) = string(e.name);
    families(k) = family;
end

[uniqueNames, ~, index] = unique(names);
counts = accumarray(index(:), 1);
if any(counts > 1)
    fail('duplicate name(s): %s', strjoin(uniqueNames(counts > 1), ', '));
end

for k = 1:numel(entries)
    checkEntry(entries{k}, names(k), families(k), kinds, checkFiles);
end

end

function checkEntry(e, name, family, kinds, checkFiles)
if ~isfield(e, 'kind') || ~isTextScalar(e.kind) || ~ismember(string(e.kind), kinds.kinds)
    fail('entry %s has a missing or unknown kind', name);
end
kind = char(e.kind);
if ~ismember(kind, kinds.familyKinds.(char(family)))
    fail('entry %s: kind %s does not belong to family %s', name, kind, family);
end
need = kinds.required.(kind);
missing = need(~isfield(e, need));
if ~isempty(missing)
    fail('entry %s is missing field(s): %s', name, strjoin(missing, ', '));
end
allowed = [{'name', 'kind'}, need];
if isfield(kinds.optional, kind)
    allowed = [allowed, kinds.optional.(kind)];
end
unknown = setdiff(fieldnames(e), allowed, 'stable');
if ~isempty(unknown)
    fail('entry %s has unknown field(s): %s', name, ...
        strjoin(reshape(unknown, 1, []), ', '));
end
switch kind
    case 'mcall'
        checkCall(e, name, family, kinds);
    case 'sumsweep2'
        checkSweep(e, name);
    case 'fluid'
        checkModel(e, name);
        checkPressures(e.pressures, name);
    case 'fluidmethods'
        checkModel(e, name);
        if ~isPositiveDecimal(e.pressure)
            fail('entry %s: pressure must be a positive decimal string', name);
        end
        checkGrid(e.grid, name);
    case 'bcfluid'
        checkModel(e, name);
        checkBoundaryConditions(e, name);
end
if checkFiles
    checkEntryFiles(e, name, kind);
end
end

function [valid, family] = parseName(v, kinds)
% sem_<family>_<nn> in full. The full-match test uses no anchors, so a
% trailing newline cannot slip past "$".
valid = false;
family = "";
if ~isTextScalar(v) || strlength(v) == 0
    return
end
text = char(v);
whole = regexp(text, 'sem_[a-z0-9]+_[0-9]+', 'match', 'once');
if ~strcmp(whole, text)
    return
end
tokens = regexp(text, '^sem_([a-z0-9]+)_([0-9]+)', 'tokens', 'once');
family = string(tokens{1});
digits = tokens{2};
number = str2double(digits);
valid = ismember(family, kinds.families) && number >= 1 ...
    && strcmp(digits, sprintf('%02d', number));
end

function checkCall(e, name, family, kinds)
callee = e.callee;
if ~isTextScalar(callee) || ~ismember(string(callee), kinds.functions)
    fail('entry %s: callee must be one of the allowlisted functions', name);
end
if ~ismember(char(callee), kinds.familyFunctions.(char(family)))
    fail('entry %s: callee %s does not belong to family %s', name, ...
        char(callee), family);
end
args = argumentList(e.args, name);
for k = 1:numel(args)
    checkArgument(args{k}, name, k, kinds);
end
n = e.nargout;
if ~(isnumeric(n) && isscalar(n) && isreal(n) && isfinite(n) && n >= 1 ...
        && n <= 4 && n == fix(n))
    fail('entry %s: nargout must be an integer from 1 to 4', name);
end
switch char(family)
    case 'maxmin1'
        count = 1;
    case 'maxmin2'
        count = 2;
    case 'maxminall'
        count = 3;
    otherwise
        count = numel(args);
end
if numel(args) ~= count
    fail('entry %s: a %s case has %d argument(s)', name, family, count);
end
if strcmp(char(family), 'maxminall')
    last = args{3};
    if ~(isfield(last, 'text') && isTextScalar(last.text) ...
            && strcmp(char(last.text), 'all'))
        fail('entry %s: a maxminall case ends with the text all', name);
    end
end
end

function list = argumentList(args, name)
% A JSON list of arguments: [] decodes as an empty double, objects with the
% same keys as a struct array, others as a cell.
if isempty(args) && (isnumeric(args) || iscell(args))
    list = {};
elseif isstruct(args)
    list = num2cell(reshape(args, 1, []));
elseif iscell(args)
    list = reshape(args, 1, []);
else
    fail('entry %s: args must be a list of arguments', name);
end
end

function checkArgument(a, name, position, kinds)
if ~isstruct(a) || ~isscalar(a) || numel(fieldnames(a)) ~= 1
    fail('entry %s: argument %d must have exactly one key', name, position);
end
key = fieldnames(a);
key = key{1};
if ~ismember(string(key), kinds.argumentKeys)
    fail('entry %s: argument %d has an unknown key %s', name, position, key);
end
value = a.(key);
switch key
    case {'double', 'uint8'}
        ok = isDecimalList(value);
    case 'logical'
        ok = islogical(value) && ~isempty(value);
    case 'text'
        ok = isTextScalar(value);
    case 'handle'
        ok = isTextScalar(value) && startsWith(char(value), '@');
    case {'strings', 'cellstr'}
        ok = isTextList(value);
    case 'matrix'
        ok = isMatrixSpec(value);
    case 'empty'
        ok = isNonNegativeIntegers(value) && numel(value) == 2;
    case 'array'
        ok = isArraySpec(value);
end
if ~ok
    fail('entry %s: argument %d: the value of %s is malformed', name, position, key);
end
end

function tf = isMatrixSpec(m)
% {"rows": R, "double": [...]}, R a positive integer that divides the count.
tf = isstruct(m) && isscalar(m) && numel(fieldnames(m)) == 2 ...
    && all(isfield(m, {'rows', 'double'})) && isDecimalList(m.double);
if ~tf
    return
end
rows = m.rows;
tf = isnumeric(rows) && isscalar(rows) && isreal(rows) && isfinite(rows) ...
    && rows >= 1 && rows == fix(rows) && mod(numel(m.double), rows) == 0;
end

function tf = isArraySpec(m)
% {"dims": [...], "double": [...]}, at least two non-negative integer dims
% whose product is the number of values.
tf = isstruct(m) && isscalar(m) && numel(fieldnames(m)) == 2 ...
    && all(isfield(m, {'dims', 'double'})) && isDecimalList(m.double);
if ~tf
    return
end
dims = m.dims;
tf = isNonNegativeIntegers(dims) && numel(dims) >= 2 && isvector(dims) ...
    && prod(dims) == numel(m.double);
end

function tf = isNonNegativeIntegers(v)
% A numeric real vector of finite non-negative integers (not logical).
tf = isnumeric(v) && isreal(v) && isvector(v) && all(isfinite(v)) ...
    && all(v >= 0) && all(v == fix(v));
end

function checkSweep(e, name)
if ~(isTextScalar(e.along) && ismember(char(e.along), {'columns', 'rows'}))
    fail('entry %s: along must be columns or rows', name);
end
lengths = e.lengths;
if ~(isnumeric(lengths) && isreal(lengths) && isvector(lengths) ...
        && ~isempty(lengths) && all(isfinite(lengths)) && all(lengths >= 1) ...
        && all(lengths == fix(lengths)))
    fail('entry %s: lengths must be a non-empty list of positive integers', name);
end
other = e.other;
if ~(isnumeric(other) && isscalar(other) && isreal(other) && isfinite(other) ...
        && other >= 1 && other == fix(other))
    fail('entry %s: other must be a positive integer', name);
end
end

function checkModel(e, name)
for field = {'modelFile', 'modelId'}
    v = e.(field{1});
    if ~isTextScalar(v) || strlength(v) == 0
        fail('entry %s: %s must be a non-empty text', name, field{1});
    end
end
end

function checkPressures(pressures, name)
if ~(iscell(pressures) && ~isempty(pressures) && all(cellfun(@isPositiveDecimal, pressures(:))))
    fail('entry %s: pressures must be a non-empty list of positive decimal strings', name);
end
end

function checkGrid(grid, name)
if ~isstruct(grid) || ~isscalar(grid)
    fail('entry %s: grid must be an object', name);
end
if ~isfield(grid, 'type') || ~isTextScalar(grid.type) ...
        || ~ismember(char(grid.type), {'anchors', 'shape'})
    fail('entry %s: grid type must be anchors or shape', name);
end
if ~isfield(grid, 'quantity') || ~isTextScalar(grid.quantity) ...
        || ~ismember(char(grid.quantity), {'enthalpy', 'temperature'})
    fail('entry %s: grid quantity must be enthalpy or temperature', name);
end
if strcmp(char(grid.type), 'anchors')
    keys = {'type', 'quantity', 'offsets', 'interior'};
    if ~isempty(setxor(fieldnames(grid), keys))
        fail('entry %s: an anchors grid has exactly type, quantity, offsets, interior', name);
    end
    if ~(isDecimalList(grid.offsets) && ~isempty(grid.offsets))
        fail('entry %s: grid offsets must be a non-empty list of decimal strings', name);
    end
    interior = grid.interior;
    if ~(isnumeric(interior) && isscalar(interior) && isreal(interior) ...
            && isfinite(interior) && interior >= 1 && interior == fix(interior))
        fail('entry %s: grid interior must be a positive integer', name);
    end
else
    keys = {'type', 'quantity', 'shape', 'values'};
    if ~isempty(setxor(fieldnames(grid), keys))
        fail('entry %s: a shape grid has exactly type, quantity, shape, values', name);
    end
    if ~(isTextScalar(grid.shape) ...
            && ismember(char(grid.shape), {'scalar', 'row', 'column', 'empty'}))
        fail('entry %s: grid shape must be scalar, row, column or empty', name);
    end
    if ~isDecimalList(grid.values)
        fail('entry %s: grid values must be a list of decimal strings', name);
    end
    count = numel(grid.values);
    switch char(grid.shape)
        case 'scalar'
            good = count == 1;
        case 'empty'
            good = count == 0;
        otherwise
            good = count >= 1;
    end
    if ~good
        fail('entry %s: a %s grid has the wrong number of values (%d)', ...
            name, char(grid.shape), count);
    end
end
end

function checkBoundaryConditions(e, name)
hasDefault = isfield(e, 'default');
hasFiles = any(isfield(e, {'file', 'geometryFile', 'geometryId'}));
if hasDefault == hasFiles
    fail('entry %s: give either default or file, geometryFile and geometryId', name);
end
if hasDefault
    if ~(islogical(e.default) && isscalar(e.default) && e.default)
        fail('entry %s: default must be true', name);
    end
else
    for field = {'file', 'geometryFile', 'geometryId'}
        if ~isfield(e, field{1}) || ~isTextScalar(e.(field{1})) ...
                || strlength(e.(field{1})) == 0
            fail('entry %s: %s must be a non-empty text', name, field{1});
        end
    end
end
end

function checkEntryFiles(e, name, kind)
% The files the entry names exist, and the model is in its file with a mode
% the fixture can run.
modelFile = char(e.modelFile);
if ~isfile(modelFile)
    fail('entry %s: %s not found', name, modelFile);
end
if strcmp(kind, 'bcfluid') && isfield(e, 'file')
    for field = {'file', 'geometryFile'}
        if ~isfile(char(e.(field{1})))
            fail('entry %s: %s not found', name, char(e.(field{1})));
        end
    end
end
[found, mode] = modelMode(fileread(modelFile), char(e.modelId));
if ~found
    fail('entry %s: model %s not found in %s', name, char(e.modelId), modelFile);
end
if ~ismember(mode, {'SATURATED', 'PSYSTEM'})
    fail('entry %s: the PROPERTIES of model %s is %s, not SATURATED or PSYSTEM', ...
        name, char(e.modelId), mode);
end
end

function [found, mode] = modelMode(text, id)
% The PROPERTIES (SATURATED when absent) of the first block of an input file
% whose ID is ID. A line is KEY ! description > value; the value runs from
% the first ">" after the "!" to the end of the line (the value pattern of
% the OpenSTREAM reader includes ">" itself), trimmed. A block ends with a
% line that is exactly END. That END handling is a simplification of the
% OpenSTREAM reader, used only to find the mode of one model; a last block
% with no END counts as a block.
found = false;
mode = '';
lines = splitlines(string(text));
blockId = '';
blockMode = 'SATURATED';
hasId = false;
for k = 1:numel(lines)
    line = char(lines(k));
    if strcmp(strtrim(line), 'END')
        if hasId && strcmp(blockId, id)
            found = true;
            mode = blockMode;
            return
        end
        blockId = '';
        blockMode = 'SATURATED';
        hasId = false;
        continue
    end
    bang = find(line == '!', 1);
    if isempty(bang)
        continue
    end
    first = bang + find(line(bang+1:end) == '>', 1);
    if isempty(first)
        continue
    end
    key = strtrim(line(1:bang-1));
    value = strtrim(line(first+1:end));
    if strcmp(key, 'ID')
        blockId = value;
        hasId = true;
    elseif strcmp(key, 'PROPERTIES')
        blockMode = value;
    end
end
if hasId && strcmp(blockId, id)
    found = true;
    mode = blockMode;
end
end

function tf = isDecimalText(t)
% A text str2double reads as a real number; NaN only for a spelling of nan.
if ~isTextScalar(t)
    tf = false;
    return
end
text = char(t);
x = str2double(text);
tf = isscalar(x) && isreal(x) && (~isnan(x) || strcmpi(text, 'nan'));
end

function tf = isDecimalList(v)
% A JSON list of decimal strings: a cell of texts, or [] for an empty list.
if isnumeric(v) && isempty(v)
    tf = true;
elseif iscell(v)
    tf = all(cellfun(@isDecimalText, reshape(v, [], 1)));
else
    tf = false;
end
end

function tf = isPositiveDecimal(t)
tf = isDecimalText(t) && isfinite(str2double(char(t))) && str2double(char(t)) > 0;
end

function tf = isTextList(v)
% A JSON list of texts: a cell of texts, or [] for an empty list.
tf = (iscell(v) && all(cellfun(@isTextScalar, reshape(v, [], 1)))) ...
    || (isnumeric(v) && isempty(v));
end

function tf = isTextScalar(v)
tf = (ischar(v) && (isrow(v) || isempty(v))) || (isstring(v) && isscalar(v));
end

function fail(varargin)
error('References:InvalidSemanticsFixture', varargin{:});
end
