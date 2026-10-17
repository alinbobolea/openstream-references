function name = cpuModelName(cpuinfoText)
%CPUMODELNAME The processor model named in the text of /proc/cpuinfo.
%
%   NAME = CPUMODELNAME(CPUINFOTEXT) returns the trimmed text after the
%   first line that starts with "model name", optional spaces or tabs, and
%   a colon. NAME is '' when there is no such line or its value is blank.
%   CPUINFOTEXT may be a char vector or a string scalar.

tokens = regexp(char(cpuinfoText), '^model name[ \t]*:([^\r\n]*)', ...
    'tokens', 'once', 'lineanchors');
name = '';
if ~isempty(tokens)
    name = strtrim(tokens{1});
end
if isempty(name)
    name = '';
end

end
