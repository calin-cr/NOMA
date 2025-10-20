function BER = runPlutoradioQPSKReceiver(prmQPSKReceiver, printData, samplenum)

%   Copyright 2017-2022 The MathWorks, Inc.


persistent rx radio constDiag;
if isempty(rx)
    rx  = QPSKReceiver(...
        'ModulationOrder',                      prmQPSKReceiver.ModulationOrder, ...
        'SampleRate',                           prmQPSKReceiver.Fs, ...
        'DecimationFactor',                     prmQPSKReceiver.Decimation, ...
        'FrameSize',                            prmQPSKReceiver.FrameSize, ...
        'HeaderLength',                         prmQPSKReceiver.HeaderLength, ...
        'NumberOfMessage',                      prmQPSKReceiver.NumberOfMessage, ...
        'PayloadLength',                        prmQPSKReceiver.PayloadLength, ...
        'DesiredPower',                         prmQPSKReceiver.DesiredPower, ...
        'AveragingLength',                      prmQPSKReceiver.AveragingLength, ...
        'MaxPowerGain',                         prmQPSKReceiver.MaxPowerGain, ...
        'RolloffFactor',                        prmQPSKReceiver.RolloffFactor, ...
        'RaisedCosineFilterSpan',               prmQPSKReceiver.RaisedCosineFilterSpan, ...
        'InputSamplesPerSymbol',                prmQPSKReceiver.Interpolation, ...
        'MaximumFrequencyOffset',               prmQPSKReceiver.MaximumFrequencyOffset, ...
        'PostFilterOversampling',               prmQPSKReceiver.Interpolation/prmQPSKReceiver.Decimation, ...
        'PhaseRecoveryLoopBandwidth',           prmQPSKReceiver.PhaseRecoveryLoopBandwidth, ...
        'PhaseRecoveryDampingFactor',           prmQPSKReceiver.PhaseRecoveryDampingFactor, ...
        'TimingRecoveryDampingFactor',          prmQPSKReceiver.TimingRecoveryDampingFactor, ...
        'TimingRecoveryLoopBandwidth',          prmQPSKReceiver.TimingRecoveryLoopBandwidth, ...
        'TimingErrorDetectorGain',              prmQPSKReceiver.TimingErrorDetectorGain, ...
        'PreambleDetectionThreshold',           prmQPSKReceiver.PreambleDetectionThreshold, ...
        'DescramblerBase',                      prmQPSKReceiver.ScramblerBase, ...
        'DescramblerPolynomial',                prmQPSKReceiver.ScramblerPolynomial, ...
        'DescramblerInitialConditions',         prmQPSKReceiver.ScramblerInitialConditions,...
        'BerMask',                              prmQPSKReceiver.BerMask, ...
        'PrintOption',                          printData);
    
    % Create and configure the Pluto System object.
    radio = sdrrx('Pluto');
    radio.RadioID               = prmQPSKReceiver.Address;
    radio.CenterFrequency       = prmQPSKReceiver.PlutoCenterFrequency;
    radio.BasebandSampleRate    = prmQPSKReceiver.PlutoFrontEndSampleRate;
    radio.SamplesPerFrame       = prmQPSKReceiver.PlutoFrameLength;
    radio.GainSource            = 'Manual';
    radio.Gain                  = prmQPSKReceiver.PlutoGain;
    radio.OutputDataType        = 'double';

    % Create a constellation diagram object to visualize the received
    % frames. Use a persistent System object so that a single figure is
    % updated for each frame that is processed.
    constDiag = comm.ConstellationDiagram( ...
        'Name', 'Received Signal Constellation', ...
        'ShowLegend', true, ...
        'ShowReferenceConstellation', false, ...
        'XLimits', [-2 2], ...
        'YLimits', [-2 2]);
end

% Initialize variables
currentTime = 0;
BER = [];
num_frames = floor(prmQPSKReceiver.StopTime*radio.BasebandSampleRate/radio.SamplesPerFrame)
rcvdSignal = complex(zeros(prmQPSKReceiver.PlutoFrameLength,1),num_frames);
num_frames = floor(prmQPSKReceiver.StopTime * radio.BasebandSampleRate / radio.SamplesPerFrame);
rcvdSignal = complex(zeros(prmQPSKReceiver.PlutoFrameLength, num_frames), ...
    zeros(prmQPSKReceiver.PlutoFrameLength, num_frames));

