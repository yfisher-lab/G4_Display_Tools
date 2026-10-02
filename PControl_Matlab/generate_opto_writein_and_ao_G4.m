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
% TWO clocks (position and AO are genuinely different hardware clocks):
%   funcFreq_pos : the position clock, used BOTH to index the .pfn's samples AND to
%                  convert those indices to real seconds. One number works here
%                  ONLY because make_func_opto_write_in now BUILDS at this same rate
%                  (395), so build rate = play rate and the two collapse. 395 is the
%                  TRUE measured hardware rate (Frame_Position log: 954-sample bars
%                  play in 2.4169 s). MUST equal the funcFreq in
%                  make_func_opto_write_in.m. If you ever build the .pfn at a
%                  DIFFERENT rate than it plays, split this back into a build rate
%                  (for sample indices) and a play rate (for seconds).
%   funcFreq_ao  : the AO clock - a SEPARATE hardware clock, nominally 1000 Hz but
%                  slowed by the same factor as position (nominal pos 500 -> 395 is
%                  x0.79; AO 1000 x0.79 ~ 790). Nominal AO/pos = 2, so AO = 2 x pos.
%                  This can't be merged with funcFreq_pos - the AO and the bars run
%                  on different clocks, which is why the timeline below converts
%                  position-samples -> seconds -> AO-samples. (This run's AO wasn't
%                  logged - AO2 recorded 0 samples - so 790 is from the 2x
%                  relationship; confirm next run by looping AO2 into a spare ADC.)
% ---------------------------------------------------------------------------
funcFreq_pos = 395;                  % position clock (build = play); match make_func_opto_write_in
funcFreq_ao  = 2 * funcFreq_pos;     % = 790; separate AO hardware clock (2 x position)

% ---- AO pulse design (applied to every version) ----
% A brief pulse marks the start of each bar presentation.
ao_amp       = 5;      % V, AO pulse amplitude
ao_delay     = 0.016;  % s, offset of each AO pulse relative to the frame change.
                       % The displayed-frame signal lags the function command by a
                       % jittery display latency (~9-17 ms on your rig), so the AO's
                       % offset = ao_delay - that latency. 16 ms centers the AO just
                       % after the change: typically 3-7 ms after, worst-case lead
                       % ~1 ms, worst-case lag ~7 ms - inside "lead <3 ms, lag <10 ms".
                       % Nudge up ~1 ms to trade a bit more lag for fewer leads, or
                       % down ~1 ms for the reverse.
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
      5,   0,         2,     0,      8,             1,         0.15,        0.3
      6,   96,        2,     0,      8,             1,         0.15,        0.3
      7,   0,         2,     0,      8,             1,         0.03,        0.06
      8,   96,        2,     0,      8,             1,         0.03,        0.06
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

    % Pad the AO with a baseline tail so it OUTLASTS the display and can never
    % loop back to re-fire pulses. The display runtime is set by the position
    % function (see the protocol), so this tail is simply never reached. The
    % margin (~5% + 0.5 s) absorbs the small AO-rate uncertainty that would
    % otherwise let the AO finish early and repeat.
    ao_totalDur = totalDur + 0.05*totalDur + 0.5;

    % Build the AO function at the AO clock. Same real-time onsets, sampled at
    % funcFreq_ao so it plays back correctly.
    aoName = sprintf('writein_AO_ID%d_%dmark_on%g_off%g', ID, numMarkPoints, onDur, offDur);
    make_func_ao_pulses(ID, ao_totalDur, onsets, widths, ao_amp, ...
        'funcFreq', funcFreq_ao, 'baseline', ao_baseline, ...
        'name', aoName, 'overwrite', true);

    fprintf('  ID %d: %d presentations, position %.3f s, AO %.3f s (padded), onsets = %s s\n', ...
        ID, numMarkPoints, totalDur, ao_totalDur, mat2str(round(onsets,3)));
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

    % funcFreq is BOTH the build rate (for sample counts) and the play rate (for
    % seconds) - valid only because make_func_opto_write_in builds at this same
    % rate. The sample counts below must match its segment construction exactly.
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

    % 0-based sample onset of each presentation (make_func_ao_pulses adds the +1),
    % converted to real seconds at the (play) rate so the AO lands when the bar does.
    onsetSamples = breakLen + (0:numMarkPoints-1)*(onLen + breakLen);
    onsets = onsetSamples/funcFreq + ao_delay;

    if isempty(ao_pulse_dur)
        widths = repmat(onLen/funcFreq - ao_delay, 1, numMarkPoints);   % span the window
    else
        widths = repmat(ao_pulse_dur, 1, numMarkPoints);                % fixed width
    end
end
