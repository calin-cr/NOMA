classdef (StrictDefaults) QPSKTransmitter < matlab.System
% Two-user NOMA QPSK Transmitter
% x = sqrt(P1)*s1 + sqrt(P2)*s2

    properties (Nontunable)
        UpsamplingFactor = 2
        ScramblerBase = 2
        ScramblerPolynomial = [1 1 1 0 1]
        ScramblerInitialConditions = [0 0 0 0]
        RolloffFactor = 0.5
        RaisedCosineFilterSpan = 10
        NumberOfMessage = 10
        MessageLength = 16
        MessageBitsUser1 = []
        MessageBitsUser2 = []
        PowerUser1 = 0.8
        PowerUser2 = 0.2
    end

    % Read-only public outputs to save ground-truth bits
    properties (SetAccess=private)
        LastBitsUser1
        LastBitsUser2
    end

    properties (Access=private)
        pBitGenerator1
        pBitGenerator2
        pQPSKModulator1
        pQPSKModulator2
        pTransmitterFilter
    end

    methods
        function obj = QPSKTransmitter(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end

    methods (Access=protected)
        function setupImpl(obj)
            obj.pBitGenerator1 = QPSKBitsGenerator( ...
                'NumberOfMessage', obj.NumberOfMessage, ...
                'MessageLength', obj.MessageLength, ...
                'MessageBits', obj.MessageBitsUser1, ...
                'ScramblerBase', obj.ScramblerBase, ...
                'ScramblerPolynomial', obj.ScramblerPolynomial, ...
                'ScramblerInitialConditions', obj.ScramblerInitialConditions);

            obj.pBitGenerator2 = QPSKBitsGenerator( ...
                'NumberOfMessage', obj.NumberOfMessage, ...
                'MessageLength', obj.MessageLength, ...
                'MessageBits', obj.MessageBitsUser2, ...
                'ScramblerBase', obj.ScramblerBase, ...
                'ScramblerPolynomial', obj.ScramblerPolynomial, ...
                'ScramblerInitialConditions', obj.ScramblerInitialConditions);

            obj.pQPSKModulator1 = comm.QPSKModulator('BitInput',true,'PhaseOffset',pi/4);
            obj.pQPSKModulator2 = comm.QPSKModulator('BitInput',true,'PhaseOffset',pi/4);

            obj.pTransmitterFilter = comm.RaisedCosineTransmitFilter( ...
                'RolloffFactor', obj.RolloffFactor, ...
                'FilterSpanInSymbols', obj.RaisedCosineFilterSpan, ...
                'OutputSamplesPerSymbol', obj.UpsamplingFactor);
        end

        function txSig = stepImpl(obj)
            [bits1, ~] = obj.pBitGenerator1();
            [bits2, ~] = obj.pBitGenerator2();
            obj.LastBitsUser1 = bits1;
            obj.LastBitsUser2 = bits2;

            s1 = obj.pQPSKModulator1(bits1);
            s2 = obj.pQPSKModulator2(bits2);

            Psum = obj.PowerUser1 + obj.PowerUser2;
            P1 = obj.PowerUser1 / Psum;
            P2 = obj.PowerUser2 / Psum;

            x = sqrt(P1)*s1 + sqrt(P2)*s2;
            txSig = obj.pTransmitterFilter(x);
        end

        function resetImpl(obj)
            reset(obj.pBitGenerator1);
            reset(obj.pBitGenerator2);
            reset(obj.pQPSKModulator1);
            reset(obj.pQPSKModulator2);
            reset(obj.pTransmitterFilter);
        end

        function releaseImpl(obj)
            release(obj.pBitGenerator1);
            release(obj.pBitGenerator2);
            release(obj.pQPSKModulator1);
            release(obj.pQPSKModulator2);
            release(obj.pTransmitterFilter);
        end

        function N = getNumInputsImpl(~), N = 0; end
    end
end