cnt = 1;
while currentTime <  prmQPSKReceiver.StopTime && cnt<=num_frames
    
    rcvdSignal(:,cnt) = radio();   % Receive signal from the radio

    % Decode the received message and capture the synchronized signal.
    [rrcSignal, timingRecSignal, fineCompSignal, BER, ~] = rx(rcvdSignal(:,cnt));

    % Update the constellation diagram with the synchronized frame just
    % before decoding.
    if ~isempty(constDiag)
        constDiag(fineCompSignal);
    end

    % Optionally print diagnostic metrics that summarize how the signal evolves
    % through the receive chain. Toggle this via prmQPSKReceiver.LogSignalMetrics.
    if isfield(prmQPSKReceiver, 'LogSignalMetrics') && prmQPSKReceiver.LogSignalMetrics
        frontEndRMS = sqrt(mean(abs(rcvdSignal(:,cnt)).^2));
        rrcRMS = sqrt(mean(abs(rrcSignal).^2));
        timingRMS = sqrt(mean(abs(timingRecSignal).^2));
        fineRMS = sqrt(mean(abs(fineCompSignal).^2));

        validSamples = abs(fineCompSignal) > 0;
        metricsPrinted = false;
        if any(validSamples)
            sym = fineCompSignal(validSamples);
            constPoints = (1/sqrt(2)) * [1+1j; 1-1j; -1+1j; -1-1j];
            [~, decisionIdx] = min(abs(sym - constPoints.'), [], 2);
            decisions = constPoints(decisionIdx);
            errorVector = sym - decisions;

            evmRMS = sqrt(mean(abs(errorVector).^2));
            decisionRMS = sqrt(mean(abs(decisions).^2));
            if decisionRMS > 0
                evmPercent = 100 * evmRMS / decisionRMS;
                snrEstimate = 20 * log10(decisionRMS / evmRMS);
            else
                evmPercent = NaN;
                snrEstimate = NaN;
            end

            centroid = mean(sym);
            rmsI = rms(real(sym));
            rmsQ = rms(imag(sym));
            if rmsQ > 0
                amplitudeImbalance = 20 * log10(rmsI / rmsQ);
            else
                amplitudeImbalance = Inf;
            end
            phaseStdDeg = rad2deg(std(angle(sym)));

            fprintf('\nFrame %d diagnostics:\n', cnt);
            fprintf('  Front-end RMS: %.3f\n', frontEndRMS);
            fprintf('  RRC output RMS: %.3f\n', rrcRMS);
            fprintf('  Timing-recovered RMS: %.3f\n', timingRMS);
            fprintf('  Carrier-synchronized RMS: %.3f\n', fineRMS);
            fprintf('  EVM (RMS): %.2f %% | Estimated SNR: %.2f dB\n', evmPercent, snrEstimate);
            fprintf('  Constellation centroid: %.3f%+.3fj\n', real(centroid), imag(centroid));
            fprintf('  I/Q amplitude imbalance: %.2f dB | Phase std: %.2f deg\n', amplitudeImbalance, phaseStdDeg);

            metricsPrinted = true;
        end

        if ~metricsPrinted
            fprintf('\nFrame %d diagnostics: metrics unavailable (no valid symbols detected).\n', cnt);
        end
    end
    %load RxData_Rsym_200000_Mod_4_veryclose.mat rcvdSignal
    
    % Decode the received message
    [~, ~, ~, BER] = rx(rcvdSignal(:,cnt));
    
    % Update simulation time
    currentTime=currentTime+(radio.SamplesPerFrame / radio.BasebandSampleRate);
    cnt = cnt+1;
end

release(rx);
release(radio);
if ~isempty(constDiag)
    release(constDiag);
end

% filename = ['RxData_Rsym_' num2str(prmQPSKReceiver.Rsym) '_Mod_' num2str(prmQPSKReceiver.ModulationOrder) '_BER_' num2str(ceil(BER(1)*100)) '_sample_' num2str(samplenum) '_veryclose'];
% save(filename) 