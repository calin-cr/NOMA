%% QPSK Receiver with ADALM-PLUTO Radio
% This example shows the implementation of a QPSK receiver using
% ADALM-PLUTO radio System objects(TM). The QPSK receiver receives and
% demodulates the signal sent by the
% <docid:plutoradio_ug#example-plutoradioQPSKTransmitterExample QPSK
% Transmitter with ADALM-PLUTO Radio> example at a bit rate of 0.4 Mbps, and
% prints the demodulated signal in the MATLAB(R) command line. In
% particular, this example illustrates methods to address real-world
% wireless communications issues like carrier frequency and phase offset,
% timing recovery and frame synchronization.

% Copyright 2017-2024 The MathWorks, Inc.

%% Introduction
% The |comm.SDRRxPluto| System object receives the QPSK
% signal impaired by over the air transmission. This example provides a
% reference design of a practical QPSK receiver that decodes the impaired
% QPSK signal by addressing the channel impairments. The QPSK receiver
% includes correlation based coarse frequency compensator, phase locked
% loop (PLL) based fine frequency compensation, timing recovery with fixed
% rate sampling and bit stuffing or stripping, frame synchronization, and
% phase ambiguity resolution.
%
% This example serves two main purposes:
% 
% * To implement a real world QPSK receiver using ADALM-PLUTO radio System
% objects
% * To illustrate the use of key Communications Toolbox(TM) synchronization components.
% 
%% Initialize Receiver Parameters
% The |plutoradioqpskreceiver_init| script initializes the simulation
% parameters and generates the |prmQPSKReceiver| structure.

% Receiver parameter structure
prmQPSKReceiver = plutoradioqpskreceiver_init;
% Specify Radio ID
prmQPSKReceiver.Address = 'usb:0'

%% Code Architecture
% The function |runPlutoradioQPSKReceiver| uses two System objects,
% |QPSKReceiver| and |comm.SDRRxPluto|, to implement the QPSK receiver. 
%
% *ADALM-PLUTO Receiver*
%
% The |comm.SDRRxPluto| System object communicates with the
% ADALM-PLUTO radio connected to the host computer. This component returns
% the QPSK signal received. 
% 
% *QPSK Receiver*
%
% The |QPSKReceiver| demodulates and retrieves the original
% transmitted message. The |QPSKReceiver| has six subcomponents, modeled
% using System objects.
% 
% Automatic gain control: The automatic gain control (AGC) subcomponent
% sets the output power to a particular level to ensure that the equivalent
% gains of the phase and timing error detectors are constant over time. The
% AGC is placed before the raised cosine receive filter so that the signal
% amplitude can be measured with an oversampling factor of two. This
% process improves the accuracy of the estimate.
% 
% Coarse frequency compensation: The coarse frequency compensator
% subcomponent uses a correlation-based algorithm to roughly estimate the
% frequency offset and then compensate for it. The estimated coarse
% frequency offset is averaged so that fine frequency compensation is
% allowed to lock or converge. Hence, the coarse frequency offset is
% estimated using a |comm.CoarseFrequencyCompensator| System object and an
% averaging formula. The |comm.PhaseFrequencyOffset| performs the
% compensation.
% 
% Timing recovery: Performs timing recovery with closed-loop scalar
% processing to counteract the channel-induced delays, using a
% |comm.SymbolSynchronizer| System object. The |comm.SymbolSynchronizer|
% object implements a PLL to correct the symbol timing error in the
% received signal. For this example, you select the rotationally-invariant
% Gardner timing error detector, allowing timing recovery to take place
% before fine frequency compensation. The input to the
% |comm.SymbolSynchronizer| object is a fixed-length frame of samples and
% the output is a frame of symbols whose length can vary due to bit
% stuffing and stripping, depending on actual channel delays.
% 
% Fine frequency compensation: The fine frequency compensation subcomponent
% performs closed-loop scalar processing and compensates for the frequency
% offset accurately using a |comm.CarrierSynchronizer| System object. The
% |comm.CarrierSynchronizer| object implements a PLL to track the residual
% frequency offset and the phase offset in the input signal.
% 
% Frame synchronization: The frame synchronization sub component performs
% frame synchronization and converts the variable length symbol inputs into
% fixed-length outputs using a |FrameSynchronizer| System object. The
% |FrameSynchronizer| object has a secondary boolean scalar output that
% indicates the validity of the first frame output.
% 
% Data decoder: The data decoder subcomponent performs phase ambiguity
% resolution and demodulation. Also, the data decoder compares the
% regenerated message with the transmitted one and calculates the BER.
%
% For more information about the system components, refer to the
% <docid:plutoradio_ug#example-plutoradioQPSKReceiverSimulinkExample QPSK
% Receiver with ADALM-PLUTO Radio in Simulink>.

