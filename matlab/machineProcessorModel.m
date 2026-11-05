function name = machineProcessorModel(cpuinfoFile, processorIdentifier)
%MACHINEPROCESSORMODEL The processor model of this machine.
%
%   NAME = MACHINEPROCESSORMODEL(CPUINFOFILE, PROCESSORIDENTIFIER) reads the
%   file CPUINFOFILE (environmentRecord passes /proc/cpuinfo) when it exists
%   and returns, as a char vector, what processorModelName makes of its
%   text; when the file does not exist (Windows) it returns the value of the
%   environment variable PROCESSOR_IDENTIFIER, which the caller passes as
%   PROCESSORIDENTIFIER, trimmed. See processorModelName for the details.
%   Both branches are run by the unit tests with files of their own.

arguments
    cpuinfoFile (1,1) string
    processorIdentifier
end

cpuinfo = string(missing);
if isfile(cpuinfoFile)
    cpuinfo = string(fileread(cpuinfoFile));
end
name = processorModelName(cpuinfo, processorIdentifier);

end
