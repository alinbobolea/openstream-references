classdef FakeMixture < TestData.FakeBase
    %FAKEMIXTURE A stored state with the kinds of methods exportDerived sees.
    %
    % NZ = 3 nodes. Every method with a node index uses 1:NZ when it is not
    % given, as the upstream methods do. The values are simple functions of
    % OFFSET and of the node index, so that a test can state them.

    properties
        NZ = 3
        OFFSET = 0
        liquid
        vapor
        hiddenProperty = 1
    end

    properties (Dependent)
        dependentProperty
    end

    properties (GetAccess = private, SetAccess = private)
        privateValue = 5
    end

    methods

        function obj = FakeMixture(offset)
            if nargin > 0
                obj.OFFSET = offset;
            end
        end

        function set.OFFSET(obj, value)
            obj.OFFSET = value;
        end

        function value = get.dependentProperty(obj)
            value = obj.OFFSET;
        end

        function v = VALUE(obj, zIdx)
            % OFFSET + node index, a column.
            if nargin < 2, zIdx = (1:obj.NZ).'; end
            v = obj.OFFSET + zIdx;
        end

        function [a, b] = PAIR(obj, zIdx)
            % Two outputs.
            if nargin < 2, zIdx = (1:obj.NZ).'; end
            a = obj.OFFSET + zIdx;
            b = 10 * zIdx;
        end

        function [twall, tbulk] = TWALL(obj, zIdx)
            % Two columns (two walls) and the bulk value.
            if nargin < 2, zIdx = (1:obj.NZ).'; end
            twall = [100 + obj.OFFSET + zIdx, 200 + obj.OFFSET + zIdx];
            tbulk = 300 + zIdx;
        end

        function v = NEEDSTWALL(obj, twall, zIdx)
            % The first wall of twall plus the node index.
            if nargin < 3, zIdx = (1:obj.NZ).'; end
            v = twall(:, 1) + zIdx + 0 * obj.OFFSET;
        end

        function v = UP(obj, zIdx)
            if nargin < 2, zIdx = (1:obj.NZ).'; end
            v = 2 * zIdx + obj.OFFSET;
        end

        function v = MCT(obj, zIdx)
            if nargin < 2, zIdx = (1:obj.NZ).'; end
            v = 3 * zIdx + obj.OFFSET;
        end

        function v = WITHOLD(obj, UPold, MCTold, zIdx)
            % The change of UP and of MCT from the previous state.
            if nargin < 4, zIdx = (1:obj.NZ).'; end
            v = obj.UP(zIdx) - UPold + obj.MCT(zIdx) - MCTold;
        end

        function s = STRUCTVALUE(obj, zIdx)
            % A struct, like DPPARTS.
            if nargin < 2, zIdx = (1:obj.NZ).'; end
            s = struct('FIRST', zIdx, 'SECOND', obj.OFFSET + 0 * zIdx);
        end

        function v = SCALARONLY(obj, zIdx)
            % Errors for more than one node, like upstream's DITTUSBOELTERGEN.
            if nargin < 2, zIdx = (1:obj.NZ).'; end
            if numel(zIdx) > 1
                error('Fake:vector', 'one node at a time');
            end
            v = 7 * zIdx + obj.OFFSET;
        end

        function v = SCALARTEXT(obj, zIdx)
            % Errors for more than one node, and gives text for one.
            if nargin < 2, zIdx = (1:obj.NZ).'; end
            if numel(zIdx) > 1
                error('Fake:vector', 'one node at a time');
            end
            v = 'text';
        end

        function v = ALWAYSFAILS(obj, zIdx) %#ok<STOUT,INUSD>
            error('Fake:always', 'this method always fails');
        end

        function v = TRAILING(obj, zIdx, skipAdjustments)
            % Like HNEARWALLEQ: a node index and a flag that is left out.
            if nargin < 2, zIdx = (1:obj.NZ).'; end
            if nargin < 3, skipAdjustments = false; end
            v = obj.OFFSET + zIdx + 1000 * skipAdjustments;
        end

        function v = NEEDSOTHER(obj, param1, param2, zIdx) %#ok<INUSD>
            % Like AFDISTR: inputs that no one can give.
            if nargin < 4, zIdx = (1:obj.NZ).'; end
            v = param1 + param2 + zIdx;
        end

        function NOOUTPUT(obj) %#ok<MANU>
        end

        function v = WARNS(obj) %#ok<MANU>
            warning('Fake:warns', 'a warning that must not appear');
            v = 1;
        end

        function v = NOINDEX(obj)
            % No node index at all (like NEARWALLRATIO).
            v = 40 + obj.OFFSET;
        end

    end

    methods (Hidden = true)

        function v = HIDDENVALUE(obj, zIdx)
            if nargin < 2, zIdx = (1:obj.NZ).'; end
            v = 50 + zIdx + obj.OFFSET;
        end

    end

    methods (Access = private)

        function v = PRIVATEVALUE(obj) %#ok<MANU>
            v = 1;
        end

    end

    methods (Access = protected)

        function v = PROTECTEDVALUE(obj) %#ok<MANU>
            v = 1;
        end

    end

    methods (Static)

        function v = STATICVALUE()
            v = 1;
        end

    end

end
