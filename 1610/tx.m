clear; clc;
p = getParameters();
txx = setupPlutoTx(p);
[txSig, txBits] = generateTxSignal(p);
save(p.RefBitsFile,'txBits','p');  % overwrite stale files

txDuration = 1000;  % seconds
disp(['Transmitting for ', num2str(txDuration), ' seconds...']);
transmitRepeat(txx, txSig);
pause(txDuration);
release(txx);
disp('Transmission stopped.');
