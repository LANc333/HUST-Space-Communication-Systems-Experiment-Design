function verify_dll_experiment
testDirectory = tempname;
mkdir(testDirectory);
cleanup = onCleanup(@() rmdir(testDirectory, 's'));

results = run_dll_experiment(testDirectory);
offsets = results.correlation.delayErrorChips;
zeroIndex = find(offsets == 0, 1);

assert(results.parameters.PRN == 20);
assert(numel(results.caCode) == 1023);
assert(all(ismember(results.caCode, [-1 1])));
assert(offsets(1) == -100 && offsets(end) == 100);
assert(abs(abs(results.correlation.matchedDoppler(zeroIndex)) - ...
    results.parameters.samplesPerMillisecond) < 1e-8);

gainRatio = abs(results.correlation.mismatchedDoppler(zeroIndex)) / ...
    abs(results.correlation.matchedDoppler(zeroIndex));
assert(gainRatio > 0.62 && gainRatio < 0.65);

assert(max(abs(results.dll.phase0.coherent + ...
    results.dll.phase180.coherent)) < 1e-8);
assert(max(abs(results.dll.phase0.envelope - ...
    results.dll.phase180.envelope)) < 1e-8);
assert(max(abs(results.dll.phase0.power - ...
    results.dll.phase180.power)) < 1e-3);
assert(abs(results.dll.phase0.coherent(zeroIndex)) < 1e-8);

for index = 1:numel(results.noise.snrDb)
    assert(all(isfinite(results.noise.discriminators(index).coherent)));
    assert(all(isfinite(results.noise.discriminators(index).envelope)));
    assert(all(isfinite(results.noise.discriminators(index).power)));
end

clear cleanup;
fprintf('DLL experiment verification passed.\n');
end
