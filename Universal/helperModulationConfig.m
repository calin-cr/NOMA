function cfg = helperModulationConfig(modulation)
%helperModulationConfig Return configuration for supported modulations.
%   CFG = helperModulationConfig(MODULATION) accepts either a modulation
%   order (numeric) or the name of the modulation scheme (string/char) and
%   returns a struct with fields describing the selected configuration. The
%   supported modulations are BPSK, QPSK, 8PSK, 16QAM, and 64QAM.
%
%   The returned struct contains the following fields:
%       ModulationOrder              - Modulation order (integer)
%       Name                         - Human readable modulation name
%       BitsPerSymbol                - Bits carried per symbol
%       PhaseAmbiguity               - Angular spacing between ambiguous
%                                      constellation rotations
%       CoarseFrequencyModulation    - Value passed to the coarse
%                                      frequency compensator
%       CarrierSyncModulation        - Value passed to the carrier
%                                      synchronizer
%       ModulatorFactory             - Function handle returning a
%                                      configured modulator System object
%       DemodulatorFactory           - Function handle returning a
%                                      configured demodulator System object
%
%   This helper centralises the modulation-specific configuration so that
%   the transmitter, receiver, and data decoder can all rely on a single
%   source of truth.
%
%   Example:
%       cfg = helperModulationConfig('16qam');
%       mod = cfg.ModulatorFactory();
%       demod = cfg.DemodulatorFactory();
%
%   See also comm.PSKModulator, comm.QPSKModulator,
%   helperQAMModulator, comm.PSKDemodulator,
%   comm.QPSKDemodulator, helperQAMDemodulator.
%
%   Copyright 2023 The MathWorks, Inc.

arguments
    modulation
end

if isnumeric(modulation)
    order = modulation;
    name = modulationOrderToName(order);
else
    name = lower(string(modulation));
    order = modulationNameToOrder(name);
end

bitsPerSymbol = log2(order);

switch name
    case {"bpsk", "2"}
        cfg = baseConfig(order, "BPSK", bitsPerSymbol, pi);
        cfg.CoarseFrequencyModulation = 'BPSK';
        cfg.CarrierSyncModulation = 'BPSK';
        cfg.ModulatorFactory = @()comm.PSKModulator(order, ...
            'BitInput', true, ...
            'PhaseOffset', 0);
        cfg.DemodulatorFactory = @()comm.PSKDemodulator(order, ...
            'BitOutput', true, ...
            'PhaseOffset', 0);
    case {"qpsk", "4"}
        cfg = baseConfig(order, "QPSK", bitsPerSymbol, pi/2);
        cfg.CoarseFrequencyModulation = 'QPSK';
        cfg.CarrierSyncModulation = 'QPSK';
        cfg.ModulatorFactory = @()comm.QPSKModulator( ...
            'BitInput', true, ...
            'PhaseOffset', pi/4, ...
            'OutputDataType', 'double');
        cfg.DemodulatorFactory = @()comm.QPSKDemodulator( ...
            'BitOutput', true, ...
            'PhaseOffset', pi/4);
    case {"8psk", "8"}
        cfg = baseConfig(order, "8PSK", bitsPerSymbol, 2*pi/order);
        cfg.CoarseFrequencyModulation = 'QPSK';
        cfg.CarrierSyncModulation = '8PSK';
        cfg.ModulatorFactory = @()comm.PSKModulator(order, ...
            'BitInput', true, ...
            'PhaseOffset', pi/order);
        cfg.DemodulatorFactory = @()comm.PSKDemodulator(order, ...
            'BitOutput', true, ...
            'PhaseOffset', pi/order);
    case {"16qam", "16"}
        cfg = baseConfig(order, "16QAM", bitsPerSymbol, pi/2);
        cfg.CoarseFrequencyModulation = '16QAM';
        cfg.CarrierSyncModulation = '16QAM';
        cfg.ModulatorFactory = @()helperQAMModulator( ...
            'ModulationOrder', order, ...
            'BitInput', true, ...
            'NormalizationMethod', 'Average power');
        cfg.DemodulatorFactory = @()helperQAMDemodulator( ...
            'ModulationOrder', order, ...
            'BitOutput', true, ...
            'NormalizationMethod', 'Average power');
    case {"64qam", "64"}
        cfg = baseConfig(order, "64QAM", bitsPerSymbol, pi/2);
        cfg.CoarseFrequencyModulation = '16QAM';
        cfg.CarrierSyncModulation = '64QAM';
        cfg.ModulatorFactory = @()helperQAMModulator( ...
            'ModulationOrder', order, ...
            'BitInput', true, ...
            'NormalizationMethod', 'Average power');
        cfg.DemodulatorFactory = @()helperQAMDemodulator( ...
            'ModulationOrder', order, ...
            'BitOutput', true, ...
            'NormalizationMethod', 'Average power');
    otherwise
        error('helperModulationConfig:UnsupportedModulation', ...
            'Unsupported modulation %s.', name);
end

end

function cfg = baseConfig(order, name, bitsPerSymbol, phaseAmbiguity)
cfg = struct( ...
    'ModulationOrder', order, ...
    'Name', char(name), ...
    'BitsPerSymbol', bitsPerSymbol, ...
    'PhaseAmbiguity', phaseAmbiguity, ...
    'CoarseFrequencyModulation', '', ...
    'CarrierSyncModulation', '', ...
    'ModulatorFactory', [], ...
    'DemodulatorFactory', []);
end

function name = modulationOrderToName(order)
switch order
    case 2
        name = "bpsk";
    case 4
        name = "qpsk";
    case 8
        name = "8psk";
    case 16
        name = "16qam";
    case 64
        name = "64qam";
    otherwise
        error('helperModulationConfig:UnsupportedOrder', ...
            'Unsupported modulation order %d.', order);
end
end

function order = modulationNameToOrder(name)
switch lower(name)
    case {'bpsk', '2'}
        order = 2;
    case {'qpsk', '4'}
        order = 4;
    case {'8psk', '8'}
        order = 8;
    case {'16qam', '16'}
        order = 16;
    case {'64qam', '64'}
        order = 64;
    otherwise
        error('helperModulationConfig:UnsupportedName', ...
            'Unsupported modulation name %s.', name);
end
end
