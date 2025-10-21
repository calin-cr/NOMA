function BER = runPlutoradioQPSKReceiver(prmQPSKReceiver, printData, samplenum)
% Extended Pluto receiver that can optionally persist raw IQ snapshots for
% offline successive interference cancellation experiments. When
% prmQPSKReceiver.LogCaptures is true, the function saves per-frame data to
% the requested MAT-file, including the synchronized constellation and the
% descrambled payload bits (when Preview mode is enabled).
%
% Copyright 2017-2024

persistent rx radio constDiag captureLog loggingEnabled
if isempty(rx)
    previewFlag = isfield(prmQPSKReceiver, 'EnablePreview') && ...
        prmQPSKReceiver.EnablePreview;

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
        'PrintOption',                          printData, ...
        'Preview',                              previewFlag);

    % Create and configure the Pluto System object. When the Analog Devices
    % libiio library is not available (for example, on a host without the SDR
    % support package installed), provide a descriptive error that callers can
    % catch to fall back to offline processing.
    try
        radio = sdrrx('Pluto');
    catch ME
        % Ensure persistent state does not remain partially initialized.
        if exist('rx', 'var') && ~isempty(rx)
            release(rx);
        end
        rx = [];
        constDiag = [];
        captureLog = [];
        loggingEnabled = false;

        if strcmp(ME.identifier, 'MATLAB:loadlibrary:LibraryNotFound') || ...
                contains(ME.message, 'Library was not found')
            newME = MException('runPlutoradioQPSKReceiver:PlutoUnavailable', ...
                ['Unable to load the Analog Devices libiio library. ', ...
                'Install the Communications Toolbox Support Package for ', ...
                'ADI ADALM-PLUTO Radio and ensure the shared libraries are ', ...
                'on the system path to run live captures.']);
            newME = newME.addCause(ME);
            throw(newME);
        end

        rethrow(ME);
    end

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

    loggingEnabled = isfield(prmQPSKReceiver, 'LogCaptures') && ...
        prmQPSKReceiver.LogCaptures;
    if loggingEnabled
        captureLog = struct('Metadata', struct(), 'Frames', []);
        captureLog.Metadata.ReceiverParams = prmQPSKReceiver;
        captureLog.Metadata.GeneratedOn = datetime('now');
        if isfield(prmQPSKReceiver, 'CaptureScenario') && ...
                ~isempty(prmQPSKReceiver.CaptureScenario)
            captureLog.Metadata.Scenario = prmQPSKReceiver.CaptureScenario;
        else
            captureLog.Metadata.Scenario = sprintf('capture_%d', samplenum);
        end
        if isfield(prmQPSKReceiver, 'PowerAllocation')
            captureLog.Metadata.PowerAllocation = prmQPSKReceiver.PowerAllocation;
        end
        captureLog.Metadata.FrameSize = prmQPSKReceiver.FrameSize;
        captureLog.Metadata.HeaderLength = prmQPSKReceiver.HeaderLength;
        captureLog.Metadata.PayloadLength = prmQPSKReceiver.PayloadLength;
        captureLog.Metadata.ModulatedHeader = prmQPSKReceiver.ModulatedHeader;
    end
end

% Initialize variables
currentTime = 0;
BER = [];
numFrames = floor(prmQPSKReceiver.StopTime * ...
    radio.BasebandSampleRate / radio.SamplesPerFrame);
rcvdSignal = complex(zeros(prmQPSKReceiver.PlutoFrameLength, numFrames));

cnt = 1;
while currentTime <  prmQPSKReceiver.StopTime && cnt <= numFrames

    rcvdSignal(:,cnt) = radio();   % Receive signal from the radio

    % Decode the received message and capture the synchronized signal.
    [rrcSignal, timingRecSignal, fineCompSignal, BER, previewBits] = ...
        rx(rcvdSignal(:,cnt));

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

    if loggingEnabled
        frameLog = struct();
        frameLog.Raw = rcvdSignal(:,cnt);
        frameLog.RRC = rrcSignal;
        frameLog.TimingRecovered = timingRecSignal;
        frameLog.FineCompensated = fineCompSignal;
        frameLog.BER = BER;
        if ~isempty(previewBits)
            frameLog.DescrambledBits = previewBits;
        end
        captureLog.Frames = [captureLog.Frames frameLog]; %#ok<AGROW>
    end

    % Update simulation time
    currentTime = currentTime + (radio.SamplesPerFrame / radio.BasebandSampleRate);
    cnt = cnt + 1;
end

release(rx);
release(radio);
rx = [];
radio = [];
if ~isempty(constDiag)
    release(constDiag);
    constDiag = [];
end

if loggingEnabled
    captureFile = '';
    if isfield(prmQPSKReceiver, 'CaptureFilename') && ...
            ~isempty(prmQPSKReceiver.CaptureFilename)
        captureFile = prmQPSKReceiver.CaptureFilename;
    end
    if isempty(captureFile)
        captureFile = sprintf('noma_capture_%s.mat', ...
            datestr(now, 'yyyymmdd_HHMMSS'));
    end

    save(captureFile, 'captureLog', 'prmQPSKReceiver');
    fprintf('Saved capture log to %s\n', captureFile);
    captureLog = [];
    loggingEnabled = false;
end
end
