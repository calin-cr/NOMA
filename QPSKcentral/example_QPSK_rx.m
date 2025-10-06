clear all

%Params
Rsym=0.25e6;
mod=4;
freq=915e6;
gain=10;
N_samples = 10; 

for samplenum = 1:N_samples

    % Receiver parameter structure
    prmQPSKReceiver = plutoradioqpskreceiver_init(Rsym, mod, freq, gain);
    
    % Specify Radio ID
    prmQPSKReceiver.Address = 'usb:0';
    
    
    
    printReceivedData = false;    % true if the received data is to be printed
    
    BER = runPlutoradioQPSKReceiver(prmQPSKReceiver, printReceivedData, samplenum);
    
    fprintf('Error rate is = %f.\n',BER(1));
    fprintf('Number of detected errors = %d.\n',BER(2));
    fprintf('Total number of compared samples = %d.\n',BER(3));
end