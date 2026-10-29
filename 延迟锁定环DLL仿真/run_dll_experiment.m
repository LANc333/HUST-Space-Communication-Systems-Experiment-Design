function results = run_dll_experiment(outputDirectory)
% Run the C/A-code correlation and delay-lock-loop experiments.

if nargin < 1 || isempty(outputDirectory)
    outputDirectory = fileparts(mfilename('fullpath'));
end
if ~exist(outputDirectory, 'dir')
    mkdir(outputDirectory);
end

prn = 20;
codeLength = 1023;
codeRate = 1.023e6;
chipDuration = 1 / codeRate;
sampleRate = 100e6;
samplesPerChip = sampleRate / codeRate;
integrationTime = 1e-3;
sampleCount = round(sampleRate * integrationTime);
trueDelaySeconds = 30e-3;
trueDelayChips = round(trueDelaySeconds / chipDuration);
receivedDopplerHz = 1000;
earlyLateSpacingChips = 1;
delayErrorChips = -100:0.1:100;
sampleIndex = 0:sampleCount-1;
time = sampleIndex / sampleRate;
sampleOffsets = round(delayErrorChips * samplesPerChip);

caCode = generateCAcode(prn);
baseCodeSamples = caCode(floor(sampleIndex / samplesPerChip) + 1);
receivedCodeIndex = mod(floor(sampleIndex / samplesPerChip) - ...
    trueDelayChips, codeLength) + 1;
receivedCode = caCode(receivedCodeIndex);
receivedSignal = receivedCode .* exp(1i * ...
    (2 * pi * receivedDopplerHz * time));

correctedSignal = receivedSignal .* exp(-1i * ...
    (2 * pi * receivedDopplerHz * time));
mismatchedSignal = receivedSignal .* exp(-1i * ...
    (2 * pi * 500 * time));
matchedCorrelation = correlationAtShifts(correctedSignal, ...
    baseCodeSamples, sampleOffsets);
mismatchedCorrelation = correlationAtShifts(mismatchedSignal, ...
    baseCodeSamples, sampleOffsets);

halfSpacingSamples = round(earlyLateSpacingChips * samplesPerChip / 2);
phase0Discriminators = calculateDiscriminators(correctedSignal, ...
    baseCodeSamples, sampleOffsets, halfSpacingSamples);
phase180Discriminators = calculateDiscriminators(-correctedSignal, ...
    baseCodeSamples, sampleOffsets, halfSpacingSamples);

snrDb = [0 -10 -20 -50];
rng(20261029, 'twister');
unitNoise = (randn(1, sampleCount) + 1i * randn(1, sampleCount)) / sqrt(2);
noiseDiscriminators = repmat(emptyDiscriminator(), 1, numel(snrDb));
for index = 1:numel(snrDb)
    noiseAmplitude = 10 ^ (-snrDb(index) / 20);
    noisySignal = receivedSignal + noiseAmplitude * unitNoise;
    wipedNoisySignal = noisySignal .* exp(-1i * ...
        (2 * pi * receivedDopplerHz * time));
    noiseDiscriminators(index) = calculateDiscriminators( ...
        wipedNoisySignal, baseCodeSamples, sampleOffsets, halfSpacingSamples);
end

zeroIndex = find(delayErrorChips == 0, 1);
gainRatio = abs(mismatchedCorrelation(zeroIndex)) / ...
    abs(matchedCorrelation(zeroIndex));
assert(numel(caCode) == codeLength && all(ismember(caCode, [-1 1])));
assert(abs(matchedCorrelation(zeroIndex) - sampleCount) < 1e-8, ...
    'Matched Doppler correlation peak is incorrect.');
assert(gainRatio > 0.62 && gainRatio < 0.65, ...
    'The 500 Hz residual Doppler attenuation is outside the expected range.');
assert(max(abs(phase0Discriminators.coherent + ...
    phase180Discriminators.coherent)) < 1e-8);
assert(max(abs(phase0Discriminators.envelope - ...
    phase180Discriminators.envelope)) < 1e-8);
assert(max(abs(phase0Discriminators.power - ...
    phase180Discriminators.power)) < 1e-3);

parameters = struct( ...
    'PRN', prn, ...
    'codeLength', codeLength, ...
    'codeRateHz', codeRate, ...
    'chipDurationSeconds', chipDuration, ...
    'samplesPerChip', samplesPerChip, ...
    'sampleRateHz', sampleRate, ...
    'samplesPerMillisecond', sampleCount, ...
    'integrationTimeSeconds', integrationTime, ...
    'trueDelaySeconds', trueDelaySeconds, ...
    'receivedDopplerHz', receivedDopplerHz, ...
    'earlyLateSpacingChips', earlyLateSpacingChips, ...
    'delayStepChips', 0.1, ...
    'noiseSNRDefinition', 'Per-sample complex baseband signal-to-noise ratio');

