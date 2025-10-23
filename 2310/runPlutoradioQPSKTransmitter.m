function runPlutoradioQPSKTransmitter(prmQPSKTransmitter)
% Two-user NOMA QPSK Pluto transmitter (saves data+reference bits once)

persistent hTx radio
if isempty(hTx)
    hTx = QPSKTransmitter(...
        'UpsamplingFactor',             prmQPSKTransmitter.Interpolation, ...
        'RolloffFactor',                prmQPSKTransmitter.RolloffFactor, ...
        'RaisedCosineFilterSpan',       prmQPSKTransmitter.RaisedCosineFilterSpan, ...
        'MessageBitsUser1',             prmQPSKTransmitter.MessageBitsUser1, ...
        'MessageBitsUser2',             prmQPSKTransmitter.MessageBitsUser2, ...
        'MessageLength',                prmQPSKTransmitter.MessageLength, ...
        'NumberOfMessage',              prmQPSKTransmitter.NumberOfMessage, ...
        'ScramblerBase',                prmQPSKTransmitter.ScramblerBase, ...
        'ScramblerPolynomial',          prmQPSKTransmitter.ScramblerPolynomial, ...
        'ScramblerInitialConditions',   prmQPSKTransmitter.ScramblerInitialConditions, ...
        'PowerUser1',                   0.8, ...
        'PowerUser2',                   0.2);

    radio = sdrtx('Pluto');
    radio.RadioID            = prmQPSKTransmitter.Address;
    radio.CenterFrequency    = prmQPSKTransmitter.PlutoCenterFrequency;
    radio.BasebandSampleRate = prmQPSKTransmitter.PlutoFrontEndSampleRate;
    radio.SamplesPerFrame    = prmQPSKTransmitter.PlutoFrameLength;
    radio.Gain               = prmQPSKTransmitter.PlutoGain;
end

disp('NOMA QPSK Transmission started...')
currentTime = 0; saved = false;

while currentTime < prmQPSKTransmitter.StopTime
    data = step(hTx);

    if ~saved
        saved = true;
        bitsUser1 = hTx.LastBitsUser1;
        bitsUser2 = hTx.LastBitsUser2;
        save('NOMA_QPSK_txData.mat','data','prmQPSKTransmitter', ...
             'bitsUser1','bitsUser2','-v7.3');
        disp('Saved: NOMA_QPSK_txData.mat (composite + reference bits)');
    end

    step(radio, data);
    currentTime = currentTime + prmQPSKTransmitter.FrameTime;
end

disp('Transmission ended.')
release(hTx); release(radio);
end
