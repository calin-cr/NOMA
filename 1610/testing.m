p = getParameters();
[txSig, txBits] = generateTxSignal(p);
save(p.RefBitsFile,'txBits','p');
ber = computeBER(txSig,p)     % should be 0
