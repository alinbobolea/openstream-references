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
%   The caller reads the file and the variable, so that both cases can be
%   tested on any system.

if isstring(cpuinfoText) && isscalar(cpuinfoText) && ismissing(cpuinfoText)
    name = strtrim(char(string(processorIdentifier)));
    if isempty(name)
        name = '';
    end
else
    name = cpuModelName(cpuinfoText);
end

end
