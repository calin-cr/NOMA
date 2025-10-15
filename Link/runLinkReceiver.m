function stats = runLinkReceiver(rx, common)
%runLinkReceiver Execute the ADALM-PLUTO receiver chain and compute BER
%
%   STATS = runLinkReceiver(RX, COMMON) captures frames from the Pluto radio,
%   performs timing/carrier recovery and demodulation, and compares the
%   demodulated bits with a deterministic reference sequence.  The returned
%   STATS structure contains BER measurements and frame counters.

    arguments
        rx struct
        common struct
    end

    [demodulator, bitsPerSymbol, carrierMode] = createDemodulator(common.modulation);

    basebandSampleRate = common.symbolRate * common.samplesPerSymbol;
    frameSymbolCount   = common.frameLength;
    frameSampleCount   = frameSymbolCount * common.samplesPerSymbol;
    frameBitCount      = frameSymbolCount * bitsPerSymbol;

    if ~isfield(rx, "samplesPerFrame") || isempty(rx.samplesPerFrame)
        rx.samplesPerFrame = frameSampleCount;
    end

    fprintf("Receiver configuration\n");
    fprintf("  Center frequency : %.3f GHz\n", rx.centerFrequency/1e9);
    fprintf("  Baseband rate    : %.3f Msps\n", basebandSampleRate/1e6);
    fprintf("  Modulation       : %s (%d bits/symbol)\n", common.modulation, bitsPerSymbol);
    fprintf("  Frame length     : %d symbols (%d samples)\n", frameSymbolCount, rx.samplesPerFrame);

    rxRadio = comm.SDRRxPluto( ...
        "RadioID",            rx.radioID, ...
        "CenterFrequency",    rx.centerFrequency, ...
        "BasebandSampleRate", basebandSampleRate, ...
        "SamplesPerFrame",    rx.samplesPerFrame, ...
        "GainSource",         "Manual", ...
        "Gain",               rx.gain, ...
        "OutputDataType",     "single");

    desiredOutputPower = db2pow(-5); % Convert desired output power from dB to linear scale.
    agc = comm.AGC("AveragingLength", 32, "DesiredOutputPower", desiredOutputPower);
    dcBlocker = dsp.DCBlocker("Algorithm", "IIR");
    rxFilter = comm.RaisedCosineReceiveFilter( ...
        "RolloffFactor", common.rolloff, ...
        "FilterSpanInSymbols", common.filterSpan, ...
        "InputSamplesPerSymbol", common.samplesPerSymbol, ...
        "DecimationFactor", 1);
    symbolSync = comm.SymbolSynchronizer( ...
        "TimingErrorDetector", "Gardner (non-data-aided)", ...
        "SamplesPerSymbol", common.samplesPerSymbol, ...
        "DampingFactor", 1.0, ...
        "NormalizedLoopBandwidth", 0.01);
    carrierSync = createCarrierSynchronizer(carrierMode);

    constDiagram = comm.ConstellationDiagram( ...
        "Title", "Received Symbols", ...
        "ShowReferenceConstellation", true);

    % Older releases allowed configuring the averaging length during
    % construction, but newer releases removed the public setter.  Inspect the
    % property metadata before attempting to set it so the scope works across
    % tool versions.
    constDiagramMeta = metaclass(constDiagram);
    averagingLengthProp = findprop(constDiagramMeta, "AveragingLength");
    if ~isempty(averagingLengthProp) && strcmpi(averagingLengthProp.SetAccess, "public")
        constDiagram.AveragingLength = rx.constellationFrames;
    end
    spectrumScope = dsp.SpectrumAnalyzer( ...
        "SampleRate", basebandSampleRate, ...
        "Title", "Received Spectrum", ...
        "PlotAsTwoSidedSpectrum", false, ...
        "SpectrumType", "Power density");

    release(rxRadio);
    cleanupObj = onCleanup(@()release(rxRadio)); %#ok<NASGU>

    randStream = RandStream('mt19937ar', 'Seed', common.randomSeed);

    framesProcessed = 0;
    bitErrors = 0;
    bitsCompared = 0;

    fprintf("Starting reception.\n");
    while framesProcessed < rx.stopAfterFrames
        [rxSamples, isValid] = rxRadio();
        if ~isValid
            warning("Pluto did not return valid samples; retrying...");
            continue;
        end

        framesProcessed = framesProcessed + 1;

        baseband = double(rxSamples(:));
        baseband = dcBlocker(baseband);
        baseband = agc(baseband);
        filtered = rxFilter(baseband);
        synchronized = symbolSync(filtered);
        corrected = carrierSync(synchronized);

        symbols = corrected;
        bits = logical(demodulator(symbols));

        expectedBits = logical(randi(randStream, [0 1], frameBitCount, 1));
        compareCount = min(numel(bits), frameBitCount);
        if compareCount == 0
            warning("No demodulated bits available for frame %d.", framesProcessed);
            continue;
        end

        [errCount, frameBER] = biterr(expectedBits(1:compareCount), bits(1:compareCount));
        bitErrors = bitErrors + errCount;
        bitsCompared = bitsCompared + compareCount;

        if numel(bits) ~= frameBitCount
            warning("Frame %d produced %d bits (expected %d). BER computed on %d bits.", ...
                framesProcessed, numel(bits), frameBitCount, compareCount);
        end

        if rx.enablePlots
            constDiagram(symbols);
            spectrumScope(baseband);
        end

        fprintf("Frame %d: %d symbols, BER %.3g (%d errors)\n", ...
            framesProcessed, numel(symbols), frameBER, errCount);
    end

    if bitsCompared == 0
        ber = NaN;
    else
        ber = bitErrors / bitsCompared;
    end

    stats = struct();
    stats.framesProcessed = framesProcessed;
    stats.bitsCompared    = bitsCompared;
    stats.bitErrors       = bitErrors;
    stats.ber             = ber;

    fprintf("Reception summary\n");
    fprintf("  Frames processed : %d\n", framesProcessed);
    fprintf("  Bits compared    : %d\n", bitsCompared);
    fprintf("  Bit errors       : %d\n", bitErrors);
    fprintf("  BER              : %.3g\n", ber);
end

function sync = createCarrierSynchronizer(mode)
%createCarrierSynchronizer Instantiate a carrier recovery object
    switch mode
        case "QPSK"
            sync = comm.CarrierSynchronizer("Modulation", "QPSK", "SamplesPerSymbol", 1);
        case "PSK"
            sync = comm.CarrierSynchronizer("Modulation", "PSK", "SamplesPerSymbol", 1);
        case "QAM"
            sync = comm.CarrierSynchronizer("Modulation", "QAM", "SamplesPerSymbol", 1);
        otherwise
            error("Unsupported carrier synchronizer mode %s", mode);
    end
end
