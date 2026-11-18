function requireOverridesUsed(inputSet, overrides)
%REQUIREOVERRIDESUSED Error when upstream ignored a key that a case overrode.
%
%   REQUIREOVERRIDESUSED(INPUTSET, OVERRIDES) checks, for each of model,
%   options and geometry that OVERRIDES has (a struct of key-value structs, as
%   prepareCaseInputs returns), that none of its keys is among the entries the
%   upstream input object kept as unused (the property "extra"). Upstream only
%   warns about an unused entry, and the warnings are switched off while the
%   input set is built, so that a misspelled key would otherwise change
%   nothing without a sign.
%
%   Errors: References:OverrideIgnored, naming the kind and the keys.

arguments
    inputSet (1,1)
    overrides (1,1) struct
end

for kind = ["model" "options" "geometry"]
    if ~isfield(overrides, kind)
        continue
    end
    extra = inputSet.(kind).extra;
    if isempty(extra)
        continue
    end
    keys = upper(string(fieldnames(overrides.(kind))));
    unused = keys(ismember(keys, upper(string(fieldnames(extra)))));
    if ~isempty(unused)
        error('References:OverrideIgnored', ...
            'The %s override key(s) %s were not used by upstream (not an input of the %s)', ...
            kind, strjoin(unused, ', '), kind);
    end
end

end
