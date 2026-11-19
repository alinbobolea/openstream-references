function record = failureRecord(name, err)
%FAILURERECORD The record of a case that failed.
%
%   RECORD = FAILURERECORD(NAME, ERR) returns a struct with the string fields
%   name (the case), identifier and message (those of the MException ERR) and
%   where (the function and line at the top of the error's stack, or "" when
%   it has none).

arguments
    name (1,1) string
    err (1,1) MException
end

record = struct( ...
    'name', name, ...
    'identifier', string(err.identifier), ...
    'message', string(err.message), ...
    'where', "");
if ~isempty(err.stack)
    top = err.stack(1);
    record.where = string(sprintf('%s (line %d)', top.name, top.line));
end

end
