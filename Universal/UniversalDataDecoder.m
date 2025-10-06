classdef UniversalDataDecoder < matlab.System
%UniversalDataDecoder Decode framed payloads for different modulations.
%
%   This decoder retains the framing, scrambling and BER tracking logic
%   from the QPSK reference while delegating modulation-specific behaviour
%   to helperModulationConfig. The header symbols are supplied by the
%   receiver so that the phase estimation matches the transmit configuration
%   exactly.
%
% Copyright 2012-2023 The MathWorks, Inc.

    properties (Nontunable)
        ModulationOrder = 4;
        HeaderLength = 26;
        PayloadLength = 2240;
        NumberOfMessage = 20;
        DescramblerBase = 2;
        DescramblerPolynomial = [1 1 1 0 1];
        DescramblerInitialConditions = [0 0 0 0];
        BerMask = [];
        PrintOption = false;
        Preview = false;
        HeaderSymbols = [];
    end

    properties (Access = private)
        pDemodulator
        pDescrambler
        pErrorRateCalc
        pTargetBits
        pBER
        pModConfig
        pHeaderSymbolLength
    end

    properties (Constant, Access = private)
        pBarkerCode = [+1; +1; +1; +1; +1; -1; -1; +1; +1; -1; +1; -1; +1];
        pMessage = 'Hello world';
        pMessageLength = 16;
    end

    methods
        function obj = UniversalDataDecoder(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end

    methods (Access = protected)
        function setupImpl(obj, ~, ~)
            coder.extrinsic('sprintf');

            obj.pModConfig = helperModulationConfig(obj.ModulationOrder);
            obj.pHeaderSymbolLength = length(obj.HeaderSymbols);

            obj.pDemodulator = obj.pModConfig.DemodulatorFactory();

            obj.pDescrambler = comm.Descrambler(obj.DescramblerBase, ...
                obj.DescramblerPolynomial, obj.DescramblerInitialConditions);

            obj.pErrorRateCalc = comm.ErrorRate( ...
                'Samples', 'Custom', ...
                'CustomSamples', obj.BerMask);

            msgSet = zeros(obj.NumberOfMessage * obj.pMessageLength, 1);
            for msgCnt = 0 : obj.NumberOfMessage - 1
                msgSet(msgCnt * obj.pMessageLength + (1 : obj.pMessageLength)) = ...
                    sprintf('%s %03d\n', obj.pMessage, mod(msgCnt, 100));
            end
            obj.pTargetBits = int2bit(msgSet, 7);
        end

        function  [BER,output] = stepImpl(obj, data, isValid)
            output = [];
            if isValid
                headerSlice = data(1:obj.pHeaderSymbolLength);
                phaseEst = angle(mean(conj(obj.HeaderSymbols) .* headerSlice));
                ambiguity = obj.pModConfig.PhaseAmbiguity;
                if ambiguity > 0
                    phaseEst = round(phaseEst/ambiguity) * ambiguity;
                end

                phShiftedData = data .* exp(-1i*phaseEst);

                demodOut = obj.pDemodulator(phShiftedData);

                deScrData = obj.pDescrambler( ...
                    demodOut(obj.HeaderLength + (1 : obj.PayloadLength)));

                if obj.Preview
                    output = deScrData;
                elseif obj.PrintOption
                    charSet = int8(bi2de(reshape(deScrData, 7, [])', 'left-msb'));
                    fprintf('%s', char(charSet));
                end

                obj.pBER = obj.pErrorRateCalc(obj.pTargetBits, deScrData);
            end
            BER = obj.pBER;
        end

        function resetImpl(obj)
            reset(obj.pDemodulator);
            reset(obj.pDescrambler);
            reset(obj.pErrorRateCalc);
            obj.pBER = zeros(3, 1);
        end

        function releaseImpl(obj)
            release(obj.pDemodulator);
            release(obj.pDescrambler);
            release(obj.pErrorRateCalc);
            obj.pBER = zeros(3, 1);
        end
    end
end
