function [txSig, txBits, txSym] = generateTxSignal(p)
%GENERATETXSIGNAL Build a single frame of modulated samples.
%   The frame contains a deterministic preamble followed by random payload
%   bits.  The transmit signal is shaped by a root-raised cosine filter and
%   normalised to unit power for the Pluto radio.

M = p.ModulationOrder;
k = log2(M);

% --- Deterministic preamble ------------------------------------------------
preambleSymIdx = mod((0:p.PreambleSymbols-1).', M);
preambleBits   = reshape(de2bi(preambleSymIdx, k, 'left-msb').', [], 1);

% --- Random payload -------------------------------------------------------
payloadBits = randi([0 1], p.PayloadSymbols * k, 1);
payloadSymIdx = bi2de(reshape(payloadBits, k, []).', 'left-msb');

% --- Assemble frame -------------------------------------------------------
txBits = [preambleBits; payloadBits];
txSymIdx = [preambleSymIdx; payloadSymIdx];

switch upper(p.Modulation)
    case 'QPSK'
        txSym = pskmod(txSymIdx, M, pi/4);
    case 'QAM'
        txSym = qammod(txSymIdx, M, 'UnitAveragePower', true);
    otherwise
        error('Unsupported modulation "%s".', p.Modulation);
end

% Root-raised cosine transmit filter (normalised to unit power)
txFilt = comm.RaisedCosineTransmitFilter( ...
    'RolloffFactor', p.Rolloff, ...
    'FilterSpanInSymbols', p.FilterSpan, ...
    'OutputSamplesPerSymbol', p.SamplesPerSymbol);

txSig = txFilt(txSym);

% Apply a safety margin to avoid Pluto DAC clipping
txSig = 0.8 * txSig ./ max(abs(txSig));
end
