% generate_opto_writein_and_ao_G4
% Batch-generate MATCHED write-in position functions and corresponding AO
% functions for multiple parameter versions - modeled on generate_patt_and_func_G4.
%
%   position function : make_func_opto_write_in  (your write-in bar function)
%   AO function       : make_func_ao_pulses      (pulse per bar presentation)
%
% For each version, the AO delivers a brief pulse at the ONSET of each bar
% presentation (when that bar position is first shown). The pulse does NOT track
% the strobe - it just marks each onset. Onset timing is sample-accurate, so it
% stays aligned even when strobing changes the on-segment length. One integer ID
% is used for BOTH
% func<ID>.pfn and ao<ID>.afn (different prefixes, so no file collision), and
% that ID is what you pass in combinedCommand as the position functionID and the
% ao0FunctionID.
%
% Run with PControl_Matlab on the path (userSettings, make_func_opto_write_in,
% make_func_ao_pulses, save_function_G4, create_currentExp, ...).

writeInUserSettings

% ---------------------------------------------------------------------------
% TWO different clocks (this matters - they are NOT the same):
%   funcFreq_pos : the rate the POSITION function plays at. Must match the value
%                  hard-coded in make_func_opto_write_in.m (currently 389). This
%                  is used to build the .pfn AND to compute the real-time pulse
%                  times (in seconds) for the AO.
%   funcFreq_ao  : the rate ANALOG OUTPUT functions actually play at. NOMINALLY
%                  this is 1000 Hz (see G4_Function_Generator: "afn rate is always
%                  1 kHz"), but - just like the position clock (nominal 500 ->
%                  actual ~389 on this rig) - the hardware runs it slow by the
%                  same factor. Nominal AO/position = 1000/500 = 2, so the ACTUAL
%                  AO rate = 2 x actual position rate. Build the AO at this
%                  measured rate or its pulses drift ~580 ms per bar.
%                  Calibrate exactly the same way you found 389: from the pulse
%                  offsets. Refine funcFreq_ao if any residual drift remains.
% ---------------------------------------------------------------------------
funcFreq_pos = 389;    % position function build/playback rate
funcFreq_ao  = 2*funcFreq_pos;   % 778

% ---- AO pulse design (applied to every version) ----
% A brief pulse marks the start of each bar presentation.
ao_amp       = 5;      % V, AO pulse amplitude
ao_delay     = 0.010;  % s, shift pulses later to match the ~12 ms arena-position
                       % display latency (measured on your rig; retune if needed)
ao_pulse_dur = 0.05;   % s, pulse width at each bar onset ([] = span the whole window)
ao_baseline  = 0;      % V, output between pulses

% ---- VERSIONS ----
% One row per matched pair. Columns are the make_func_opto_write_in inputs:
%    ID  barStartLoc  onDur  offDur  numMarkPoints  strobeBar  strobeOnDur  strobeOffDur
V = {
      1,   0,         2,     0,      8,             0,         0,           0
      2,   96,        2,     0,      8,             0,         0,           0
      3,   0,         2,     0,      8,             1,         0.4,         0.8
      4,   96,        2,     0,      8,             1,         0.4,         0.8
   };

fprintf('Generating %d matched pairs (position %g Hz, AO %g Hz)...\n', ...
    size(V,1), funcFreq_pos, funcFreq_ao);

for i = 1:size(V,1)
    ID           = V{i,1};
    barStartLoc  = V{i,2};
    onDur        = V{i,3};
    offDur       = V{i,4};
    numMarkPoints= V{i,5};
    strobeBar    = V{i,6};
    strobeOnDur  = V{i,7};
    strobeOffDur = V{i,8};

    % --- position function (write-in) ---
    % make_func_opto_write_in always reads the 3 optional strobe args, so pass
    % all three even when strobeBar == 0.
    make_func_opto_write_in(ID, barStartLoc, onDur, offDur, numMarkPoints, ...
        strobeBar, strobeOnDur, strobeOffDur);

    % --- matching AO timeline ---
    % Onsets/widths/totalDur are in SECONDS (real time), computed from the
    % position clock (funcFreq_pos) so they line up with the bar presentations.
    [onsets, widths, totalDur] = writein_ao_timeline(funcFreq_pos, onDur, offDur, ...
        numMarkPoints, strobeBar, strobeOnDur, strobeOffDur, ao_delay, ao_pulse_dur);

    % Build the AO function at the AO clock (1 kHz). Same real-time onsets, but
    % sampled at 1000 Hz so it plays back correctly.
    aoName = sprintf('writein_AO_ID%d_%dmark_on%g_off%g', ID, numMarkPoints, onDur, offDur);
    make_func_ao_pulses(ID, totalDur, onsets, widths, ao_amp, ...
        'funcFreq', funcFreq_ao, 'baseline', ao_baseline, ...
        'name', aoName, 'overwrite', true);

    fprintf('  ID %d: %d presentations, %.4f s total, AO onsets = %s s\n', ...
        ID, numMarkPoints, totalDur, mat2str(round(onsets,3)));
end

% ---- compile the experiment so the controller can load the new functions ----
% (recompiles whatever is in the experiment's Patterns/Functions folders)
create_currentExp(exp_path)
disp('complete!')

% =========================================================================
% local function - MUST mirror the segment construction in
% make_func_opto_write_in.m. If you change the timeline in that file, update
% this to match, or the AO pulses will drift off the bar presentations.
% =========================================================================
function [onsets, widths, totalDur] = writein_ao_timeline(funcFreq, onDur, ...
        offDur, numMarkPoints, strobeBar, strobeOnDur, strobeOffDur, ...
        ao_delay, ao_pulse_dur)

    breakLen = round(offDur * funcFreq);                 % "behind fly" break segment
    if strobeBar == 0
        onLen = round(onDur * funcFreq);                 % bar held for onDur
    else
        strobeCycle     = strobeOnDur + strobeOffDur;
        numStrobeCycles = round(onDur / strobeCycle);
        onLen = numStrobeCycles * (round(strobeOnDur*funcFreq) + round(strobeOffDur*funcFreq));
    end

    N        = breakLen + numMarkPoints*(onLen + breakLen);
    totalDur = N / funcFreq;

    % 0-based sample onset of each presentation (make_func_ao_pulses adds the +1)
    onsetSamples = breakLen + (0:numMarkPoints-1)*(onLen + breakLen);
    onsets = onsetSamples/funcFreq + ao_delay;

    if isempty(ao_pulse_dur)
        widths = repmat(onLen/funcFreq - ao_delay, 1, numMarkPoints);   % span the window
    else
        widths = repmat(ao_pulse_dur, 1, numMarkPoints);                % fixed width
    end
end
