function varargout = warning(varargin)
%WARNING Issue a warning as the built-in does, and record it for WarningRecorder.
%
%   This file shadows the built-in warning while a WarningRecorder exists:
%   the recorder puts this folder first on the search path and takes it off
%   again when it is released. Keep the folder out of the source folder
%   (genpath of it must never reach this file).
%
%   - A call that sets or reads the warning state (WarningRecorder.isStateCall:
%     no argument, a struct, or a first argument on, off, query or error) and
%     a call with an output go to the built-in unchanged and are not recorded.
%   - Any other call is passed to the built-in. When the built-in has left a
%     message in lastwarn (lastwarn is reset before the call), the identifier
%     and the formatted message are appended to the recorder that is current,
%     and lastwarn is left as the built-in set it. The state of the warning is
%     not looked at: MATLAB records a warning in lastwarn even while it is off,
%     and such a call is recorded like any other. When the built-in left
%     nothing (a call with an empty message) lastwarn is restored as it was.
%     An error of the built-in (a warning turned into an error) is thrown again
%     after lastwarn is restored.
%   - Recording never throws.

if nargout > 0
    [varargout{1:nargout}] = builtin('warning', varargin{:});
    return
end
if WarningRecorder.isStateCall(varargin)
    builtin('warning', varargin{:});
    return
end

[previousMessage, previousId] = lastwarn;
lastwarn('', '');
try
    builtin('warning', varargin{:});
catch err
    lastwarn(previousMessage, previousId);
    rethrow(err);
end
[message, id] = lastwarn;
if isempty(message)
    lastwarn(previousMessage, previousId);
    return
end
try
    WarningRecorder.add(id, message);
catch
    % Recording must never change what the caller sees.
end

end
