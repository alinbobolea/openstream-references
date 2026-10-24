function result = runNumberCase(e)
%RUNNUMBERCASE The result of a handle, ismembertol, uint8 or sum case.
%
%   RESULT = RUNNUMBERCASE(E) converts the {"double": [...]} fields of the
%   manifest entry E with FixtureArguments.doubles and calls the function:
%
%   - handle:      f = str2func(text); a struct with fields text
%                  (func2str(f)) and value (describeValue of f(z), z a
%                  column);
%   - ismembertol: describeValue(ismembertol(a, b, tol)), a and b rows;
%   - uint8:       describeValue(uint8(values)), values a row;
%   - sum:         describeValue(sum(values)), values a row.
%
%   An error of the call is not caught here; exportInputFixture records it
%   as the case's error. Another kind errors with
%   References:InvalidInputFixture.

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
    case 'uint8'
        result = describeValue(uint8(FixtureArguments.doubles(e.values, 'row')));
    case 'sum'
        result = describeValue(sum(FixtureArguments.doubles(e.values, 'row')));
    otherwise
        error('References:InvalidInputFixture', ...
            'Case %s: no number case for kind %s', e.name, e.kind);
end

end
