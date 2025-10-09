# Link Scripts

The `Link` directory contains a modular MATLAB reference design for pairing two
ADALM-PLUTO radios.  `TxLink.m` and `RxLink.m` are lightweight launchers that
only expose the high-level parameters and report link statistics, while the
signal processing chain lives in helper functions alongside them.

## File overview

| File | Purpose |
| ---- | ------- |
| `TxLink.m` | Configure high-level transmitter parameters and call `runLinkTransmitter`. |
| `RxLink.m` | Configure receiver parameters and call `runLinkReceiver`, reporting BER. |
| `defaultLinkParameters.m` | Produce synchronized default parameter sets for both sessions. |
| `runLinkTransmitter.m` | Implement waveform generation, filtering, and SDR streaming. |
| `runLinkReceiver.m` | Implement synchronization, demodulation, plotting, and BER metrics. |
| `createModulator.m` / `createDemodulator.m` | Instantiate modem System objects. |
| `bitsToSymbols.m` | Convert binary data to M-ary symbol indices. |

## Running the link

1. Launch two MATLAB sessions with the ADALM-PLUTO support package installed.
2. In each session, open either `TxLink.m` or `RxLink.m` and adjust the exposed
   parameter values (e.g., center frequency, gain, modulation order).  The
   defaults in both scripts already match, including the pseudo-random seed used
   for bit generation so that BER can be computed deterministically.
3. Run `TxLink.m` to begin transmitting the requested number of frames.  If you
   set `prm.tx.framesToSend = Inf`, the helper will transmit continuously until
   interrupted.
4. Run `RxLink.m` to capture the specified number of frames.  The helper function
   performs timing/carrier recovery and prints per-frame as well as aggregate BER
   results.  Enable or disable live plots by toggling `prm.rx.enablePlots`.

The modular layout keeps the runnable scripts concise—similar to the earlier
QPSK examples—while still allowing you to extend the individual helper functions
with custom processing stages as needed.
