clear; clc;

p = getParameters();
[txSig, txBits, txSym] = generateTxSignal(p);
save(p.RefBitsFile,'txBits','txSym','p');  % overwrite stale files

tx = setupPlutoTx(p);
cleanup = onCleanup(@() release(tx)); %#ok<NASGU>

txDuration = p.TxDuration;
fprintf('Transmitting %d complex samples per frame at %.2f Msps for %d seconds...\n', ...
    numel(txSig), p.SampleRate/1e6, txDuration);

txWaveform = complex(single(real(txSig)), single(imag(txSig)));

transmitRepeat(tx, txWaveform);
pause(txDuration);

disp('Transmission stopped.');
