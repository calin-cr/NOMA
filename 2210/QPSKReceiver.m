classdef (StrictDefaults)QPSKReceiver < matlab.System
    %

    % Copyright 2012-2023 The MathWorks, Inc.
    
    properties (Nontunable)
        ModulationOrder = 4;
        SampleRate = 200000;
        DecimationFactor = 1;
        FrameSize = 1133;
        HeaderLength = 13;
        NumberOfMessage = 20;
        PayloadLength = 2240;
        DesiredPower = 2
        AveragingLength = 50
        MaxPowerGain = 20
        RolloffFactor = 0.5
        RaisedCosineFilterSpan = 10
        InputSamplesPerSymbol = 2
        MaximumFrequencyOffset = 6e3
        CFCFrequencyResolution = 1000
        CFCAlgorithm = 'Correlation-based'
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
    end
    
    properties (Access = private, Constant)
        pUpdatePeriod = 4 % Defines the size of vector that will be processed in AGC system object
        pModulatedHeader = sqrt(2)/2 * (-1-1i) * [+1; +1; +1; +1; +1; -1; -1; +1; +1; -1; +1; -1; +1];
        pMessage = 'Hello world';
        pMessageLength = 16;
    end
    
    methods
        function obj = QPSKReceiver(varargin)
            setProperties(obj,nargin,varargin{:});
        end
    end
    
    methods (Access = protected)
        function setupImpl(obj, ~)
            
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
                'Modulation',               'QPSK', ...
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
                'Modulation',               'QPSK', ...
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
            
            obj.pFrameSync = FrameSynchronizer( ...
                'Preamble',                 obj.pModulatedHeader, ...
                'Threshold',                obj.PreambleDetectionThreshold, ...
                'OutputLength',             obj.FrameSize);
            
            obj.pDataDecod = QPSKDataDecoder( ...
                'ModulationOrder',          obj.ModulationOrder, ...
                'HeaderLength',             obj.HeaderLength, ...
                'NumberOfMessage',          obj.NumberOfMessage, ...
                'PayloadLength',            obj.PayloadLength, ...
                'DescramblerBase',          obj.DescramblerBase, ...
                'DescramblerPolynomial',    obj.DescramblerPolynomial, ...
                'DescramblerInitialConditions', obj.DescramblerInitialConditions, ...
                'BerMask',                  obj.BerMask, ...
                'Preview',                  obj.Preview, ...
                'PrintOption',              obj.PrintOption);
        end
        
        function [RCRxSignal,timingRecSignal,fineCompSignal,BER,output] = stepImpl(obj, bufferSignal)
            
            AGCSignal = obj.pAGC(bufferSignal);                          % AGC control
            RCRxSignal = obj.pRxFilter(AGCSignal);                       % Pass the signal through
                                                                         % Square-Root Raised Cosine Received Filter
            [~, freqOffsetEst] = obj.pCoarseFreqEstimator(RCRxSignal);   % Coarse frequency offset estimation
            % average coarse frequency offset estimate, so that carrier
            % sync is able to lock/converge
            freqOffsetEst = (freqOffsetEst + obj.pCnt * obj.pMeanFreqOff)/(obj.pCnt+1);
            obj.pCnt = obj.pCnt + 1;            % update state
            obj.pMeanFreqOff = freqOffsetEst;
            
            coarseCompSignal = obj.pCoarseFreqCompensator(RCRxSignal,...
                -freqOffsetEst);                                         % Coarse frequency compensation
            timingRecSignal = obj.pTimingRec(coarseCompSignal);          % Symbol timing recovery
            
            fineCompSignal = obj.pFineFreqCompensator(timingRecSignal);  % Fine frequency compensation
            
            [symFrame, isFrameValid] = obj.pFrameSync(fineCompSignal);   % Frame synchronization
            
            %figure;
            %plot(symFrame,'o');
            %title('Received Signal')

            
            %% 
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

