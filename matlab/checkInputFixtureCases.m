function checkInputFixtureCases(cases)
%CHECKINPUTFIXTURECASES Fail when an input-fixture case failed because of the manifest.
%
%   CHECKINPUTFIXTURECASES(CASES), with CASES the cell array of recorded
%   cases (each a struct with fields name and errorId), errors with
%   identifier References:InvalidInputFixture, naming the cases, when any
%   case's errorId is References:InvalidInputFixture. That identifier is
%   raised only by the fixture's own code for a malformed manifest argument
%   (an unknown argument key, class or "as" value, or a badly shaped list),
%   which would otherwise look like an intended failing case.

arguments
    cases cell
end

bad = strings(1, 0);
for k = 1:numel(cases)
    if strcmp(cases{k}.errorId, 'References:InvalidInputFixture')
        bad(end+1) = string(cases{k}.name); %#ok<AGROW>
    end
end
if ~isempty(bad)
    error('References:InvalidInputFixture', ...
        'Case(s) failed because of the manifest: %s', strjoin(bad, ', '));
end

end
