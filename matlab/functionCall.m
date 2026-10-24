function call = functionCall(e)
%FUNCTIONCALL The MATLAB call made by an upper, sprintf, num2str or strcat case.
%
%   CALL = FUNCTIONCALL(E) returns, for the input-fixture manifest entry E,
%   a struct with fields:
%
%   - fn:    the function called;
%   - args:  its arguments, a 1xN cell;
%   - store: the function applied to the result before it is saved
%            (@describeValue or @toPlain).
%
%   The case's result is CALL.store(CALL.fn(CALL.args{:})). Building the
%   call runs no OpenSTREAM code (for upper with "as" textscan it runs
%   textscan). Arguments are converted by FixtureArguments.
%
%   - upper: fn @upper, store @describeValue; the one argument by "as":
%     - "char", "string": char(text), string(text);
%     - "double":   the {"double": [...]} argument "values", as a row;
%     - "uint8":    the {"uint8": [...]} argument "values" (a uint8 row);
%     - "textscan": the first cell of textscan(string(text), '%f').
%   - sprintf: fn @sprintf; the format (char, or a string when
%     "formatClass" is "string"), then each argument of "args"; store
%     @toPlain, or @describeValue when formatClass is "string".
%   - num2str: fn @num2str. The value is "values", either
%     {"double": [...]} as a row (a column when "shape" is "column"; uint8
%     of it when "valuesClass" is "uint8"), or {"text": ...} as char (a
%     string when valuesClass is "string"; only with an empty format).
%     The arguments are the value alone when "format" is empty, else the
%     value and the format (char, or a string when formatClass is
%     "string"). Store @toPlain, or @describeValue when formatClass or
%     valuesClass is "string", since toPlain turns a string into char.
%   - strcat: fn @strcat, the arguments of "args" (none when args is
%     empty), store @describeValue.
%
%   A field missing or outside these rules errors with
%   References:InvalidInputFixture.

switch char(e.kind)
    case 'upper'
        call = makeCall(@upper, {upperArgument(e)}, @describeValue);
    case 'sprintf'
        [fmt, isString] = formatOf(e);
        call = makeCall(@sprintf, [{fmt}, argumentList(e.args)], storeFor(isString));
    case 'num2str'
        call = num2strCall(e);
    case 'strcat'
        call = makeCall(@strcat, argumentList(e.args), @describeValue);
    otherwise
        fail('Case %s: no function call for kind %s', e.name, e.kind);
end

end

function call = makeCall(fn, args, store)
call = struct();
call.fn = fn;
call.args = args;
call.store = store;
end

function v = upperArgument(e)
switch char(e.as)
    case 'char'
        v = char(e.text);
    case 'string'
        v = string(e.text);
    case 'double'
        requireField(e, 'values');
        v = FixtureArguments.doubles(e.values, 'row');
    case 'uint8'
        requireField(e, 'values');
        if ~isstruct(e.values) || ~isfield(e.values, 'uint8')
            fail('Case %s: "values" must be a {"uint8": [...]} argument', e.name);
        end
        v = FixtureArguments.value(e.values);
    case 'textscan'
        scanned = textscan(string(e.text), '%f');
        v = scanned{1};
    otherwise
        fail('Case %s: "as" must be char, string, double, uint8 or textscan', e.name);
end
end

function call = num2strCall(e)
values = e.values;
if ~isstruct(values) || ~isscalar(values) || numel(fieldnames(values)) ~= 1
    fail('Case %s: "values" must have exactly one key', e.name);
end
valuesClass = optionalText(e, 'valuesClass');
shape = optionalText(e, 'shape');
emptyFormat = isempty(char(e.format));
isString = false;
if isfield(values, 'double')
    if isempty(shape)
        shape = 'row';
    elseif ~ismember(shape, {'row', 'column'})
        fail('Case %s: "shape" must be row or column', e.name);
    end
    v = FixtureArguments.doubles(values, shape);
    if strcmp(valuesClass, 'uint8')
        v = uint8(v);
    elseif ~isempty(valuesClass)
        fail('Case %s: "valuesClass" must be uint8 for double values', e.name);
    end
elseif isfield(values, 'text')
    if ~isempty(shape)
        fail('Case %s: "shape" applies to double values only', e.name);
    end
    if ~emptyFormat
        fail('Case %s: text values need an empty format', e.name);
    end
    if strcmp(valuesClass, 'string')
        v = string(values.text);
        isString = true;
    elseif isempty(valuesClass)
        v = char(values.text);
    else
        fail('Case %s: "valuesClass" must be string for text values', e.name);
    end
else
    fail('Case %s: "values" must be a double or a text argument', e.name);
end
if emptyFormat
    if isfield(e, 'formatClass')
        fail('Case %s: "formatClass" needs a format', e.name);
    end
    args = {v};
else
    [fmt, formatIsString] = formatOf(e);
    isString = isString || formatIsString;
    args = {v, fmt};
end
call = makeCall(@num2str, args, storeFor(isString));
end

function [fmt, isString] = formatOf(e)
% The format as char, or as a string when formatClass is "string".
formatClass = optionalText(e, 'formatClass');
if strcmp(formatClass, 'string')
    fmt = string(e.format);
    isString = true;
elseif isempty(formatClass)
    fmt = char(e.format);
    isString = false;
else
    fail('Case %s: "formatClass" must be string', e.name);
end
end

function store = storeFor(isString)
% describeValue keeps the class of a string result, which toPlain drops.
if isString
    store = @describeValue;
else
    store = @toPlain;
end
end

function args = argumentList(specs)
% The MATLAB values of a JSON list of arguments, as a 1xN cell.
args = cellfun(@FixtureArguments.value, FixtureArguments.list(specs), ...
    'UniformOutput', false);
args = reshape(args, 1, []);
end

function text = optionalText(e, field)
% The text of an optional field ('' when absent).
text = '';
if isfield(e, field)
    value = e.(field);
    if ~((ischar(value) && isrow(value)) || (isstring(value) && isscalar(value)))
        fail('Case %s: "%s" must be text', e.name, field);
    end
    text = char(value);
end
end

function requireField(e, field)
if ~isfield(e, field)
    fail('Case %s: missing field "%s"', e.name, field);
end
end

function fail(varargin)
error('References:InvalidInputFixture', varargin{:});
end
