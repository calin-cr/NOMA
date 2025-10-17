p = getParameters();
[txSig, txBits, txSym] = generateTxSignal(p);
save(p.RefBitsFile,'txBits','txSym','p');

if mod(numel(txSig), p.SamplesPerFrame) ~= 0
    error('Tx waveform length (%d) not a multiple of SamplesPerFrame (%d).', ...
        numel(txSig), p.SamplesPerFrame);
end

rxData = reshape(txSig, p.SamplesPerFrame, []);
ber = computeBER(rxData, p)     % should be ~0 without channel impairments
