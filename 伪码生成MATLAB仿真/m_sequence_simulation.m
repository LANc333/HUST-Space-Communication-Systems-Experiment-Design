% M-sequence generation and cyclic-correlation experiment.
% Run this script in MATLAB. It creates two PNG figures and a text summary
% beside this file; it uses base MATLAB only.

clear;
close all;
clc;

registerLength = 10;
sequenceLength = 2^registerLength - 1;
initialState = ones(registerLength, 1);

% x^10 + x^9 + x^8 + x^6 + x^3 + x^2 + 1
feedbackStages = [2 3 6 8 9];

% Read the output node shown in each structure diagram.
C1 = generateStructureI(initialState, sequenceLength, feedbackStages);
C2 = generateStructureII(initialState, sequenceLength, feedbackStages);

% Logic levels: 0 -> +1 and 1 -> -1.
C1 = 1 - 2 * C1;
C2 = 1 - 2 * C2;

autoC1 = cyclicCorrelation(C1, C1);
autoC2 = cyclicCorrelation(C2, C2);
crossC12 = cyclicCorrelation(C1, C2);

phaseShift = findPhaseShift(C1, C2);
peakIndex = find(crossC12 == max(crossC12), 1, 'first') - 1;

assert(sum(C1 == -1) == 512 && sum(C1 == 1) == 511, ...
    'C1 does not satisfy the m-sequence balance property.');
assert(sum(C2 == -1) == 512 && sum(C2 == 1) == 511, ...
    'C2 does not satisfy the m-sequence balance property.');
assert(autoC1(1) == sequenceLength && all(autoC1(2:end) == -1), ...
    'C1 cyclic autocorrelation is not two-valued.');
assert(autoC2(1) == sequenceLength && all(autoC2(2:end) == -1), ...
    'C2 cyclic autocorrelation is not two-valued.');
assert(isequal(C2, circshift(C1, [0 -phaseShift])), ...
    'The two sequences are not aligned by the reported cyclic shift.');
assert(crossC12(phaseShift + 1) == sequenceLength, ...
    'The cross-correlation peak does not match the reported phase shift.');

outputDirectory = fileparts(mfilename('fullpath'));
if isempty(outputDirectory)
    outputDirectory = pwd;
end
chipIndex = 0:sequenceLength-1;

figure('Color', 'w', 'Name', 'M-sequence cyclic autocorrelation');
stem(chipIndex, autoC1, '.', 'DisplayName', 'C1');
hold on;
stem(chipIndex, autoC2, 'x', 'DisplayName', 'C2');
grid on;
xlabel('Cyclic shift (chips)');
ylabel('Unnormalized autocorrelation');
title('M-sequence cyclic autocorrelation');
xlim([0 sequenceLength-1]);
legend('Location', 'best');
saveas(gcf, fullfile(outputDirectory, 'm_sequence_autocorrelation.png'));

figure('Color', 'w', 'Name', 'M-sequence cyclic cross-correlation');
stem(chipIndex, crossC12, '.', 'DisplayName', 'R_{C1,C2}');
hold on;
plot(phaseShift, crossC12(phaseShift + 1), 'ro', ...
    'MarkerFaceColor', 'r', 'DisplayName', 'Peak');
grid on;
xlabel('Cyclic shift (chips)');
ylabel('Unnormalized cross-correlation');
title(sprintf('C1/C2 cyclic cross-correlation (phase shift = %d chips)', phaseShift));
xlim([0 sequenceLength-1]);
legend('Location', 'best');
saveas(gcf, fullfile(outputDirectory, 'm_sequence_cross_correlation.png'));

summaryPath = fullfile(outputDirectory, 'm_sequence_results.txt');
fileId = fopen(summaryPath, 'w');
assert(fileId >= 0, 'Could not create the result summary file.');
cleanupFile = onCleanup(@() fclose(fileId));
fprintf(fileId, 'Polynomial: 1 + x^2 + x^3 + x^6 + x^8 + x^9 + x^10\n');
fprintf(fileId, 'Register length: %d\n', registerLength);
fprintf(fileId, 'Sequence length: %d\n', sequenceLength);
fprintf(fileId, 'Initial state: all ones\n');
fprintf(fileId, 'Logic mapping: 0 -> +1, 1 -> -1\n');
fprintf(fileId, 'Correlation convention: Rxy(k) = sum_n x(n) y(n-k)\n');
fprintf(fileId, 'C1 balance (+1/-1): %d/%d\n', sum(C1 == 1), sum(C1 == -1));
fprintf(fileId, 'C2 balance (+1/-1): %d/%d\n', sum(C2 == 1), sum(C2 == -1));
fprintf(fileId, 'Autocorrelation: R(0) = %d; R(k) = -1 for k = 1,...,%d\n', ...
    autoC1(1), sequenceLength-1);
fprintf(fileId, 'C2 = circshift(C1, -%d)\n', phaseShift);
fprintf(fileId, 'C1/C2 cross-correlation peak: %d at cyclic shift %d\n', ...
    max(crossC12), peakIndex);
clear cleanupFile;

fprintf('Sequence length: %d chips\n', sequenceLength);
fprintf('C1/C2 phase shift: %d chips\n', phaseShift);
fprintf('Cross-correlation peak: %d\n', max(crossC12));
fprintf('Wrote figures and summary to: %s\n', outputDirectory);

function sequence = generateStructureI(state, count, feedbackStages)
sequence = zeros(1, count);
initial = state;
for index = 1:count
    sequence(index) = state(10);
    feedback = mod(sum(state([feedbackStages 10])), 2);
    state = [feedback; state(1:9)];
end
assert(isequal(state, initial), 'Register did not return to its initial state.');
end

function sequence = generateStructureII(state, count, feedbackStages)
sequence = zeros(1, count);
initial = state;
for index = 1:count
    output = state(10);
    sequence(index) = output;
    nextState = [output; state(1:9)];
    tapIndices = 11 - feedbackStages;
    nextState(tapIndices) = mod(nextState(tapIndices) + output, 2);
    state = nextState;
end
assert(isequal(state, initial), 'Register did not return to its initial state.');
end

function result = cyclicCorrelation(first, second)
count = numel(first);
result = zeros(1, count);
% Rxy(k) = sum_n first(n) * second(n-k), with periodic indexing.
for shift = 0:count-1
    result(shift + 1) = sum(first .* circshift(second, [0 shift]));
end
end

function shift = findPhaseShift(reference, candidate)
count = numel(reference);
shift = [];
for offset = 0:count-1
    if isequal(candidate, circshift(reference, [0 -offset]))
        shift = offset;
        return;
    end
end
error('The generated sequences are not cyclic shifts of one another.');
end
