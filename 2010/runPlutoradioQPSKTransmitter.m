function runPlutoradioQPSKTransmitter(prmQPSKTransmitter)
%#codegen
%
% Extended Pluto transmitter that supports single-user QPSK and
% superposition-coded NOMA experiments. When the prmQPSKTransmitter struct
% contains the NOMAEnabled flag, the function instantiates one
% QPSKTransmitter System object per user, applies the configured power
% allocation and persists the per-user waveforms for offline SIC
% processing.
%
% Copyright 2017-2024

persistent hTx radio nomaLog
if isempty(hTx)
    % Determine whether the caller configured power-domain NOMA.
    nomaEnabled = isfield(prmQPSKTransmitter, 'NOMAEnabled') && ...
        prmQPSKTransmitter.NOMAEnabled;

    if nomaEnabled
        numUsers = prmQPSKTransmitter.NumUsers;
        hTx = cell(1, numUsers);
        for uIdx = 1:numUsers
            hTx{uIdx} = QPSKTransmitter(...
                'UpsamplingFactor',             prmQPSKTransmitter.Interpolation, ...
                'RolloffFactor',                prmQPSKTransmitter.RolloffFactor, ...
                'RaisedCosineFilterSpan',       prmQPSKTransmitter.RaisedCosineFilterSpan, ...
                'MessageBits',                  prmQPSKTransmitter.UserMessageBits(:, uIdx), ...
                'MessageLength',                prmQPSKTransmitter.MessageLength, ...
                'NumberOfMessage',              prmQPSKTransmitter.NumberOfMessage, ...
                'ScramblerBase',                prmQPSKTransmitter.ScramblerBase, ...
                'ScramblerPolynomial',          prmQPSKTransmitter.ScramblerPolynomial, ...
                'ScramblerInitialConditions',   prmQPSKTransmitter.ScramblerInitialConditions);
        end
    else
        hTx = QPSKTransmitter(...
            'UpsamplingFactor',             prmQPSKTransmitter.Interpolation, ...
            'RolloffFactor',                prmQPSKTransmitter.RolloffFactor, ...
            'RaisedCosineFilterSpan',       prmQPSKTransmitter.RaisedCosineFilterSpan, ...
            'MessageBits',                  prmQPSKTransmitter.MessageBits, ...
            'MessageLength',                prmQPSKTransmitter.MessageLength, ...
            'NumberOfMessage',              prmQPSKTransmitter.NumberOfMessage, ...
            'ScramblerBase',                prmQPSKTransmitter.ScramblerBase, ...
            'ScramblerPolynomial',          prmQPSKTransmitter.ScramblerPolynomial, ...
            'ScramblerInitialConditions',   prmQPSKTransmitter.ScramblerInitialConditions);
    end

    % Create and configure the Pluto System object.
    radio = sdrtx('Pluto');
    radio.RadioID               = prmQPSKTransmitter.Address;
    radio.CenterFrequency       = prmQPSKTransmitter.PlutoCenterFrequency;
    radio.BasebandSampleRate    = prmQPSKTransmitter.PlutoFrontEndSampleRate;
    radio.SamplesPerFrame       = prmQPSKTransmitter.PlutoFrameLength;
    radio.Gain                  = prmQPSKTransmitter.PlutoGain;

    nomaLog = struct('Enabled', nomaEnabled, 'Frames', [], ...
        'PowerAllocation', [], 'Metadata', struct());
    if nomaEnabled
        nomaLog.PowerAllocation = prmQPSKTransmitter.PowerAllocation(:).';
        nomaLog.Metadata.PowerAllocation = nomaLog.PowerAllocation;
        nomaLog.Metadata.FrameSize = prmQPSKTransmitter.FrameSize;
        nomaLog.Metadata.HeaderLength = prmQPSKTransmitter.HeaderLength;
        nomaLog.Metadata.PayloadLength = prmQPSKTransmitter.PayloadLength;
        nomaLog.Metadata.NumberOfMessage = prmQPSKTransmitter.NumberOfMessage;
        nomaLog.Metadata.MessageLength = prmQPSKTransmitter.MessageLength;
        nomaLog.Metadata.ModulationOrder = prmQPSKTransmitter.ModulationOrder;
        nomaLog.Metadata.ScramblerBase = prmQPSKTransmitter.ScramblerBase;
        nomaLog.Metadata.ScramblerPolynomial = prmQPSKTransmitter.ScramblerPolynomial;
        nomaLog.Metadata.ScramblerInitialConditions = ...
            prmQPSKTransmitter.ScramblerInitialConditions;
        nomaLog.Metadata.ModulatedHeader = prmQPSKTransmitter.ModulatedHeader;
        if isfield(prmQPSKTransmitter, 'PreambleDetectionThreshold')
            nomaLog.Metadata.PreambleDetectionThreshold = ...
                prmQPSKTransmitter.PreambleDetectionThreshold;
        else
            nomaLog.Metadata.PreambleDetectionThreshold = 0.8;
        end
        nomaLog.Metadata.UserNames = prmQPSKTransmitter.UserNames;
        nomaLog.Metadata.MessageBits = prmQPSKTransmitter.UserMessageBits;
        nomaLog.Metadata.PlutoFrontEndSampleRate = ...
            prmQPSKTransmitter.PlutoFrontEndSampleRate;
        nomaLog.Metadata.PlutoFrameLength = prmQPSKTransmitter.PlutoFrameLength;
    end