results = struct();
results.parameters = parameters;
results.caCode = caCode;
results.correlation = struct( ...
    'delayErrorChips', delayErrorChips, ...
    'matchedDoppler', matchedCorrelation, ...
    'mismatchedDoppler', mismatchedCorrelation, ...
    'mismatchedToMatchedMagnitudeRatio', gainRatio);
results.dll = struct( ...
    'delayErrorChips', delayErrorChips, ...
    'phase0', phase0Discriminators, ...
    'phase180', phase180Discriminators);
results.noise = struct( ...
    'snrDb', snrDb, ...
    'discriminators', noiseDiscriminators, ...
    'randomSeed', 20261029);

saveCorrelationFigures(outputDirectory, delayErrorChips, ...
    matchedCorrelation, mismatchedCorrelation);
saveDiscriminatorFigures(outputDirectory, delayErrorChips, ...
    phase0Discriminators, phase180Discriminators, snrDb, noiseDiscriminators);
save(fullfile(outputDirectory, 'dll_simulation_results.mat'), ...
    'results', '-v7.3');
writeSummary(outputDirectory, parameters, results, zeroIndex);

fprintf('PRN %d, %d chips, %d samples/ms\n', prn, codeLength, sampleCount);
fprintf('Matched peak: %.0f at %.1f chips error\n', ...
    abs(matchedCorrelation(zeroIndex)), delayErrorChips(zeroIndex));
fprintf('500 Hz Doppler mismatch magnitude ratio: %.4f\n', gainRatio);
fprintf('Results saved to: %s\n', outputDirectory);
end

function caCode = generateCAcode(prn)
if prn ~= 20
    error('This experiment is configured for GPS C/A PRN 20.');
end

codeLength = 1023;
g1State = ones(1, 10);
g2State = ones(1, 10);
g1 = zeros(1, codeLength);
g2 = zeros(1, codeLength);
for index = 1:codeLength
    g1(index) = g1State(10);
    g1Feedback = xor(g1State(3), g1State(10));
    g1State = [g1Feedback g1State(1:9)];

    g2(index) = g2State(10);
    g2Feedback = xor(g2State(2), g2State(3));
    g2Feedback = xor(g2Feedback, g2State(6));
    g2Feedback = xor(g2Feedback, g2State(8));
    g2Feedback = xor(g2Feedback, g2State(9));
    g2Feedback = xor(g2Feedback, g2State(10));
    g2State = [g2Feedback g2State(1:9)];
end

% GPS PRN 20 uses the G2 phase shift 472 from the supplied course reference.
g2Shift = 472;
g2 = [g2(end-g2Shift+1:end) g2(1:end-g2Shift)];
caBits = xor(g1, g2);
caCode = 2 * double(caBits) - 1;
end

function correlation = correlationAtShifts(signal, codeSamples, shifts)
allShifts = ifft(fft(signal) .* conj(fft(codeSamples)));
indices = mod(shifts, numel(codeSamples)) + 1;
correlation = allShifts(indices);
end

function discriminators = calculateDiscriminators(signal, codeSamples, ...
    shifts, halfSpacingSamples)
early = correlationAtShifts(signal, codeSamples, shifts - halfSpacingSamples);
late = correlationAtShifts(signal, codeSamples, shifts + halfSpacingSamples);
discriminators = struct( ...
    'coherent', real(early) - real(late), ...
    'envelope', abs(early) - abs(late), ...
    'power', abs(early) .^ 2 - abs(late) .^ 2);
end

function value = emptyDiscriminator()
value = struct('coherent', [], 'envelope', [], 'power', []);
end

function saveCorrelationFigures(outputDirectory, delays, matched, mismatched)
figureHandle = figure('Visible', 'off', 'Color', 'w', ...
    'Name', 'DLL correlation and Doppler');
