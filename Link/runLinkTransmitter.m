function stats = runLinkTransmitter(tx, common)
%runLinkTransmitter Execute the ADALM-PLUTO transmitter chain
%
%   STATS = runLinkTransmitter(TX, COMMON) generates deterministic frames
%   using the parameters contained in TX and COMMON, applies pulse shaping,
%   and streams the resulting waveform through the specified Pluto radio.
%   The returned STATS structure summarizes the transmitted signal.

    arguments
        tx struct
        common struct
    end

    [modulator, bitsPerSymbol, constellation] = createModulator(common.modulation);

    basebandSampleRate = common.symbolRate * common.samplesPerSymbol;
    frameSymbolCount   = common.frameLength;
    frameSampleCount   = frameSymbolCount * common.samplesPerSymbol;
    frameBitCount      = frameSymbolCount * bitsPerSymbol;

    fprintf("Transmitter configuration\n");
    fprintf("  Center frequency : %.3f GHz\n", tx.centerFrequency/1e9);
    fprintf("  Baseband rate    : %.3f Msps\n", basebandSampleRate/1e6);
    fprintf("  Modulation       : %s (%d bits/symbol)\n", common.modulation, bitsPerSymbol);
    fprintf("  Frame length     : %d symbols (%d samples)\n", frameSymbolCount, frameSampleCount);

    txFilter = comm.RaisedCosineTransmitFilter( ...
        "RolloffFactor", common.rolloff, ...
        "FilterSpanInSymbols", common.filterSpan, ...
        "OutputSamplesPerSymbol", common.samplesPerSymbol);

    % Normalize filter output to unit average power
    txFilter.Gain = 1 / sqrt(sum(abs(constellation).^2) / numel(constellation));

    txRadio = comm.SDRTxPluto( ...
        "RadioID",            tx.radioID, ...
        "CenterFrequency",    tx.centerFrequency, ...
        "BasebandSampleRate", basebandSampleRate, ...
        "Gain",               tx.gain);

    randStream = RandStream('mt19937ar', 'Seed', common.randomSeed);

    framesToSend = tx.framesToSend;
    isContinuous = isinf(framesToSend);
    if isContinuous
        fprintf("Starting continuous transmission. Press Ctrl+C in MATLAB to stop.\n");
    else
        fprintf("Preparing to send %d frame(s).\n", framesToSend);
    end

    release(txRadio);
    cleanupObj = onCleanup(@()release(txRadio)); %#ok<NASGU>

    framesSent = 0;
    startTime = tic;

    while isContinuous || framesSent < framesToSend
        frameBits = randi(randStream, [0 1], frameBitCount, 1);
        symbols   = bitsToSymbols(frameBits, bitsPerSymbol);
        waveform  = modulator(symbols);
        shaped    = txFilter(waveform);
        txRadio(complex(single(real(shaped)), single(imag(shaped))));
        framesSent = framesSent + 1;

        if ~isContinuous && mod(framesSent, 10) == 0 && framesToSend >= 10
            fprintf("  Frames transmitted: %d/%d\n", framesSent, framesToSend);
        elseif isContinuous && mod(framesSent, 100) == 0
            fprintf("  Continuous frames transmitted: %d\n", framesSent);
        end
    end

    elapsed = toc(startTime);

    stats = struct();
    stats.framesTransmitted = framesSent;
    stats.frameLength       = frameSymbolCount;
    stats.samplesPerFrame   = frameSampleCount;
    stats.bitsPerFrame      = frameBitCount;
    stats.elapsedSeconds    = elapsed;
    if elapsed > 0
        stats.effectiveSymbolRate = framesSent * frameSymbolCount / elapsed;
    else
        stats.effectiveSymbolRate = NaN;
    end

    fprintf("Transmission complete.\n");
    fprintf("  Frames sent        : %d\n", stats.framesTransmitted);
    if ~isnan(stats.effectiveSymbolRate)
        fprintf("  Effective sym rate : %.3f Msps\n", stats.effectiveSymbolRate/1e6);
    else
        fprintf("  Effective sym rate : N/A\n");
    end
end
