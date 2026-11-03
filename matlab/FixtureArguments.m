classdef FixtureArguments
    %FIXTUREARGUMENTS MATLAB values of input-fixture manifest arguments.
    %
    %   V = FIXTUREARGUMENTS.VALUE(SPEC) returns the MATLAB value of a
    %   manifest argument, an object with exactly one key:
    %
    %   - {"double": [...]}:  str2double of each text (a list of texts),
    %     as a row;
    %   - {"logical": ...}:   logical(...);
    %   - {"text": ...}:      char(...);
    %   - {"handle": ...}:    str2func(char(...));
    %   - {"strings": [...]}: a string row;
    %   - {"uint8": [...]}:   uint8 of str2double of each text, as a row;
    %   - {"matrix": {"rows": R, "double": [...]}}: str2double of each
    %     text, reshaped to R rows in column-major order, so
    %     {"rows": 2, "double": ["1", "3", "2", "4"]} is [1 2; 3 4]. R must
    %     be a positive integer that divides the number of texts;
    %   - {"empty": [R, C]}:  zeros(R, C), R and C non-negative integers
    %     ([0, 0] is the empty matrix []);
    %   - {"cellstr": [...]}: a 1xN cell of char, one per text of the list
    %     (a 1x0 cell for an empty list);
    %   - {"array": {"dims": [...], "double": [...]}}: str2double of each
    %     text, reshaped to the dims in column-major order. There must be at
    %     least two dims, non-negative integers whose product is the number
    %     of texts.
    %
    %   V = FIXTUREARGUMENTS.DOUBLES(SPEC, SHAPE) returns a {"double": [...]}
    %   argument as a row, or as a column when SHAPE is 'column'.
    %
    %   ARGS = FIXTUREARGUMENTS.PAIRS(VALUES) returns {key1, value1, key2,
    %   value2, ...} from a JSON list of [key, argument] pairs (the values
    %   of a write call).
    %
    %   ARGS = FIXTUREARGUMENTS.WRITEARGUMENTS(CLASSNAME, CALL) returns the
    %   arguments after the file name of one writeInputFile call of a write
    %   case: {id, key1, value1, ...}, or {time, pressure, hin, mflow, key1,
    %   value1, ...} for BoundaryConditions. The pairs are converted first,
    %   then time, pressure, hin and mflow in that order. Any other class
    %   errors with References:InvalidInputFixture.
    %
    %   OUT = FIXTUREARGUMENTS.LIST(X) returns a JSON list as jsondecode
    %   returns it (cell, struct array or empty) as a 1xN cell.
    %
    %   V = FIXTUREARGUMENTS.TEXTTODOUBLES(TEXTS) returns str2double of every
    %   text in TEXTS, as a row (1x0 when TEXTS is empty). TEXTS must be a
    %   JSON list of texts as jsondecode returns it: a cell of texts, or []
    %   for an empty list (the rule validateInputFixtureList applies).
    %
    %   A malformed argument errors with References:InvalidInputFixture.

    methods (Static)

        function v = value(spec)
            if ~isstruct(spec) || ~isscalar(spec) || numel(fieldnames(spec)) ~= 1
                error('References:InvalidInputFixture', ...
                    'An argument must have exactly one key');
            end
            key = fieldnames(spec);
            key = key{1};
            switch key
                case 'double'
                    v = FixtureArguments.textToDoubles(spec.double);
                case 'logical'
                    v = logical(spec.logical);
                case 'text'
                    v = char(spec.text);
                case 'handle'
                    v = str2func(char(spec.handle));
                case 'strings'
                    v = reshape(string(spec.strings), 1, []);
                case 'uint8'
                    v = uint8(FixtureArguments.textToDoubles(spec.uint8));
                case 'matrix'
                    v = FixtureArguments.matrix(spec.matrix);
                case 'empty'
                    v = FixtureArguments.emptyArray(spec.empty);
                case 'cellstr'
                    v = FixtureArguments.cellText(spec.cellstr);
                case 'array'
                    v = FixtureArguments.array(spec.array);
                otherwise
                    error('References:InvalidInputFixture', ...
                        'Unknown argument key %s', key);
            end
        end

        function v = doubles(spec, shape)
            if ~isstruct(spec) || ~isfield(spec, 'double')
                error('References:InvalidInputFixture', ...
                    'Expected a {"double": [...]} argument');
            end
            v = FixtureArguments.textToDoubles(spec.double);
            if strcmp(shape, 'column')
                v = reshape(v, [], 1);
            else
                v = reshape(v, 1, []);
            end
        end

        function out = list(x)
            if iscell(x)
                out = reshape(x, 1, []);
            elseif isstruct(x)
                out = num2cell(reshape(x, 1, []));
            elseif isempty(x)
                out = {};
            else
                out = {x};
            end
        end

        function args = pairs(values)
            pairList = FixtureArguments.asPairs(values);
            args = cell(1, 2 * numel(pairList));
            for k = 1:numel(pairList)
                pair = pairList{k};
                if ~ischar(pair{1}) || ~isstruct(pair{2})
                    error('References:InvalidInputFixture', ...
                        'Each value must be a [key, arg] pair with a text key');
                end
                args{2*k - 1} = char(pair{1});
                args{2*k} = FixtureArguments.value(pair{2});
            end
        end

        function args = writeArguments(className, call)
            values = FixtureArguments.pairs(call.values);
            switch char(className)
                case {'Model', 'Options', 'Geometry'}
                    args = [{call.id}, values];
                case 'BoundaryConditions'
                    args = [{FixtureArguments.value(call.time), ...
                        FixtureArguments.value(call.pressure), ...
                        FixtureArguments.value(call.hin), ...
                        FixtureArguments.value(call.mflow)}, values];
                otherwise
                    error('References:InvalidInputFixture', ...
                        'Unknown class %s', className);
            end
        end

        function v = textToDoubles(texts)
            isText = @(t) (ischar(t) && (isrow(t) || isempty(t))) ...
                || (isstring(t) && isscalar(t));
            if isnumeric(texts) && isempty(texts)
                v = zeros(1, 0);
            elseif iscell(texts) && all(cellfun(isText, texts(:)))
                if isempty(texts)
                    v = zeros(1, 0);
                else
                    texts = cellfun(@char, texts, 'UniformOutput', false);
                    v = reshape(str2double(texts), 1, []);
                end
            else
                error('References:InvalidInputFixture', ...
                    'Numbers must be given as a list of texts');
            end
        end

    end

    methods (Static, Access = private)

        function pairList = asPairs(values)
            % jsondecode returns a list of [key, arg] pairs as a cell of
            % 2-element cells; a single pair may come back unwrapped, and a
            % list of pairs as an N-by-2 cell. Accept all three, nothing else.
            if iscell(values) && numel(values) == 2 && ~iscell(values{1}) ...
                    && ~iscell(values{2})
                pairList = {values};
            elseif iscell(values) && all(cellfun(@(p) iscell(p) && numel(p) == 2, values(:)))
                pairList = reshape(values, 1, []);
            elseif iscell(values) && ismatrix(values) && size(values, 2) == 2
                pairList = reshape(num2cell(values, 2), 1, []);
            else
                error('References:InvalidInputFixture', ...
                    'values must be a list of [key, arg] pairs');
            end
        end

        function v = matrix(m)
            % {"rows": R, "double": [...]} as an R-row matrix, column-major.
            if ~isstruct(m) || ~isscalar(m) || numel(fieldnames(m)) ~= 2 ...
                    || ~all(isfield(m, {'rows', 'double'}))
                error('References:InvalidInputFixture', ...
                    'A matrix argument must have exactly the keys rows and double');
            end
            rows = m.rows;
            if ~isnumeric(rows) || ~isscalar(rows) || ~isreal(rows) ...
                    || ~isfinite(rows) || rows < 1 || rows ~= fix(rows)
                error('References:InvalidInputFixture', ...
                    'The rows of a matrix argument must be a positive integer');
            end
            values = FixtureArguments.textToDoubles(m.double);
            if mod(numel(values), rows) ~= 0
                error('References:InvalidInputFixture', ...
                    'The rows of a matrix argument must divide its number of values');
            end
            v = reshape(values, rows, []);
        end

        function v = emptyArray(size2)
            % {"empty": [R, C]} as zeros(R, C).
            if ~(isnumeric(size2) && isreal(size2) && isvector(size2) ...
                    && numel(size2) == 2 && all(isfinite(size2)) ...
                    && all(size2 >= 0) && all(size2 == fix(size2)))
                error('References:InvalidInputFixture', ...
                    'An empty argument must be [rows, cols], non-negative integers');
            end
            v = zeros(size2(1), size2(2));
        end

        function v = cellText(texts)
            % {"cellstr": [...]} as a 1xN cell of char; a list of texts as
            % jsondecode returns it (a cell of texts, or [] when empty).
            isText = @(t) ischar(t) && (isrow(t) || isempty(t));
            if isnumeric(texts) && isempty(texts)
                v = cell(1, 0);
            elseif iscell(texts) && all(cellfun(isText, texts(:)))
                v = reshape(texts, 1, []);
            else
                error('References:InvalidInputFixture', ...
                    'A cellstr argument must be a list of texts');
            end
        end

        function v = array(m)
            % {"dims": [...], "double": [...]} as an array of those dims,
            % column-major.
            if ~isstruct(m) || ~isscalar(m) || numel(fieldnames(m)) ~= 2 ...
                    || ~all(isfield(m, {'dims', 'double'}))
                error('References:InvalidInputFixture', ...
                    'An array argument must have exactly the keys dims and double');
            end
            dims = m.dims;
            if ~(isnumeric(dims) && isreal(dims) && isvector(dims) ...
                    && numel(dims) >= 2 && all(isfinite(dims)) ...
                    && all(dims >= 0) && all(dims == fix(dims)))
                error('References:InvalidInputFixture', ...
                    'The dims of an array argument must be two or more non-negative integers');
            end
            values = FixtureArguments.textToDoubles(m.double);
            if prod(dims) ~= numel(values)
                error('References:InvalidInputFixture', ...
                    'The dims of an array argument must multiply to its number of values');
            end
            v = reshape(values, reshape(dims, 1, []));
        end

    end

end
