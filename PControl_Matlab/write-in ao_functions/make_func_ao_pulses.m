function make_func_ao_pulses(funcN, totalDur, pulseOnsets, pulseWidths, pulseAmps, varargin)
%MAKE_FUNC_AO_PULSES  Build & save an analog-output (.afn) function with voltage
% pulses at arbitrary times. Structured like the make_func_* / generate_AO_*
% files in this repo and saved by integer ID via save_function_G4, so it is
% referenced the same way as a position function in combinedCommand /
% setAOFunctionID (ao<funcN>.afn).
%
% Requires on the MATLAB path (part of PControl_Matlab): userSettings,
% save_function_G4, ADConvert, signed_16Bit_to_char, dec2char.
%
% USAGE
%   make_func_ao_pulses(1, 10, [2 5 8], 0.1, 5)
%       -> ao0001.afn : 10 s function, 0.1 s / 5 V pulses at t = 2, 5, 8 s.
%   make_func_ao_pulses(2, 10, [2 5 8], [0.05 0.1 0.2], [5 5 10], 'overwrite',true,'plot',true)
%       -> per-pulse widths and amplitudes, overwrite existing, show preview.
%
% REQUIRED
%   funcN        integer function ID  -> saved as ao<funcN,%04d>.afn
%   totalDur     total function duration (s). MUST match the position function
%                it plays with:  totalDur*funcFreq == position-function samples.
%   pulseOnsets  vector of pulse start times (s from function start)
%   pulseWidths  pulse durations (s): scalar (applies to all) or per-pulse vector
%   pulseAmps    pulse voltages (V, -10..10): scalar or per-pulse vector
%
% OPTIONAL name/value
%   'funcFreq'   AO functions are NOMINALLY 1 kHz, but the
%                hardware runs them slow by the same factor as the display clock
%                (e.g. ~778 Hz when the position clock is ~389). Build at the
%                MEASURED AO rate, not the nominal 1000, or pulses drift ~580 ms
%                per interval. Do NOT build at the position rate either (that
%                makes it play too fast and loop).
%   'baseline'   voltage between pulses (V). default 0
%   'saveDir'    folder for ao####.afn. default [exp_path filesep 'Functions']
%                (put it wherever your experiment loads .afn from - same place
%                 as your .pfn files)
%   'name'       label stored in the .mat. default auto-generated
%   'overwrite'  logical, delete existing files of this ID first. default false
%   'plot'       logical, preview the waveform. default false

% ---------------- parse optional args ----------------
ip = inputParser;
ip.addParameter('funcFreq', 1000, @(x) isscalar(x) && x > 0);  % AO always plays at 1 kHz
ip.addParameter('baseline', 0,    @(x) isscalar(x));
ip.addParameter('saveDir',  '',   @(x) ischar(x) || isstring(x));
ip.addParameter('name',     '',   @(x) ischar(x) || isstring(x));
ip.addParameter('overwrite', false, @(x) islogical(x) || ismember(x,[0 1]));
ip.addParameter('plot',      false, @(x) islogical(x) || ismember(x,[0 1]));
ip.parse(varargin{:});
opt = ip.Results;
funcFreq = opt.funcFreq;

% ---------------- default save dir from userSettings ----------------
if isempty(char(opt.saveDir))
    writeInUserSettings;                                  % defines exp_path, etc.
    saveDir = fullfile(exp_path, 'Analog Output Functions');
else
    saveDir = char(opt.saveDir);
end
if ~exist(saveDir, 'dir'); mkdir(saveDir); end

% ---------------- expand scalar width/amp to per-pulse ----------------
nP = numel(pulseOnsets);
if isscalar(pulseWidths); pulseWidths = repmat(pulseWidths, 1, nP); end
if isscalar(pulseAmps);   pulseAmps   = repmat(pulseAmps,   1, nP); end
assert(numel(pulseWidths) == nP && numel(pulseAmps) == nP, ...
    'pulseWidths and pulseAmps must be scalar or the same length as pulseOnsets.');
assert(all(abs(pulseAmps) <= 10) && abs(opt.baseline) <= 10, ...
    'voltages must be within -10..10 V.');

% ---------------- build the waveform ----------------
N = round(totalDur * funcFreq);
anaSig = ones(1, N) * opt.baseline;
pulseIdx = zeros(1, nP);
for k = 1:nP
    i0 = round(pulseOnsets(k) * funcFreq) + 1;      % +1: MATLAB is 1-based
    i1 = i0 + max(1, round(pulseWidths(k) * funcFreq)) - 1;
    assert(i0 >= 1 && i1 <= N, ...
        sprintf('pulse %d (%.4f s + %.4f s) falls outside 0..%.4f s.', ...
        k, pulseOnsets(k), pulseWidths(k), totalDur));
    anaSig(i0:i1) = pulseAmps(k);
    pulseIdx(k) = i0;
end

% ---------------- name ----------------
if isempty(char(opt.name))
    name = sprintf('ao_pulses_%dpulse_%gV', nP, max(pulseAmps));
else
    name = char(opt.name);
end

% ---------------- overwrite handling (save_function_G4 errors on existing) ----------------
afnFile = fullfile(saveDir, sprintf('ao%04d.afn', funcN));
matFile = fullfile(saveDir, sprintf('%04d_%s_G4.mat', funcN, name));
if opt.overwrite
    if exist(afnFile, 'file'); delete(afnFile); end
    if exist(matFile, 'file'); delete(matFile); end
end

% ---------------- save via the repo's canonical routine ----------------
% save_function_G4 validates the -10..10 V range, runs ADConvert, writes the
% 512-byte header + int16 data to ao<ID>.afn, and saves the afnparam .mat.
afnparam.type     = 'afn';
afnparam.ID       = funcN;
afnparam.funcFreq = funcFreq;
afnparam.dur      = N / funcFreq;
afnparam.onsets   = pulseOnsets;
afnparam.widths   = pulseWidths;
afnparam.amps     = pulseAmps;
afnparam.baseline = opt.baseline;
save_function_G4(anaSig, afnparam, saveDir, name);

fprintf('Wrote %s  (%d samples, %.4f s at %g Hz, %d pulses) in %s\n', ...
    sprintf('ao%04d.afn', funcN), N, N/funcFreq, funcFreq, nP, saveDir);
fprintf('Pulse start sample indices: %s\n', mat2str(pulseIdx));

% ---------------- optional preview ----------------
if opt.plot
    t = (0:N-1) / funcFreq;
    figure; plot(t, anaSig, 'LineWidth', 1.2);
    xlabel('time (s)'); ylabel('AO voltage (V)');
    title(sprintf('ao%04d.afn  (%s)', funcN, name), 'Interpreter', 'none');
    ylim([-10.5 10.5]); grid on;
end

end
