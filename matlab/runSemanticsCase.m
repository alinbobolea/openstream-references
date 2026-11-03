function result = runSemanticsCase(e)
%RUNSEMANTICSCASE The result of one case of the semantics fixture.
%
%   RESULT = RUNSEMANTICSCASE(E) runs the case E (a scalar struct as
%   jsondecode returns a manifest entry, valid by validateSemanticsList) and
%   returns what it records. An error of the call itself is not caught here;
%   exportSemanticsFixture records it as the case's error. By kind:
%
%   - mcall:        a struct with the field outputs, a 1-by-nargout cell of
%                   describeValue of each output of FEVAL(callee, args{:})
%                   called with nargout outputs (the arguments are converted
%                   by FixtureArguments);
%   - sumsweep2:    a struct with the fields lengths (the row of lengths) and
%                   sums (a cell, one describeValue per length). For a length
%                   n, v(k) = 0.1*k for k = 1..n with v(k) = 1e16 where
%                   mod(k,5) == 1 and -1e16 where mod(k,5) == 2; "columns"
%                   sums the n-by-other matrix whose column j is v*j with
%                   sum(A, 1); "rows" sums its transpose with sum(A, 2);
%   - fluid:        a 1-by-N cell, one struct per pressure, whose fields are
%                   the stored properties of Inputs.FluidProperties (FLUID,
%                   PROPERTIES, PRESSURE, TSAT ... QKMAX, hidden ones
%                   included, not coolpropH), each through describeValue;
%   - fluidmethods: a struct with the fields quantity, grid (describeValue
%                   of the grid used, see below) and methods, a struct with one
%                   field per method applied to the grid, each a struct with
%                   ok, errorId, errorMessage and value (describeValue of the
%                   result). An enthalpy grid is given to T and to RHOL RHOV
%                   MUL MUV KL KV CPL CPV ALPHAL ALPHAV PRANDTLL PRANDTLV; a
%                   temperature grid to H. Each method is guarded on its own;
%   - bcfluid:      a struct with the fields pressures (describeValue of the
%                   row of pressures of the boundary-condition objects),
%                   fluidCount (the number of fluid objects built from them)
%                   and objects, a 1-by-N cell with, for each boundary-condition
%                   object k, a struct whose fields TSAT HF HG TIN DTIN DHIN XIN
%                   are guarded like the methods above (the call is
%                   OBJECT.MEMBER(FLUIDS(k))).
%
%   The grid of a fluidmethods case with type anchors is the sorted row of
%   unique values made of every anchor (HMIN HF HG HMAX of the fluid object at
%   the case pressure for an enthalpy grid, TMIN TMAX for a temperature grid)
%   shifted by every offset, and, between each two consecutive unshifted
%   anchors a and b, the "interior" points a + (b-a)*(1:n)/(n+1). With type
%   shape the values are used as given: one value as a scalar, a row, a
%   column, or zeros(0,0).
%
%   Models are built with Inputs.Model(modelFile, modelId); the fluid objects
%   with Inputs.FluidProperties(P, model) as the solvers build them. These
%   kinds need OpenSTREAM on the path. Any other kind errors with
%   References:InvalidSemanticsFixture.

if ~isstruct(e) || ~isscalar(e) || ~isfield(e, 'kind')
    error('References:InvalidSemanticsFixture', 'A case must be an object with a kind');
end
kind = char(e.kind);
switch kind
    case 'mcall'
        result = callResult(e);
    case 'sumsweep2'
        result = sweepResult(e);
    case 'fluid'
        result = fluidResult(e);
    case 'fluidmethods'
        result = methodsResult(e);
    case 'bcfluid'
        result = boundaryResult(e);
    otherwise
        error('References:InvalidSemanticsFixture', 'Unknown kind %s', kind);
end

end

function result = callResult(e)
args = FixtureArguments.list(e.args);
values = cell(1, numel(args));
for k = 1:numel(args)
    values{k} = FixtureArguments.value(args{k});
end
outputs = cell(1, e.nargout);
[outputs{:}] = feval(char(e.callee), values{:});
described = cell(1, numel(outputs));
for k = 1:numel(outputs)
    described{k} = describeValue(outputs{k});
end
result = struct('outputs', {described});
end

