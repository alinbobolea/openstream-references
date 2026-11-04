classdef WarningRecorder < handle
    %WARNINGRECORDER Record the calls of the function warning while it exists.
    %
    %   REC = WARNINGRECORDER() starts recording: the folder
    %   support/warningRecorder, which holds a function file warning.m that
    %   records a call and passes it to the built-in, is put first on the
    %   search path. REC.RECORDED() returns the warnings recorded since, a
    %   struct array with the fields identifier and message (the formatted
    %   text), in the order they were issued.
    %
    %   What is recorded: every call of warning (a message, with or without
    %   an identifier and format arguments) that leaves a message in lastwarn
    %   after the built-in has run. Whether MATLAB leaves one for a warning
    %   that is switched off is decided by MATLAB (the source folder says
    %   lastwarn records a warning even while it is off); the recorder does
    %   not look at the state of the warning. Calls that set or read the
    %   state, calls with an output and calls with no argument are passed on
    %   and not recorded. Warnings issued by calling builtin('warning', ...)
    %   directly do not pass through the shadow and are not recorded.
    %
    %   WARNINGRECORDER(FOLDER) uses the shadow in FOLDER instead (a seam for
    %   tests). A folder without warning.m, or one that is not on the path
    %   after it was added, is an error with the identifier
    %   References:WarningRecorderUnavailable and nothing is changed.
    %
    %   The recorder does not depend on the text the console shows, which
    %   differs between hosts (on the test runner a displayed warning is
    %   the bracketed text [Warning: ...]).
    %
    %   The recorder stops when it is deleted or cleared (the path and the
    %   state of the notice below are restored when the last one stops).
    %   Recorders nest: the newest one records until it is released.
    %   WarningRecorder.releaseAll() stops all of them. Test isvalid before
    %   deleting a handle that may have been released.
    %
    %   MATLAB says, when a file with the name of a built-in is first used,
    %   that the function has the same name as a built-in (identifier
    %   MATLAB:dispatcher:nameConflict). That notice is switched off for the
    %   whole life of the recorders and its state restored at the end.
    %   WarningRecorder.complete drops it from recorded warnings.

    properties (Access = private)
        id (1,1) double = 0
        final = struct('identifier', {}, 'message', {})
    end

    methods

        function obj = WarningRecorder(folder)
            if nargin < 1
                folder = WarningRecorder.folder();
            end
            obj.id = WarningRecorder.nextId();
            WarningRecorder.install(obj.id, folder);
        end

        function w = recorded(obj)
            %RECORDED The warnings recorded so far (or up to the release).
            if obj.id > 0 && isappdata(0, WarningRecorder.dataKey(obj.id))
                w = getappdata(0, WarningRecorder.dataKey(obj.id));
            else
                w = obj.final;
            end
        end

        function delete(obj)
            if obj.id > 0
                obj.final = obj.recorded();
                WarningRecorder.uninstall(obj.id);
                obj.id = 0;
            end
        end

    end

    methods (Static)

        function k = key()
            %KEY The name of the root appdata item that holds the stack of
            % recorders (absent when none is active).
            k = 'WarningRecorderStack';
        end

        function f = folder()
            %FOLDER The folder with the shadow warning.m.
            here = fileparts(mfilename('fullpath'));
            f = fullfile(fileparts(here), 'support', 'warningRecorder');
        end

        function tf = active()
            %ACTIVE True while some recorder exists.
            tf = isappdata(0, WarningRecorder.key()) ...
                && ~isempty(getappdata(0, WarningRecorder.key()));
        end

        function tf = isStateCall(args)
            %ISSTATECALL True for the argument lists (a cell) of the calls of
            % warning that set or read the state: none, a struct, or a first
            % argument that is on, off, query or error (char or string).
            tf = isempty(args) || isstruct(args{1});
            if ~tf && (ischar(args{1}) || isstring(args{1})) && isscalar(string(args{1}))
                tf = any(strcmp(char(args{1}), {'on', 'off', 'query', 'error'}));
            end
        end

        function w = complete(recorded, lastMessage, lastId)
            %COMPLETE The recorded warnings plus the last warning of lastwarn
            % (LASTMESSAGE, LASTID) when it is not the last recorded one: a
            % warning issued by a direct call of the built-in was not seen
            % by the shadow. The notice that a function has the name of a
            % built-in is dropped from both.
            notice = 'MATLAB:dispatcher:nameConflict';
            w = recorded;
            if ~isempty(w)
                w = w(~strcmp({w.identifier}, notice));
            end
            if (~isempty(lastMessage) || ~isempty(lastId)) && ~strcmp(lastId, notice)
                if isempty(w) || ~strcmp(w(end).message, lastMessage) ...
                        || ~strcmp(w(end).identifier, lastId)
                    w(end+1) = struct('identifier', lastId, 'message', lastMessage);
                end
            end
        end

        function add(identifier, message)
            %ADD Append a warning to the newest recorder (called by the
            % shadow warning.m; does nothing when no recorder exists).
            stack = getappdata(0, WarningRecorder.key());
            if isempty(stack)
                return
            end
            dataKey = WarningRecorder.dataKey(stack(end));
            w = getappdata(0, dataKey);
            w(end+1) = struct('identifier', char(identifier), 'message', char(message));
            setappdata(0, dataKey, w);
        end

        function releaseAll()
            %RELEASEALL Stop every recorder and restore the path.
            stack = getappdata(0, WarningRecorder.key());
            for id = fliplr(reshape(stack, 1, []))
                WarningRecorder.uninstall(id);
            end
        end

    end

    methods (Static, Access = private)

        function k = dataKey(id)
            k = sprintf('%s%d', WarningRecorder.key(), id);
        end

        function k = settingsKey()
            k = [WarningRecorder.key() 'Settings'];
        end

        function id = nextId()
            persistent counter
            if isempty(counter)
                counter = 0;
            end
            counter = counter + 1;
            id = counter;
        end

        function install(id, folder)
            stack = getappdata(0, WarningRecorder.key());
            if isempty(stack)
                % The outermost recorder puts the shadow on the path. Nothing
                % is changed before the file is known to be there, and what is
                % changed is undone when the shadow does not take.
                if ~isfile(fullfile(folder, 'warning.m'))
                    error('References:WarningRecorderUnavailable', ...
                        'The folder %s has no warning.m', folder);
                end
                noticeId = 'MATLAB:dispatcher:nameConflict';
                noticeState = warning('off', noticeId);
                addpath(folder, '-begin');
                if ~contains(path, folder)
                    warning(noticeState);
                    error('References:WarningRecorderUnavailable', ...
                        'The folder %s is not on the path', folder);
                end
                setappdata(0, WarningRecorder.settingsKey(), ...
                    struct('folder', folder, 'noticeState', noticeState));
            end
            setappdata(0, WarningRecorder.dataKey(id), ...
                struct('identifier', {}, 'message', {}));
            setappdata(0, WarningRecorder.key(), [reshape(stack, 1, []) id]);
        end

        function uninstall(id)
            stack = reshape(getappdata(0, WarningRecorder.key()), 1, []);
            stack(stack == id) = [];
            if isappdata(0, WarningRecorder.dataKey(id))
                rmappdata(0, WarningRecorder.dataKey(id));
            end
            if ~isempty(stack)
                setappdata(0, WarningRecorder.key(), stack);
                return
            end
            if isappdata(0, WarningRecorder.key())
                rmappdata(0, WarningRecorder.key());
            end
            if isappdata(0, WarningRecorder.settingsKey())
                settings = getappdata(0, WarningRecorder.settingsKey());
                rmappdata(0, WarningRecorder.settingsKey());
                if contains(path, settings.folder)
                    rmpath(settings.folder);
                end
                warning(settings.noticeState);
            end
        end

    end

end
