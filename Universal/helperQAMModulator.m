classdef helperQAMModulator < matlab.System
%helperQAMModulator Lightweight System object wrapper around qammod.
%
%   This helper provides the small subset of functionality required by the
%   universal transmitter/receiver example now that the legacy
%   comm.RectangularQAMModulator object has been removed. Only bit input and
%   average power normalisation are supported.
%
%   Copyright 2024

    %#ok<*EMCA>

    properties (Nontunable)
        ModulationOrder (1, 1) double {mustBePositive, mustBeInteger} = 16;
        BitInput (1, 1) logical = true;
        NormalizationMethod (1, :) char {mustBeMember(NormalizationMethod, {'Average power'})} = 'Average power';
    end

    properties
        OutputDataType (1, :) char {mustBeMember(OutputDataType, {'double', 'single'})} = 'double';
    end

    methods
        function obj = helperQAMModulator(varargin)
            setProperties(obj, nargin, varargin{:});
        end
    end

    methods (Access = protected)
        function setupImpl(obj)
            if ~obj.BitInput
                error('helperQAMModulator:UnsupportedConfiguration', ...
                    'Only BitInput == true is supported.');
            end
        end

        function y = stepImpl(obj, x)
            modData = qammod(x, obj.ModulationOrder, ...
                'InputType', 'bit', ...
                'UnitAveragePower', true);
            if strcmp(obj.OutputDataType, 'single')
                y = single(modData);
            else
                y = double(modData);
            end
        end

        function resetImpl(~)
        end

        function releaseImpl(~)
        end
    end
end