end

currentTime = 0;
disp('Transmission has started')

while currentTime < prmQPSKTransmitter.StopTime
    if iscell(hTx)
        numUsers = numel(hTx);
        userSignals = cell(1, numUsers);
        for uIdx = 1:numUsers
            userSignals{uIdx} = step(hTx{uIdx});
        end

        sqrtPower = sqrt(prmQPSKTransmitter.PowerAllocation(:));
        data = zeros(size(userSignals{1}));
        for uIdx = 1:numUsers
            data = data + sqrtPower(uIdx) * userSignals{uIdx};
        end

        if nomaLog.Enabled
            frameLog = struct('Composite', data, 'Users', []);
            frameLog.Users = repmat(struct('Symbols', [], 'Bits', []), 1, numUsers);
            for uIdx = 1:numUsers
                frameLog.Users(uIdx).Symbols = userSignals{uIdx};
                frameLog.Users(uIdx).Bits = prmQPSKTransmitter.UserMessageBits(:, uIdx);
            end
            nomaLog.Frames = [nomaLog.Frames frameLog]; %#ok<AGROW>
        end
    else
        data = step(hTx);
    end

    % Stream the composite waveform to the radio front end.
    step(radio, data);

    % Update simulation time
    currentTime = currentTime + prmQPSKTransmitter.FrameTime;
end

if currentTime ~= 0
    disp('Transmission has ended')
end

% Release transmitter objects and plot the final transmitted frame for
% visual inspection.
if iscell(hTx)
    for uIdx = 1:numel(hTx)
        release(hTx{uIdx});
    end
    hTx = [];
else
    release(hTx);
    hTx = [];
end
release(radio);

if exist('data', 'var')
    figure;
    plot(data, 'o');
    title(' final Transmitted data')
end

if nomaLog.Enabled
    logFile = 'noma_tx_log.mat';
    if isfield(prmQPSKTransmitter, 'TransmitLogFile') && ...
            ~isempty(prmQPSKTransmitter.TransmitLogFile)
        logFile = prmQPSKTransmitter.TransmitLogFile;
    end

    nomaLog.Metadata.GeneratedOn = datetime('now');
    save(logFile, 'nomaLog', 'prmQPSKTransmitter');
    fprintf('Saved NOMA transmit log to %s\n', logFile);
end
end