function result = sweepResult(e)
lengths = reshape(e.lengths, 1, []);
other = e.other;
along = char(e.along);
sums = cell(1, numel(lengths));
for index = 1:numel(lengths)
    n = lengths(index);
    k = 1:n;
    v = 0.1 * k;
    v(mod(k, 5) == 1) = 1e16;
    v(mod(k, 5) == 2) = -1e16;
    a = v(:) .* (1:other);
    switch along
        case 'columns'
            sums{index} = describeValue(sum(a, 1));
        case 'rows'
            sums{index} = describeValue(sum(a.', 2));
        otherwise
            error('References:InvalidSemanticsFixture', 'Unknown direction %s', along);
    end
end
result = struct('lengths', lengths, 'sums', {sums});
end

function result = fluidResult(e)
model = Inputs.Model(char(e.modelFile), char(e.modelId));
pressures = FixtureArguments.textToDoubles(e.pressures);
fluids = Inputs.FluidProperties(pressures, model);
names = fluidPropertyNames();
result = cell(1, numel(fluids));
for k = 1:numel(fluids)
    s = struct();
    for j = 1:numel(names)
        s.(names{j}) = describeValue(fluids(k).(names{j}));
    end
    result{k} = s;
end
end

function names = fluidPropertyNames()
% The 29 stored data properties of Inputs.FluidProperties (the CoolProp
% handle is left out).
names = {'FLUID', 'PROPERTIES', 'PRESSURE', 'TSAT', 'RHOF', 'RHOG', 'MUF', ...
    'MUG', 'HF', 'HG', 'HFG', 'SIGMA', 'KF', 'KG', 'CPF', 'CPG', 'ALPHAF', ...
    'ALPHAG', 'PRANDTLF', 'PRANDTLG', 'PCRIT', 'PTRIPLE', 'UC', 'QK', ...
    'TMIN', 'HMIN', 'TMAX', 'HMAX', 'QKMAX'};
end

function result = methodsResult(e)
model = Inputs.Model(char(e.modelFile), char(e.modelId));
pressure = str2double(char(e.pressure));
fluid = Inputs.FluidProperties(pressure, model);
quantity = char(e.grid.quantity);
grid = methodGrid(e.grid, fluid);
if strcmp(quantity, 'enthalpy')
    names = {'T', 'RHOL', 'RHOV', 'MUL', 'MUV', 'KL', 'KV', 'CPL', 'CPV', ...
        'ALPHAL', 'ALPHAV', 'PRANDTLL', 'PRANDTLV'};
else
    names = {'H'};
end
outcomes = struct();
for k = 1:numel(names)
    name = names{k};
    outcomes.(name) = guarded(@() feval(name, fluid, grid));
end
result = struct();
result.quantity = quantity;
result.grid = describeValue(grid);
result.methods = outcomes;
end

function grid = methodGrid(g, fluid)
% The grid of a fluidmethods case (see runSemanticsCase).
if strcmp(char(g.type), 'anchors')
    if strcmp(char(g.quantity), 'enthalpy')
        anchors = [fluid.HMIN, fluid.HF, fluid.HG, fluid.HMAX];
    else
        anchors = [fluid.TMIN, fluid.TMAX];
    end
    offsets = FixtureArguments.textToDoubles(g.offsets);
    n = g.interior;
    points = reshape(anchors(:) + offsets(:).', 1, []);
    for k = 1:numel(anchors) - 1
        a = anchors(k);
        b = anchors(k + 1);
        points = [points, a + (b - a) * (1:n) / (n + 1)]; %#ok<AGROW>
    end
    grid = reshape(unique(points), 1, []);
else
    values = FixtureArguments.textToDoubles(g.values);
    switch char(g.shape)
        case 'scalar'
            grid = values(1);
        case 'row'
            grid = values;
        case 'column'
            grid = reshape(values, [], 1);
        case 'empty'
            grid = zeros(0, 0);
        otherwise
            error('References:InvalidSemanticsFixture', ...
                'Unknown grid shape %s', char(g.shape));
    end
end
end

function result = boundaryResult(e)
model = Inputs.Model(char(e.modelFile), char(e.modelId));
if isfield(e, 'default')
    objs = Inputs.BoundaryConditions();
else
    geometry = Inputs.Geometry(char(e.geometryFile), char(e.geometryId));
    objs = Inputs.BoundaryConditions(char(e.file), geometry);
end
pressures = reshape([objs.PRESSURE], 1, []);
fluids = Inputs.FluidProperties(pressures, model);
members = {'TSAT', 'HF', 'HG', 'TIN', 'DTIN', 'DHIN', 'XIN'};
objects = cell(1, numel(objs));
for k = 1:numel(objs)
    s = struct();
    for j = 1:numel(members)
        member = members{j};
        s.(member) = guarded(@() feval(member, objs(k), fluids(k)));
    end
    objects{k} = s;
end
result = struct();
result.pressures = describeValue(pressures);
result.fluidCount = numel(fluids);
result.objects = objects;
end

function r = guarded(f)
% The outcome of calling F with no argument: ok, the error (identifier and
% message, '' when ok) and the value through describeValue ([] on error).
r = struct('ok', true, 'errorId', '', 'errorMessage', '', 'value', []);
try
    r.value = describeValue(f());
catch err
    r.ok = false;
    r.errorId = err.identifier;
    r.errorMessage = err.message;
end
end
