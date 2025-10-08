classdef helperQAMDemodulator < matlab.System
%helperQAMDemodulator Lightweight System object wrapper around qamdemod.
%
%   Provides the minimal functionality required by the universal receiver
%   example in place of the removed comm.RectangularQAMDemodulator object.
%   Only bit output and average power normalisation are supported.
%
%   Copyright 2024

    %#ok<*EMCA>

    properties (Nontunable)
        ModulationOrder (1, 1) double {mustBePositive, mustBeInteger} = 16;
        BitOutput (1, 1) logical = true;
        NormalizationMethod (1, :) char {mustBeMember(NormalizationMethod, {'Average power'})} = 'Average power';
    end

    methods
        function obj = helperQAMDemodulator(varargin)
            setProperties(obj, nargin, varargin{:});
        end
    end

    methods (Access = protected)
        function setupImpl(obj)
            if ~obj.BitOutput
                error('helperQAMDemodulator:UnsupportedConfiguration', ...
                    'Only BitOutput == true is supported.');
            end
        end

        function y = stepImpl(obj, x)
            y = qamdemod(x, obj.ModulationOrder, ...
                'OutputType', 'bit', ...
                'UnitAveragePower', true);
        end

        function resetImpl(~)
        end

        function releaseImpl(~)
        end
    end
end