%% Receive QPSK Signal and Calculate BER
% Run the example to start receiving the QPSK signal. The QPSK receiver
% demodulates and calculates the bit error rate (BER) of the received
% signal.

printReceivedData = false;    % true if the received data is to be printed

BER = runPlutoradioQPSKReceiver(prmQPSKReceiver, printReceivedData); 

fprintf('Error rate is = %f.\n',BER(1));
fprintf('Number of detected errors = %d.\n',BER(2));
fprintf('Total number of compared samples = %d.\n',BER(3));

%%
% When you run the simulations, the received messages are decoded and
% printed out in the MATLAB command window while the simulation is running.
% BER information is also shown at the end of the script execution. The
% calculation of the BER value includes the first received frames, when
% some of the adaptive components in the QPSK receiver still have not
% converged.  During this period, the BER is quite high.  Once the
% transient period is over, the receiver is able to estimate the
% transmitted frame and the BER dramatically improves. In this example, to
% guarantee a reasonable execution time of the system in simulation mode,
% the simulation duration is fairly short.  As such, the overall BER
% results are significantly affected by the high BER values at the
% beginning of the simulation. To increase the simulation duration and
% obtain lower BER values,  you can change the SimParams.StopTime variable
% in the <matlab:openExample('plutoradio/QPSKReceiverWithADALMPLUTORadioExample','supportingFile','plutoradioqpskreceiver_init.m') receiver initialization
% file>.
%
% If the message is not properly decoded by the receiver system, you can
% vary the gain of the source signals in the |ADALM-PLUTO Transmitter| and
% |ADALM-PLUTO Receiver| System objects by changing the SimParams.PlutoGain
% value in the <matlab:openExample('plutoradio/QPSKTransmitterWithADALMPLUTORadioExample','supportingFile','plutoradioqpsktransmitter_init.m') transmitter
% initialization file> and in the <matlab:openExample('plutoradio/QPSKReceiverWithADALMPLUTORadioExample','supportingFile','plutoradioqpskreceiver_init.m')
% receiver initialization file>.
%
% Also, a large relative frequency offset between the transmit and receive
% radios can prevent the receiver functions from properly decoding the
% message. If that happens, you can determine the offset by running the
% models in <docid:plutoradio_ug#mw_baa863fb-d239-4495-baf9-eb6864e0f592
% Frequency Offset Calibration with ADALM-PLUTO Radio in Simulink> example
% then applying that offset to the center frequency of the |comm.SDRRxPluto| 
% System object.
%
%% Supporting Functions
% This example uses the following functions:
%
% * <matlab:openExample('plutoradio/QPSKReceiverWithADALMPLUTORadioExample','supportingFile','runPlutoradioQPSKReceiver.m') runPlutoradioQPSKReceiver.m>
% * <matlab:openExample('plutoradio/QPSKReceiverWithADALMPLUTORadioExample','supportingFile','plutoradioqpskreceiver_init.m') plutoradioqpskreceiver_init.m>
% * <matlab:openExample('plutoradio/QPSKReceiverWithADALMPLUTORadioExample','supportingFile','QPSKReceiver.m') QPSKReceiver.m>

%% References
% 1. Rice, Michael. _Digital Communications - A Discrete-Time
% Approach_. 1st ed. New York, NY: Prentice Hall, 2008.
