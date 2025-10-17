function ber = computeBER(rxData,p)
% Load reference bits and validate
S = load(p.RefBitsFile,'txBits','p');
refBits = S.txBits;
pref    = S.p;

% Sanity: parameters must match TX
assert(strcmpi(pref.Modulation,p.Modulation) && ...
       pref.ModulationOrder==p.ModulationOrder && ...
       pref.SamplesPerSymbol==p.SamplesPerSymbol && ...
       abs(pref.Rolloff - p.Rolloff) < 1e-12 && ...
       pref.FilterSpan == p.FilterSpan, ...
       'Parameter mismatch between TX and RX. Regenerate tx_ref.mat.');

% Matched RRC receive filter
rxFilt = comm.RaisedCosineReceiveFilter( ...
    'RolloffFactor', p.Rolloff, ...
    'FilterSpanInSymbols', p.FilterSpan, ...
    'InputSamplesPerSymbol', p.SamplesPerSymbol, ...
    'DecimationFactor', 1);
rxBB = rxFilt(rxData);

% --- Optional carrier & timing recovery for OTA ---
if isfield(p,'EnableSync') && p.EnableSync
    switch upper(p.Modulation)
        case 'QPSK'
            modType = 'QPSK';
        case 'QAM'
            modType = 'QAM';
        otherwise
            error('Unsupported modulation for synchronization');
    end

    % Coarse frequency compensation
    cfc = comm.CoarseFrequencyCompensator( ...
        'Modulation', modType, ...
        'SampleRate', p.SampleRate);

    rxBB = cfc(rxBB);

    % Symbol timing recovery
    symSync = comm.SymbolSynchronizer( ...
        'SamplesPerSymbol', p.SamplesPerSymbol, ...
        'DampingFactor', 1, ...
        'NormalizedLoopBandwidth', 0.01, ...
        'TimingErrorDetector', 'Gardner (non-data-aided)');
    rxBB = symSync(rxBB);
end


% Remove filter delay and downsample
delay = p.FilterSpan * p.SamplesPerSymbol;
if numel(rxBB) <= delay, error('RX frame shorter than filter delay.'); end
rxBB = rxBB(delay+1:end);
rxSym = rxBB(1:p.SamplesPerSymbol:end);

% Demod
M = p.ModulationOrder; k = log2(M);
switch upper(p.Modulation)
    case 'QPSK'
        rxSymIdx = pskdemod(rxSym, M, pi/4);
    case 'QAM'
        rxSymIdx = qamdemod(rxSym, M, 'UnitAveragePower', true);
    otherwise
        error('Unsupported modulation.');
end
rxBits = reshape(de2bi(rxSymIdx, k, 'left-msb').', [], 1);

% Align and compute BER correctly
N = min(numel(refBits), numel(rxBits));
assert(N>0,'No bits to compare. Check frame sizes.');
refBits = refBits(1:N);
rxBits  = rxBits(1:N);

% Option A: use biterr correctly
[~, ber] = biterr(refBits, rxBits);

% Option B (equivalent manual):
% ber = sum(xor(refBits,rxBits))/N;

% Clamp to [0,1] for safety
ber = max(0,min(1,ber));

% Plot
figure; scatterplot(rxSym);
title(sprintf('%s RRC, BER=%.3e', p.Modulation, ber));

logResults(p, ber);
end