tiledlayout(3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
series = {real(matched), real(mismatched); ...
    imag(matched), imag(mismatched); abs(matched), abs(mismatched)};
rowLabels = {'I correlation', 'Q correlation', 'Correlation magnitude'};
columnTitles = {'Doppler estimate 1000 Hz', 'Doppler estimate 500 Hz'};
for row = 1:3
    for column = 1:2
        nexttile;
        plot(delays, series{row, column}, 'LineWidth', 1.1);
        xlim([-2 2]);
        grid on;
        xlabel('Reference delay error (chips)');
        ylabel(rowLabels{row});
        if row == 1
            title(columnTitles{column});
        end
    end
end
sgtitle('Prompt correlation near the code phase peak');
saveas(figureHandle, fullfile(outputDirectory, ...
    'correlation_doppler_zoom.png'));
close(figureHandle);

figureHandle = figure('Visible', 'off', 'Color', 'w', ...
    'Name', 'DLL correlation full scan');
zeroIndex = find(delays == 0, 1);
matchedPeak = abs(matched(zeroIndex));
plot(delays, abs(matched) / matchedPeak, 'LineWidth', 1.1);
hold on;
plot(delays, abs(mismatched) / matchedPeak, 'LineWidth', 1.1);
grid on;
xlabel('Reference delay error (chips)');
ylabel('Normalized correlation magnitude');
title('Correlation magnitude across the full delay scan');
legend('Doppler estimate 1000 Hz', 'Doppler estimate 500 Hz', ...
    'Location', 'best');
saveas(figureHandle, fullfile(outputDirectory, ...
    'correlation_doppler_full_scan.png'));
close(figureHandle);
end

function saveDiscriminatorFigures(outputDirectory, delays, phase0, ...
    phase180, snrDb, noiseDiscriminators)
names = {'coherent', 'envelope', 'power'};
labels = {'Coherent E-L', 'Envelope E-L', 'Power E^2-L^2'};
phases = {phase0, phase180};
phaseNames = {'0 deg', '180 deg'};
for phaseIndex = 1:2
    figureHandle = figure('Visible', 'off', 'Color', 'w', ...
        'Name', ['DLL discriminators, phase ' phaseNames{phaseIndex}]);
    tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    for metricIndex = 1:3
        nexttile;
        plot(delays, phases{phaseIndex}.(names{metricIndex}), ...
            'LineWidth', 1.1);
        xlim([-2 2]);
        grid on;
        ylabel(labels{metricIndex});
        if metricIndex == 1
            title(['Carrier phase error ' phaseNames{phaseIndex}]);
        end
        if metricIndex == 3
            xlabel('Reference delay error (chips)');
        end
    end
    saveas(figureHandle, fullfile(outputDirectory, ...
        ['dll_discriminators_phase_' num2str((phaseIndex - 1) * 180) '.png']));
    close(figureHandle);
end

figureHandle = figure('Visible', 'off', 'Color', 'w', ...
    'Name', 'DLL discriminator noise comparison');
tiledlayout(numel(snrDb), 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for snrIndex = 1:numel(snrDb)
    for metricIndex = 1:3
        nexttile;
        plot(delays, noiseDiscriminators(snrIndex).(names{metricIndex}), ...
            'LineWidth', 0.9);
        xlim([-2 2]);
        grid on;
        title(sprintf('%s, SNR %d dB', labels{metricIndex}, snrDb(snrIndex)));
        if metricIndex == 1
            ylabel('Discriminator output');
        end
        if snrIndex == numel(snrDb)
            xlabel('Reference delay error (chips)');
        end
    end
end
sgtitle('DLL discriminator outputs under complex baseband AWGN');
saveas(figureHandle, fullfile(outputDirectory, ...
    'dll_discriminators_noise_snr.png'));
close(figureHandle);
end

function writeSummary(outputDirectory, parameters, results, zeroIndex)
summaryPath = fullfile(outputDirectory, 'dll_simulation_results.txt');
fileId = fopen(summaryPath, 'w');
assert(fileId >= 0, 'Could not create the result summary file.');
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, 'GPS C/A PRN: %d\n', parameters.PRN);
fprintf(fileId, 'Code length: %d chips\n', parameters.codeLength);
fprintf(fileId, 'Code rate: %.3f MHz\n', parameters.codeRateHz / 1e6);
fprintf(fileId, 'Sampling: %.3f samples/chip, %.3f MHz\n', ...
    parameters.samplesPerChip, parameters.sampleRateHz / 1e6);
fprintf(fileId, 'Coherent integration: %.3f ms (%d samples)\n', ...
    parameters.integrationTimeSeconds * 1e3, parameters.samplesPerMillisecond);
fprintf(fileId, 'Received delay: %.3f ms\n', ...
    parameters.trueDelaySeconds * 1e3);
fprintf(fileId, 'Received Doppler: %d Hz\n', parameters.receivedDopplerHz);
fprintf(fileId, 'Early-late spacing: %.1f chip\n', ...
    parameters.earlyLateSpacingChips);
fprintf(fileId, 'Delay error scan: [-100, 100] chips, step %.1f chip\n', ...
    parameters.delayStepChips);
fprintf(fileId, 'Matched-Doppler correlation at zero error: %.6f\n', ...
    abs(results.correlation.matchedDoppler(zeroIndex)));
fprintf(fileId, '500 Hz Doppler mismatch magnitude ratio: %.6f\n', ...
    results.correlation.mismatchedToMatchedMagnitudeRatio);
fprintf(fileId, 'DLL carrier phase cases: 0 and 180 degrees\n');
fprintf(fileId, 'Discriminators: coherent E-L, envelope E-L, power E^2-L^2\n');
fprintf(fileId, 'Noise: complex AWGN, per-sample SNR in dB; RNG seed %d\n', ...
    results.noise.randomSeed);
fprintf(fileId, 'Noise SNR cases: 0, -10, -20, -50 dB\n');
fprintf(fileId, ['For readable curves, figures zoom to +/-2 chips; ' ...
    'MAT data retain the full +/-100 chip scan.\n']);
clear cleanup;
end
