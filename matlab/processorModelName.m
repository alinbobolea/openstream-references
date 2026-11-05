function name = processorModelName(cpuinfoText, processorIdentifier)
%PROCESSORMODELNAME The processor model of the machine a run is on.
%
%   NAME = PROCESSORMODELNAME(CPUINFOTEXT, PROCESSORIDENTIFIER) returns, as
%   a char vector:
%
%   - where the file /proc/cpuinfo exists (CPUINFOTEXT is its text, a char
%     vector or a string scalar): what cpuModelName finds in it, '' when it
%     names no model. PROCESSORIDENTIFIER is not used then;
%   - where the file does not exist (CPUINFOTEXT is string(missing)): the
%     value of the environment variable PROCESSOR_IDENTIFIER, which is
%     PROCESSORIDENTIFIER (text), trimmed; '' when it is empty. Windows sets
%     this variable, for example "Intel64 Family 6 Model 85 Stepping 7,
%     GenuineIntel".
%
%   A value that is not a char array or a string scalar (an empty string
%   array, [], a missing string) counts as empty text. The caller reads the
%   file and the variable, so that both cases can be tested on any system.

if isstring(cpuinfoText) && isscalar(cpuinfoText) && ismissing(cpuinfoText)
    name = strtrim(scalarText(processorIdentifier));
    if isempty(name)
        name = '';
    end
else
    name = cpuModelName(scalarText(cpuinfoText));
end

end

function text = scalarText(value)
% VALUE as a char array: itself if it is a char array, its text if it is a
% string scalar that is not missing, '' for anything else. char of an empty
% string array is not a 0-by-0 char (it has more than two dimensions, and
% strtrim then errors), so that case is never given to char.
if ischar(value)
    text = value;
elseif isstring(value) && isscalar(value) && ~ismissing(value)
    text = char(value);
else
    text = '';
end
end
