function writeFailures(outputDir, failures)
%WRITEFAILURES Write the cases that failed to OUTPUTDIR/failures.json.
%
%   WRITEFAILURES(OUTPUTDIR, FAILURES) writes the failureRecord structs of the
%   cell row FAILURES, in order, as a JSON list; an empty list is written as
%   [] so that a run in which every case passed says so.

arguments
    outputDir (1,1) string
    failures cell
end

if isempty(failures)
    text = '[]';
else
    text = jsonencode([failures{:}], 'PrettyPrint', true);
    if text(1) ~= '['
        text = ['[' text ']'];  % one record is encoded as an object, not a list
    end
end
fid = fopen(fullfile(outputDir, 'failures.json'), 'w');
if fid < 0
    error('References:CannotWrite', 'Cannot write %s', ...
        fullfile(outputDir, 'failures.json'));
end
fprintf(fid, '%s\n', text);
fclose(fid);

end
