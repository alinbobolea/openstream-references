function [output, coverage] = runProfiled(action, root)
%RUNPROFILED Run a function under MATLAB's profiler and report executed lines.
%
%   [OUTPUT, COVERAGE] = RUNPROFILED(ACTION, ROOT) clears the profiler, turns
%   it on, calls OUTPUT = ACTION(), turns it off, and returns OUTPUT together
%   with profilerCoverage of the profile (the files under the folder ROOT).
%   The profiler is turned off, and its data cleared, also when ACTION
%   errors, and the error then passes on unchanged.

arguments
    action (1,1) function_handle
    root (1,1) string
end

profile('off');
profile('clear');
profile('on');
stop = onCleanup(@stopProfiler);

output = action();

profile('off');
coverage = profilerCoverage(profile('info'), root);

end

function stopProfiler()
profile('off');
profile('clear');
end
