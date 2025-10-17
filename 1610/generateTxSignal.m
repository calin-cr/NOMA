function [txSig, txBits] = generateTxSignal(p)
M = p.ModulationOrder;
k = log2(M);
numBits = p.FrameSymbols * k;

% Random bits
txBits = randi([0 1], numBits, 1);

% Map bits→symbols
txSymIdx = bi2de(reshape(txBits, k, []).', 'left-msb');

switch upper(p.Modulation)
    case 'QPSK'
        txSym = pskmod(txSymIdx, M, pi/4);        % QPSK
    case 'QAM'
        txSym = qammod(txSymIdx, M, 'UnitAveragePower', true);
end

% Root-raised-cosine transmit filter
txFilt = comm.RaisedCosineTransmitFilter( ...
    'RolloffFactor', p.Rolloff, ...
    'FilterSpanInSymbols', p.FilterSpan, ...
    'OutputSamplesPerSymbol', p.SamplesPerSymbol);

txSig = txFilt(txSym);
txSig = txSig ./ max(abs(txSig));                 % normalize
end
