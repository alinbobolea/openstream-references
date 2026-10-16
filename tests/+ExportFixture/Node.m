classdef Node < handle
    %NODE Test fixture holding every kind of property toPlain must handle.
    %
    % value and next are stored public properties, hiddenValue a stored
    % private one, scratch is transient, doubled is dependent and LIMIT is
    % constant. next lets tests build reference cycles.

    properties
        value = 0
        next = []
    end

    properties (Access = private)
        hiddenValue = 42
    end

    properties (Transient)
        scratch = 7
    end

    properties (Dependent)
        doubled
    end

    properties (Constant)
        LIMIT = 10
    end

    methods

        function obj = Node(value)
            if nargin > 0
                obj.value = value;
            end
        end

        function d = get.doubled(obj)
            d = 2*obj.value;
        end

    end

end
