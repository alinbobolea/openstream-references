function out = toPlain(value, opts)
%TOPLAIN Convert a value, including OpenSTREAM objects, to plain MATLAB types.
%
%   OUT = TOPLAIN(VALUE) returns VALUE with every object converted to
%   numeric, logical, char, cell or struct data.
%
%   OUT = TOPLAIN(VALUE, includePrefixes=PREFIXES) converts objects whose
%   class name starts with one of PREFIXES. Default: "Solvers.", "Inputs.",
%   "Session.".
%
%   Stub: not implemented yet; returns [].

arguments
    value
    opts.includePrefixes (1,:) string = ["Solvers." "Inputs." "Session."]
end

out = [];

end
