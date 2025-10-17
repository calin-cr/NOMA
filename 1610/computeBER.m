function ber = computeBER(rxData,p)
%COMPUTEBER Demodulate Pluto captures and estimate the BER.

if ~isstruct(p)
    error('Parameter input must be a struct returned by getParameters().');
end

if ~isfield(p,'SamplesPerFrame')
    error('The parameter struct appears outdated. Regenerate it via getParameters().');
end

% Load reference transmission
if ~isfile(p.RefBitsFile)
    error('Reference file %s is missing. Run tx.m first to refresh it.', p.RefBitsFile);
end

S = load(p.RefBitsFile,'txBits','txSym','p');
refBits = S.txBits;
refSym  = S.txSym;
pref    = S.p;

% Sanity check – the TX parameters must match the RX settings
assert(strcmpi(pref.Modulation,p.Modulation) && ...
       pref.ModulationOrder == p.ModulationOrder && ...
       pref.SamplesPerSymbol == p.SamplesPerSymbol && ...
       abs(pref.Rolloff - p.Rolloff) < 1e-12 && ...
       pref.FilterSpan == p.FilterSpan && ...
       pref.PreambleSymbols == p.PreambleSymbols && ...
       pref.PayloadSymbols == p.PayloadSymbols, ...
       'Parameter mismatch between TX and RX. Regenerate tx_ref.mat.');

rxData = double(rxData);

if isvector(rxData)
    rxData = rxData(:);
end

numSamples = size(rxData,1);
numFrames  = size(rxData,2);

if numFrames == 1 && numSamples > p.SamplesPerFrame
    numFrames = floor(numSamples / p.SamplesPerFrame);
    rxData = reshape(rxData(1:numFrames*p.SamplesPerFrame), p.SamplesPerFrame, numFrames);
    numSamples = size(rxData,1);
end

if numSamples < p.SamplesPerFrame
    error('Expected at least %d samples per frame but received %d.', p.SamplesPerFrame, numSamples);
end

% Instantiate DSP objects once and reset for each frame
rxFilt = comm.RaisedCosineReceiveFilter( ...
    'RolloffFactor', p.Rolloff, ...
    'FilterSpanInSymbols', p.FilterSpan, ...
    'InputSamplesPerSymbol', p.SamplesPerSymbol, ...
    'DecimationFactor', 1);

if p.EnableSync
    modType = validatestring(upper(p.Modulation), {'QPSK','QAM'});
    cfc = comm.CoarseFrequencyCompensator( ...
        'Modulation', modType, ...
        'SampleRate', p.SampleRate);

    symSync = comm.SymbolSynchronizer( ...
        'SamplesPerSymbol', p.SamplesPerSymbol, ...
        'DampingFactor', 1, ...
        'NormalizedLoopBandwidth', 0.01, ...
        'TimingErrorDetector', 'Gardner (non-data-aided)');

    carrierSync = comm.CarrierSynchronizer( ...
        'Modulation', modType, ...
        'SamplesPerSymbol', 1, ...
        'DampingFactor', 1, ...
        'NormalizedLoopBandwidth', 0.001);
else
    cfc = [];
    symSync = [];
    carrierSync = [];
end

totalBitErrors = 0;
totalBits      = 0;
lastRxFrameSym = [];

for frameIdx = 1:numFrames
    frame = rxData(:, frameIdx);

    if all(frame == 0)
        warning('Frame %d is all zeros. Skipping.', frameIdx);
        continue;
    end

    % Matched filtering
    rxBB = rxFilt(frame);

    % Remove group delay introduced by the matched filters
    totalDelay = 2 * p.FilterDelaySamples;
    if numel(rxBB) <= totalDelay
        warning('Frame %d too short after filtering. Skipping.', frameIdx);
        reset(rxFilt);
        continue;
    end
    rxBB = rxBB(totalDelay+1:end);

    % Synchronisation pipeline
    if p.EnableSync
        rxSync = cfc(rxBB);
        rxSync = symSync(rxSync);
        rxSync = carrierSync(rxSync);
    else
        rxSync = rxBB(1:p.SamplesPerSymbol:end);
    end

    if numel(rxSync) < numel(refSym)
        warning('Frame %d shorter (%d sym) than expected (%d). Skipping.', ...
            frameIdx, numel(rxSync), numel(refSym));
        reset(rxFilt);
        if p.EnableSync
            reset(cfc); reset(symSync); reset(carrierSync);
        end
        continue;
    end

    % Locate the deterministic preamble to align the frame
    preamble = refSym(1:p.PreambleSymbols);
    mf = conj(flipud(preamble));
    metric = filter(mf, 1, rxSync);
    [~, peakIdx] = max(abs(metric));
    startIdx = peakIdx - numel(preamble) + 1;
    if startIdx < 1
        warning('Unable to align frame %d (startIdx=%d). Skipping.', frameIdx, startIdx);
        reset(rxFilt);
        if p.EnableSync
            reset(cfc); reset(symSync); reset(carrierSync);
        end
        continue;
    end

    stopIdx  = startIdx + numel(refSym) - 1;
    if stopIdx > numel(rxSync)
        warning('Aligned frame %d truncated (%d < %d). Skipping.', ...
            frameIdx, numel(rxSync), stopIdx);
        reset(rxFilt);
        if p.EnableSync
            reset(cfc); reset(symSync); reset(carrierSync);
        end
        continue;
    end

    rxFrameSym = rxSync(startIdx:stopIdx);

    % Demodulate into bits
    switch upper(p.Modulation)
        case 'QPSK'
            rxSymIdx = pskdemod(rxFrameSym, p.ModulationOrder, pi/4);
        case 'QAM'
            rxSymIdx = qamdemod(rxFrameSym, p.ModulationOrder, 'UnitAveragePower', true);
        otherwise
            error('Unsupported modulation %s.', p.Modulation);
    end

    k = log2(p.ModulationOrder);
    rxBits = reshape(de2bi(rxSymIdx, k, 'left-msb').', [], 1);

    N = min(numel(refBits), numel(rxBits));
    if N == 0
        continue;
    end

    totalBitErrors = totalBitErrors + sum(xor(refBits(1:N), rxBits(1:N)));
    totalBits      = totalBits + N;
    lastRxFrameSym = rxFrameSym;

    % Reset stateful objects before the next frame
    reset(rxFilt);
    if p.EnableSync
        reset(cfc); reset(symSync); reset(carrierSync);
    end
end

if totalBits == 0
    error('No valid frames were decoded. Verify hardware connections and gain settings.');
end

ber = totalBitErrors / totalBits;
ber = max(0,min(1,ber));

if p.EnablePlots
    figure;
    scatterplot(refSym); title(sprintf('%s reference constellation', p.Modulation));
    if ~isempty(lastRxFrameSym)
        figure;
        scatterplot(lastRxFrameSym); title(sprintf('%s received constellation', p.Modulation));
    end
end

logResults(p, ber);
end
