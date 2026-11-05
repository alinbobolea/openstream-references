function env = environmentRecord(jsonFile)
%ENVIRONMENTRECORD Describe the software environment of a run.
%
%   ENV = ENVIRONMENTRECORD() returns a struct with the MATLAB, Python and
%   CoolProp versions, the upstream commits (environment variables set by
%   the workflow), the runner image, the processor model (cpuModel, from
%   /proc/cpuinfo where that file exists; where it does not exist, on
%   Windows, the value of the environment variable PROCESSOR_IDENTIFIER,
%   '' when it is not set; see machineProcessorModel) and the creation time
%   (UTC).
%
%   ENV = ENVIRONMENTRECORD(JSONFILE) also writes ENV to JSONFILE.

arguments
    jsonFile (1,1) string = ""
end

env = struct();
env.matlabVersion = version;
env.matlabRelease = version('-release');
env.pythonVersion = char(py.sys.version);
env.coolpropVersion = char(py.CoolProp.CoolProp.get_global_param_string('version'));
env.openstreamCommit = getenv('OPENSTREAM_COMMIT');
env.coolpropWrapperCommit = getenv('COOLPROPWRAPPER_COMMIT');
env.runnerImage = strtrim([getenv('ImageOS') ' ' getenv('ImageVersion')]);
env.computer = computer;
% Where /proc/cpuinfo does not exist (Windows), the model is the value of
% the environment variable PROCESSOR_IDENTIFIER (see machineProcessorModel).
env.cpuModel = machineProcessorModel('/proc/cpuinfo', getenv('PROCESSOR_IDENTIFIER'));
env.created = char(datetime('now', TimeZone = 'UTC', ...
    Format = 'yyyy-MM-dd''T''HH:mm:ss''Z'''));

if strlength(jsonFile) > 0
    fid = fopen(jsonFile, 'w');
    fprintf(fid, '%s\n', jsonencode(env, PrettyPrint = true));
    fclose(fid);
end

end
