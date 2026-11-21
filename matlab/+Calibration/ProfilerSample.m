classdef ProfilerSample
    %PROFILERSAMPLE A small class with known executed lines.
    %
    %   calibrateProfiler runs it under the profiler and compares what the
    %   profiler reports with what is known here. A line that has a tag in its
    %   trailing comment is part of the comparison:
    %
    %   - [ran:KIND]   a statement that runs when calibrateProfiler runs the
    %                  sample (see runSample in calibrateProfiler);
    %   - [never:KIND] a statement that does not run;
    %   - [label:KIND] a line of a kind whose treatment by the profiler is
    %                  being recorded (a signature, case, else, end, import, a line of
    %                  a continued statement). Nothing is known about it in
    %                  advance.
    %
    %   Lines without a tag are not compared. Do not move or edit a tagged line
    %   without running the tests: the tags and the code are one record.

    properties
        scale = 2                                                          % [label:property-default]
    end

    methods

        function obj = ProfilerSample(scale)                               % [label:constructor-signature]
            if nargin > 0                                                  % [ran:if-condition]
                obj.scale = scale;                                         % [ran:statement-if-true]
            end                                                            % [label:end-of-if]
        end                                                                % [label:end-of-function]

        function out = branches(obj, mode)                                 % [label:method-signature]
            switch mode                                                    % [ran:switch]
                case 1                                                     % [label:case-taken]
                    out = obj.scale;                                       % [ran:case-body-taken]
                case 2                                                     % [label:case-unused]
                    out = 2 * obj.scale;                                   % [never:case-body-unused]
                otherwise                                                  % [label:otherwise]
                    out = 3 * obj.scale;                                   % [ran:otherwise-body-taken]
            end                                                            % [label:end-of-switch]
        end                                                                % [label:end-of-function]

        function out = twoWay(obj, flag)                                   % [label:method-signature]
            if flag                                                        % [ran:if-condition]
                out = obj.scale;                                           % [ran:if-body-taken]
            else                                                           % [label:else]
                out = -obj.scale;                                          % [never:else-body-unused]
            end                                                            % [label:end-of-if]
        end                                                                % [label:end-of-function]

        function out = continued(obj)                                      % [label:method-signature]
            out = obj.scale + ...                                          % [ran:continued-statement-first-line]
                obj.scale + ...                                            % [label:continued-statement-middle-line]
                1;                                                         % [label:continued-statement-last-line]
        end                                                                % [label:end-of-function]

        function out = looped(obj)                                         % [label:method-signature]
            out = 0;                                                       % [ran:statement-before-loop]
            for k = 1:2                                                    % [ran:for-line]
                out = out + obj.scale;                                     % [ran:for-body]
            end                                                            % [label:end-of-for]
        end                                                                % [label:end-of-function]

        function out = guarded(obj)                                        % [label:method-signature]
            try                                                            % [label:try]
                out = obj.scale;                                           % [ran:try-body]
            catch                                                          % [label:catch]
                out = 0;                                                   % [never:catch-body-unused]
            end                                                            % [label:end-of-try]
        end                                                                % [label:end-of-function]

        function out = withLocalCall(obj)                                  % [label:method-signature]
            import Calibration.ProfilerSample                              % [label:import]
            out = localDouble(obj.scale);                                  % [ran:statement-calling-local-function]
        end                                                                % [label:end-of-function]

        function out = neverCalled(obj)                                    % [label:signature-of-uncalled-method]
            out = obj.scale;                                               % [never:body-of-uncalled-method]
        end                                                                % [label:end-of-uncalled-method]

    end

end

function y = localDouble(x)                                                % [label:local-function-signature]
    y = 2 * x;                                                             % [ran:local-function-body]
end                                                                        % [label:end-of-local-function]
