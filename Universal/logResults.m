function logResults(filename, Rsym, modulation, freq, gain, BER)
%LOGRESULTS Append experiment results with modulation metadata.
%
%   The modulation argument can be numeric (modulation order) or a string
%   name. The log table keeps both the order and the human-readable name.
%
% Copyright 2023 The MathWorks, Inc.

cfg = helperModulationConfig(modulation);
entry = table(Rsym, cfg.ModulationOrder, string(cfg.Name), freq, gain, ...
    BER(1), BER(2), BER(3), datetime('now'), ...
    'VariableNames', {'Rsym','ModOrder','Modulation','Freq','Gain', ...
    'BER','NumErrors','NumCompared','Timestamp'});

if isfile(filename)
    load(filename, 'resultsTable');
    resultsTable = [resultsTable; entry];
else
    resultsTable = entry;
end

save(filename, 'resultsTable');
end
