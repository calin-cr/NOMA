classdef (StrictDefaults)UniversalTransmitter < matlab.System
%UniversalTransmitter Generates a transmit waveform for multiple modulations
%
%   This System object mirrors the QPSKTransmitter used in the reference
%   example but relies on helperModulationConfig to create the appropriate
%   modulator object for the requested modulation order.
%
%   Copyright 2023 The MathWorks, Inc.

    properties (Nontunable)
        ModulationOrder = 4;
        HeaderLength = 26;
        PayloadLength = 2240;
        FrameBits = 0;
        UpsamplingFactor = 2;
        ScramblerBase = 2;
        ScramblerPolynomial = [1 1 1 0 1];
        ScramblerInitialConditions = [0 0 0 0];
        RolloffFactor = 0.5;
        RaisedCosineFilterSpan = 10;
        NumberOfMessage = 10;
        MessageLength = 16;
        MessageBits = [];
    end

    properties (Access = private)
        pBitGenerator
        pModulator
        pTransmitterFilter
        pMessage = 'Hello world';
    end

    methods
        function obj = UniversalTransmitter(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end

    methods (Access = protected)
        function setupImpl(obj)
            cfg = helperModulationConfig(obj.ModulationOrder);

            obj.pBitGenerator = UniversalBitsGenerator( ...
                'NumberOfMessage',              obj.NumberOfMessage, ...
                'MessageLength',                obj.MessageLength, ...
                'MessageBits',                  obj.MessageBits, ...
                'HeaderLength',                obj.HeaderLength, ...
                'ScramblerBase',                obj.ScramblerBase, ...
                'ScramblerPolynomial',          obj.ScramblerPolynomial, ...
                'ScramblerInitialConditions',   obj.ScramblerInitialConditions);

            obj.pModulator = cfg.ModulatorFactory();

            if isprop(obj.pModulator,'OutputDataType')
                obj.pModulator.OutputDataType = 'double';
            end

            obj.pTransmitterFilter = comm.RaisedCosineTransmitFilter( ...
                'RolloffFactor',                obj.RolloffFactor, ...
                'FilterSpanInSymbols',          obj.RaisedCosineFilterSpan, ...
                'OutputSamplesPerSymbol',       obj.UpsamplingFactor);
        end

        function transmittedSignal = stepImpl(obj)
            [transmittedBin, ~] = obj.pBitGenerator();
            if obj.FrameBits > 0
                targetLength = obj.FrameBits;
            else
                targetLength = length(transmittedBin);
            end
            padLength = targetLength - length(transmittedBin);
            if padLength > 0
                modInput = [transmittedBin; zeros(padLength,1)];
            else
                modInput = transmittedBin(1:targetLength);
            end
            modulatedData = obj.pModulator(modInput);
            transmittedSignal = obj.pTransmitterFilter(modulatedData);
        end

        function resetImpl(obj)
            reset(obj.pBitGenerator);
            reset(obj.pModulator);
            reset(obj.pTransmitterFilter);
        end

        function releaseImpl(obj)
            release(obj.pBitGenerator);
            release(obj.pModulator);
            release(obj.pTransmitterFilter);
        end

        function N = getNumInputsImpl(~)
            N = 0;
        end
    end
end
