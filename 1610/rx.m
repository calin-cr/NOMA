clear; clc;
p = getParameters();
rxx = setupPlutoRx(p);

pause(1);  % allow hardware to stabilize
disp('Receiving...');
rxData = rxx(); 
release(rxx);

ber = computeBER(rxData,p);
fprintf('BER: %.3e\n', ber);
