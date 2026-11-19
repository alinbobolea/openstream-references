function failures = runGuarded(action, name, inputFiles, outputDir, continueOnError, failures)
%RUNGUARDED Run the work of one case; when it fails, stop or record the failure.
%
%   FAILURES = RUNGUARDED(ACTION, NAME, INPUTFILES, OUTPUTDIR, CONTINUEONERROR,
%   FAILURES) calls ACTION, a function handle without arguments. If it errors
%   and CONTINUEONERROR is false, the error is rethrown unchanged. If
%   CONTINUEONERROR is true the failure is recorded instead: the failureRecord
%   of the case NAME is appended to the cell row FAILURES, which is returned,
%   and the files in the string array INPUTFILES (those that exist) are copied
%   to OUTPUTDIR/<NAME>-inputs, so that the failing case can be looked at.
%   When ACTION does not error FAILURES is returned as it was.

arguments
    action (1,1) function_handle
    name (1,1) string
    inputFiles string
    outputDir (1,1) string
    continueOnError (1,1) logical
    failures cell
end

try
    action();
catch err
    if ~continueOnError
        rethrow(err);
    end
    fprintf('\n*** %s FAILED, the run goes on: %s\n', name, err.message);
    failures{end+1} = failureRecord(name, err);
    copyInputs(fullfile(outputDir, name + "-inputs"), inputFiles);
end

end

function copyInputs(folder, files)
% The files that exist, copied to FOLDER; a file that cannot be copied does
% not hide the failure that is being recorded.
if ~isfolder(folder)
    mkdir(folder);
end
for file = reshape(files, 1, [])
    if isfile(file)
        try
            copyfile(file, folder);
        catch
            fprintf('could not copy %s\n', file);
        end
    end
end
end
