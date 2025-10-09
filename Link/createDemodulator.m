function [demodulator, bitsPerSymbol, carrierMode] = createDemodulator(name)
%createDemodulator Construct a symbol demodulator for the link scripts
%
%   [DEMODULATOR, BITSPERSYMBOL, CARRIERMODE] = createDemodulator(NAME)
%   returns a function handle that maps received constellation points to
%   binary data, along with metadata used by the receiver chain.

    arguments
        name (1,1) string
    end

    switch upper(name)
        case "BPSK"
            M = 2;
            demodObj = comm.PSKDemodulator(M, PhaseOffset=pi/4, BitOutput=true);
            carrierMode = "PSK";
        case "QPSK"
            M = 4;
            demodObj = comm.PSKDemodulator(M, PhaseOffset=pi/4, BitOutput=true);
            carrierMode = "QPSK";
        case "8PSK"
            M = 8;
            demodObj = comm.PSKDemodulator(M, PhaseOffset=pi/8, BitOutput=true);
            carrierMode = "PSK";
        case "16QAM"
            M = 16;
            demodObj = comm.RectangularQAMDemodulator(M, BitOutput=true, ...
                NormalizationMethod="Average power");
            carrierMode = "QAM";
        case "64QAM"
            M = 64;
            demodObj = comm.RectangularQAMDemodulator(M, BitOutput=true, ...
                NormalizationMethod="Average power");
            carrierMode = "QAM";
        otherwise
            error("Unsupported modulation %s", name);
    end

    bitsPerSymbol = log2(M);
    demodulator = @(samples)demodObj(samples);
end
