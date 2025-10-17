clear; clc;

p = getParameters();
rx = setupPlutoRx(p);
cleanup = onCleanup(@() release(rx)); %#ok<NASGU>

pause(0.5);  % allow hardware to settle
fprintf('Capturing %d frames of %d samples each...\n', p.NumRxFrames, p.SamplesPerFrame);

rxData = collectPlutoFrames(rx, p);

ber = computeBER(rxData, p);
fprintf('Measured BER: %.3e\n', ber);
