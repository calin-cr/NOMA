classdef (StrictDefaults) QPSKTransmitter_NOMA < matlab.System
%QPSKTransmitter_NOMA Generate a two-user NOMA QPSK waveform.
%
%   This System object builds on the example QPSK transmitter by
%   superimposing two independently encoded QPSK users with configurable
%   power allocation. Each user shares the same raised cosine filtering,
%   frame structure (Barker header + scrambled payload), and Pluto SDR
%   interface as the legacy single-user design.
%
%   The composite transmit signal is:
%       x(t) = sqrt(P1) * s1(t) + sqrt(P2) * s2(t)
%   where P1 + P2 = 1 and P1 > P2.
%
%   See also createNOMAUserConfig, QPSKTransmitter.

%   Copyright 2024

    properties (Nontunable)
        UpsamplingFactor = 2;
        RolloffFactor = 0.5;
        RaisedCosineFilterSpan = 10;
        ScramblerBase = 2;
        ScramblerPolynomial = [1 1 1 0 1];
        ScramblerInitialConditions = [0 0 0 0];
        NumberOfMessages = 100;
        Message1 = "Hello world";
        Message2 = "Chao world";
        PowerUser1 = 0.8;
        PowerUser2 = 0.2;
    end

    properties (Access = private)
        pUser1Cfg
        pUser2Cfg
        pPayloadSrc1
        pPayloadSrc2
        pScrambler1
        pScrambler2
        pQPSKMod1
        pQPSKMod2
        pTxFilter1
        pTxFilter2
    end

    methods
        function obj = QPSKTransmitter_NOMA(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end

    methods (Access = protected)
        function setupImpl(obj)
            validateattributes(obj.PowerUser1, {'double'}, {'real','scalar','positive'});
            validateattributes(obj.PowerUser2, {'double'}, {'real','scalar','positive'});
            if abs((obj.PowerUser1 + obj.PowerUser2) - 1) > 1e-6
                error('QPSKTransmitter_NOMA:PowerAllocation', ...
                    'Power coefficients must sum to one.');
            end
            if obj.PowerUser1 <= obj.PowerUser2
                error('QPSKTransmitter_NOMA:PowerOrdering', ...
                    'PowerUser1 must be strictly greater than PowerUser2.');
            end

            % Create deterministic frame configurations for both users
            maxChars = max(strlength(obj.Message1), strlength(obj.Message2));
            obj.pUser1Cfg = createNOMAUserConfig(char(obj.Message1), obj.NumberOfMessages, maxChars);
            obj.pUser2Cfg = createNOMAUserConfig(char(obj.Message2), obj.NumberOfMessages, maxChars);

            % Payload sources repeat the formatted message blocks
            obj.pPayloadSrc1 = dsp.SignalSource(obj.pUser1Cfg.PayloadBits, ...
                'SamplesPerFrame', obj.pUser1Cfg.PayloadBitCount, ...
                'SignalEndAction', 'Cyclic repetition');
            obj.pPayloadSrc2 = dsp.SignalSource(obj.pUser2Cfg.PayloadBits, ...
                'SamplesPerFrame', obj.pUser2Cfg.PayloadBitCount, ...
                'SignalEndAction', 'Cyclic repetition');

            % Scramblers match the legacy example parameters
            obj.pScrambler1 = comm.Scrambler(obj.ScramblerBase, ...
                obj.ScramblerPolynomial, obj.ScramblerInitialConditions);
            obj.pScrambler2 = comm.Scrambler(obj.ScramblerBase, ...
                obj.ScramblerPolynomial, obj.ScramblerInitialConditions);

            % QPSK modulators
            obj.pQPSKMod1 = comm.QPSKModulator('BitInput', true, ...
                'PhaseOffset', pi/4, 'OutputDataType', 'double');
            obj.pQPSKMod2 = comm.QPSKModulator('BitInput', true, ...
                'PhaseOffset', pi/4, 'OutputDataType', 'double');

            % Raised cosine filters (same parameters as legacy transmitter)
            obj.pTxFilter1 = comm.RaisedCosineTransmitFilter( ...
                'RolloffFactor', obj.RolloffFactor, ...
                'FilterSpanInSymbols', obj.RaisedCosineFilterSpan, ...
                'OutputSamplesPerSymbol', obj.UpsamplingFactor);
            obj.pTxFilter2 = comm.RaisedCosineTransmitFilter( ...
                'RolloffFactor', obj.RolloffFactor, ...
                'FilterSpanInSymbols', obj.RaisedCosineFilterSpan, ...
                'OutputSamplesPerSymbol', obj.UpsamplingFactor);
        end

        function transmittedSignal = stepImpl(obj)
            % User 1 (high-power / weak user)
            payloadBits1 = obj.pPayloadSrc1();
            scrambledPayload1 = obj.pScrambler1(payloadBits1);
            frameBits1 = [obj.pUser1Cfg.HeaderBits; scrambledPayload1];
            symbols1 = obj.pQPSKMod1(frameBits1);
            waveform1 = obj.pTxFilter1(symbols1);

            % User 2 (low-power / strong user)
            payloadBits2 = obj.pPayloadSrc2();
            scrambledPayload2 = obj.pScrambler2(payloadBits2);
            frameBits2 = [obj.pUser2Cfg.HeaderBits; scrambledPayload2];
            symbols2 = obj.pQPSKMod2(frameBits2);
            waveform2 = obj.pTxFilter2(symbols2);

            transmittedSignal = sqrt(obj.PowerUser1) * waveform1 + ...
                sqrt(obj.PowerUser2) * waveform2;
        end

        function resetImpl(obj)
            reset(obj.pPayloadSrc1);
            reset(obj.pPayloadSrc2);
            reset(obj.pScrambler1);
            reset(obj.pScrambler2);
            reset(obj.pQPSKMod1);
            reset(obj.pQPSKMod2);
            reset(obj.pTxFilter1);
            reset(obj.pTxFilter2);
        end

        function releaseImpl(obj)
            release(obj.pPayloadSrc1);
            release(obj.pPayloadSrc2);
            release(obj.pScrambler1);
            release(obj.pScrambler2);
            release(obj.pQPSKMod1);
            release(obj.pQPSKMod2);
            release(obj.pTxFilter1);
            release(obj.pTxFilter2);
        end

        function num = getNumInputsImpl(~)
            num = 0;
        end
    end
end
