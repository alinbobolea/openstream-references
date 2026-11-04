function result = runNumberCase(e)
%RUNNUMBERCASE The result of a handle, ismembertol, ismembertolsweep, uint8 or sum case.
%
%   RESULT = RUNNUMBERCASE(E) converts the {"double": [...]} fields of the
%   manifest entry E with FixtureArguments.doubles and calls the function:
%
%   - handle:           f = str2func(text); a struct with fields text
%                       (func2str(f)) and value (describeValue of f(z), z a
%                       column);
%   - ismembertol:      describeValue(ismembertol(a, b, tol)), a and b rows;
%   - ismembertolsweep: for each call {a, b, tol} of the list calls, a and b
%                       lists of decimal texts and tol a decimal text (all
%                       read with str2double; NaN, Inf and -0 are legal
%                       spellings), ismembertol(a, b, tol) with a and b
%                       rows. A struct with the field calls, a 1-by-N cell
%                       with, for each call in order, a struct with ok,
%                       errorId, errorMessage and value: describeValue of the
%                       logical result and ok true, or, when ismembertol
%                       errors, ok false, the error's identifier and
%                       message, and value []. A call that is not an object
%                       with exactly a, b and tol, or whose texts are not
%                       given as texts, errors with
%                       References:InvalidInputFixture before any call is
%                       made;
%   - uint8:            describeValue(uint8(values)), values a row;
%   - sum:              describeValue(sum(values)), values a row.
%
%   An error of the call of the other kinds is not caught here;
%   exportInputFixture records it as the case's error. Another kind errors
%   with References:InvalidInputFixture.

switch char(e.kind)
    case 'handle'
        f = str2func(char(e.text));
        v = f(FixtureArguments.doubles(e.z, 'column'));
        result = struct();
        result.text = func2str(f);
        result.value = describeValue(v);
    case 'ismembertol'
        result = describeValue(ismembertol(FixtureArguments.doubles(e.a, 'row'), ...
            FixtureArguments.doubles(e.b, 'row'), e.tol));
    case 'ismembertolsweep'
        result = sweep(e);
    case 'uint8'
        result = describeValue(uint8(FixtureArguments.doubles(e.values, 'row')));
    case 'sum'
        result = describeValue(sum(FixtureArguments.doubles(e.values, 'row')));
    otherwise
        error('References:InvalidInputFixture', ...
            'Case %s: no number case for kind %s', e.name, e.kind);
end

end

function result = sweep(e)
% Convert every call first (a malformed call errors before any call is made),
% then make the calls, each guarded on its own.
calls = FixtureArguments.list(e.calls);
converted = cell(1, numel(calls));
for k = 1:numel(calls)
    c = calls{k};
    if ~isstruct(c) || ~isscalar(c) || ~isequal(sort(fieldnames(c)), {'a'; 'b'; 'tol'})
        error('References:InvalidInputFixture', ...
            'Call %d of a sweep must be an object with exactly a, b and tol', k);
    end
    if ~((ischar(c.tol) && isrow(c.tol)) || (isstring(c.tol) && isscalar(c.tol)))
        error('References:InvalidInputFixture', 'The tol of call %d must be a text', k);
    end
    converted{k} = {FixtureArguments.textToDoubles(c.a), ...
        FixtureArguments.textToDoubles(c.b), str2double(char(c.tol))};
end
out = cell(1, numel(calls));
for k = 1:numel(calls)
    args = converted{k};
    try
        out{k} = struct('ok', true, 'errorId', '', 'errorMessage', '', ...
            'value', describeValue(ismembertol(args{1}, args{2}, args{3})));
    catch err
        out{k} = struct('ok', false, 'errorId', err.identifier, ...
            'errorMessage', err.message, 'value', []);
    end
end
result = struct('calls', {out});
end
