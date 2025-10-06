classdef (StrictDefaults)UniversalReceiver < matlab.System
%UniversalReceiver Receiver front-end supporting multiple modulations.
%
%   The implementation mirrors the structure of QPSKReceiver but delegates
%   modulation specific objects to helperModulationConfig and uses the
%   UniversalDataDecoder to recover the payload.
%
% Copyright 2012-2023 The MathWorks, Inc.

    properties (Nontunable)
        ModulationOrder = 4;
        SampleRate = 200000;
        DecimationFactor = 1;
        FrameSize = 1133;
        HeaderLength = 26;
        NumberOfMessage = 20;
        PayloadLength = 2240;
        DesiredPower = 2;
        AveragingLength = 50;
        MaxPowerGain = 60;
        RolloffFactor = 0.5;
        RaisedCosineFilterSpan = 10;
        InputSamplesPerSymbol = 2;
        MaximumFrequencyOffset = 6e3;
        CFCFrequencyResolution = 1000;
        CFCAlgorithm = 'Correlation-based';
        PostFilterOversampling = 2;
        PhaseRecoveryLoopBandwidth = 0.01;
        PhaseRecoveryDampingFactor = 1;
        TimingRecoveryDampingFactor = 1;
        TimingRecoveryLoopBandwidth = 0.01;
        TimingErrorDetectorGain = 5.4;
        PreambleDetectionThreshold = 8;
        DescramblerBase = 2;
        DescramblerPolynomial = [1 1 1 0 1];
        DescramblerInitialConditions = [0 0 0 0];
        BerMask = [];
        PrintOption = false;
        Preview = false;
    end

    properties (Access = private)
        pAGC
        pRxFilter
        pCoarseFreqEstimator
        pCoarseFreqCompensator
        pFineFreqCompensator
        pTimingRec
        pFrameSync
        pDataDecod
        pMeanFreqOff
        pCnt
        pModConfig
        pHeaderSymbols
    end

    properties (Access = private, Constant)
        pBarkerCode = [+1 +1 +1 +1 +1 -1 -1 +1 +1 -1 +1 -1 +1];
    end

    methods
        function obj = UniversalReceiver(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end

    methods (Access = protected)
        function setupImpl(obj, ~)
            obj.pModConfig = helperModulationConfig(obj.ModulationOrder);

            obj.pAGC = comm.AGC( ...
                'DesiredOutputPower',       obj.DesiredPower, ...
                'AveragingLength',          obj.AveragingLength, ...
                'MaxPowerGain',             obj.MaxPowerGain);

            obj.pRxFilter = comm.RaisedCosineReceiveFilter( ...
                'RolloffFactor',            obj.RolloffFactor, ...
                'FilterSpanInSymbols',      obj.RaisedCosineFilterSpan, ...
                'InputSamplesPerSymbol',    obj.InputSamplesPerSymbol, ...
                'DecimationFactor',         obj.DecimationFactor);

            obj.pCoarseFreqEstimator = comm.CoarseFrequencyCompensator( ...
                'Modulation',               obj.pModConfig.CoarseFrequencyModulation, ...
                'Algorithm',                obj.CFCAlgorithm, ...
                'SampleRate',               obj.SampleRate/obj.DecimationFactor);

            if strcmpi(obj.CFCAlgorithm,'FFT-Based')
                obj.pCoarseFreqEstimator.FrequencyResolution = obj.CFCFrequencyResolution;
            else
                obj.pCoarseFreqEstimator.MaximumFrequencyOffset = obj.MaximumFrequencyOffset;
            end

            obj.pCoarseFreqCompensator = comm.PhaseFrequencyOffset( ...
                'PhaseOffset',              0, ...
                'FrequencyOffsetSource',    'Input port', ...
                'SampleRate',               obj.SampleRate/obj.DecimationFactor);

            obj.pMeanFreqOff = 0;
            obj.pCnt = 0;

            obj.pFineFreqCompensator = comm.CarrierSynchronizer( ...
                'Modulation',               obj.pModConfig.CarrierSyncModulation, ...
                'ModulationPhaseOffset',    'Auto', ...
                'SamplesPerSymbol',         obj.PostFilterOversampling, ...
                'DampingFactor',            obj.PhaseRecoveryDampingFactor, ...
                'NormalizedLoopBandwidth',  obj.PhaseRecoveryLoopBandwidth);

            obj.pTimingRec = comm.SymbolSynchronizer( ...
                'TimingErrorDetector',      'Gardner (non-data-aided)', ...
                'SamplesPerSymbol',         obj.PostFilterOversampling, ...
                'DampingFactor',            obj.TimingRecoveryDampingFactor, ...
                'NormalizedLoopBandwidth',  obj.TimingRecoveryLoopBandwidth, ...
                'DetectorGain',             obj.TimingErrorDetectorGain);

            headerBits = repmat(((obj.pBarkerCode + 1)/2)',1,2)';
            headerBits = headerBits(:);
            if length(headerBits) < obj.HeaderLength
                headerBits = [headerBits; zeros(obj.HeaderLength - length(headerBits),1)];
            else
                headerBits = headerBits(1:obj.HeaderLength);
            end
            modObj = obj.pModConfig.ModulatorFactory();
            if isprop(modObj,'OutputDataType')
                modObj.OutputDataType = 'double';
            end
            obj.pHeaderSymbols = modObj(headerBits);

            obj.pFrameSync = FrameSynchronizer( ...
                'Preamble',                 obj.pHeaderSymbols, ...
                'Threshold',                obj.PreambleDetectionThreshold, ...
                'OutputLength',             obj.FrameSize);

            obj.pDataDecod = UniversalDataDecoder( ...
                'ModulationOrder',          obj.ModulationOrder, ...
                'HeaderLength',             obj.HeaderLength, ...
                'NumberOfMessage',          obj.NumberOfMessage, ...
                'PayloadLength',            obj.PayloadLength, ...
                'DescramblerBase',          obj.DescramblerBase, ...
                'DescramblerPolynomial',    obj.DescramblerPolynomial, ...
                'DescramblerInitialConditions', obj.DescramblerInitialConditions, ...
                'BerMask',                  obj.BerMask, ...
                'Preview',                  obj.Preview, ...
                'PrintOption',              obj.PrintOption, ...
                'HeaderSymbols',            obj.pHeaderSymbols);
        end

        function [RCRxSignal,timingRecSignal,fineCompSignal,BER,output] = stepImpl(obj, bufferSignal)
            AGCSignal = obj.pAGC(bufferSignal);
            RCRxSignal = obj.pRxFilter(AGCSignal);
            [~, freqOffsetEst] = obj.pCoarseFreqEstimator(RCRxSignal);
            freqOffsetEst = (freqOffsetEst + obj.pCnt * obj.pMeanFreqOff)/(obj.pCnt+1);
            obj.pCnt = obj.pCnt + 1;
            obj.pMeanFreqOff = freqOffsetEst;

            coarseCompSignal = obj.pCoarseFreqCompensator(RCRxSignal, -freqOffsetEst);
            timingRecSignal = obj.pTimingRec(coarseCompSignal);
            fineCompSignal = obj.pFineFreqCompensator(timingRecSignal);

            [symFrame, isFrameValid] = obj.pFrameSync(fineCompSignal);

            [BER, output] = obj.pDataDecod(symFrame, isFrameValid);
        end

        function resetImpl(obj)
            reset(obj.pAGC);
            reset(obj.pRxFilter);
            reset(obj.pCoarseFreqEstimator);
            reset(obj.pCoarseFreqCompensator);
            reset(obj.pFineFreqCompensator);
            reset(obj.pTimingRec);
            reset(obj.pFrameSync);
            reset(obj.pDataDecod);
            obj.pMeanFreqOff = 0;
            obj.pCnt = 0;
        end

        function releaseImpl(obj)
            release(obj.pAGC);
            release(obj.pRxFilter);
            release(obj.pCoarseFreqEstimator);
            release(obj.pCoarseFreqCompensator);
            release(obj.pFineFreqCompensator);
            release(obj.pTimingRec);
            release(obj.pFrameSync);
            release(obj.pDataDecod);
        end

        function N = getNumOutputsImpl(~)
            N = 5;
        end
    end
end
