classdef FakeProbeField < matlab.mixin.Copyable
    %FAKEPROBEFIELD A stored state with the calls that exportProbes makes.
    %
    % Five nodes. Built with the offset it has W = offset + (1:5)' and
    % H = 10 * offset + (1:5)'; built with two arguments (inputSet, fluid) it
    % keeps them; built without arguments its mesh is the single node 1, so that
    % copying into it from a state of five nodes is refused, as upstream refuses
    % a copy between objects that are not on one mesh.

    properties
        NZ = 5
        Z = (0:4).'
        W = zeros(5, 1)
        H = zeros(5, 1)
        inputSet
        fluid
    end

    methods

        function obj = FakeProbeField(inputSet, fluid, offset)
            if nargin == 0
                obj.Z = 1;
                return
            end
            obj.inputSet = inputSet;
            obj.fluid = fluid;
            if nargin > 2
                obj.W = offset + (1:5).';
                obj.H = 10 * offset + (1:5).';
            end
        end

        function chf = CHF(obj, zIdx)
            % 100 + the node index; the whole column without an index.
            chf = 100 + (1:obj.NZ).';
            if nargin > 1
                chf = chf(zIdx);
            end
        end

        function copyFlowProperties(srcObj, targetObj, opts)
            arguments
                srcObj
                targetObj
                opts.all (1,1) logical = false
            end
            if numel(srcObj.Z) ~= numel(targetObj.Z) || any(srcObj.Z ~= targetObj.Z)
                error('Fake:mismatch', 'mismatched spatial meshes');
            end
            if opts.all
                targetObj.W = srcObj.W;
                targetObj.H = srcObj.H;
            else
                targetObj.W(2:end) = srcObj.W(2:end);
                targetObj.H(2:end) = srcObj.H(2:end);
            end
        end

    end

end
