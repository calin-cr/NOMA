% analyzeResults.m
clear; close all;

resultsFile = 'experiment_results.mat';
if ~isfile(resultsFile)
    error('No results file found. Run experiment first.');
end

load(resultsFile, 'resultsTable');

disp('All logged results:');
disp(resultsTable);

% === Plot BER vs Rsym (grouped by Gain if you test multiple gains) ===
figure;
gscatter(resultsTable.Rsym/1e3, resultsTable.BER, resultsTable.Gain, 'bgrcmyk','o',8);
set(gca,'YScale','log');
xlabel('Symbol rate (kSym/s)');
ylabel('Bit Error Rate (BER)');
title('BER vs Symbol rate');
grid on;

% === Throughput calculation ===
bitsPerSymbol = log2(resultsTable.ModOrder);
throughput = resultsTable.Rsym .* bitsPerSymbol .* (1 - resultsTable.BER);

figure;
plot(resultsTable.Rsym/1e3, throughput/1e3, 'o-','LineWidth',1.2);
xlabel('Symbol rate (kSym/s)');
ylabel('Effective throughput (kbit/s)');
title('Throughput vs Symbol rate');
grid on;

% === Summary statistics ===
summaryStats = groupsummary(resultsTable,"Rsym",["mean","std"],"BER");
disp('Summary statistics (per Rsym):');
disp(summaryStats);

% Optional: Save summary
save('summary_stats.mat','summaryStats');
% === Gráfico BER promedio con desviación estándar ===
figure;

errorbar(summaryStats.Rsym/1e6, ...       % X: símbolo rate (Msps)
         summaryStats.mean_BER, ...       % Y: media de BER
         summaryStats.std_BER, ...        % Desviación estándar
         'o-', 'LineWidth', 1.5, 'MarkerSize', 8);

xlabel('Symbol Rate (Msps)');
ylabel('BER');
title('BER vs Symbol Rate (con desviación estándar)');
grid on;
