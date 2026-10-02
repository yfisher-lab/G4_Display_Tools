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
%   funcFreq_ao  : the AO clock - a SEPARATE hardware clock. What governs AO-to-bar
%                  alignment is the RATIO funcFreq_ao/funcFreq_pos: the generator
%                  places each pulse at onsetSamples*ratio, so on playback the
%                  onsetSamples cancels (and with it run-to-run absolute-rate wobble)
%                  only if ratio = R_ao/R_pos. The nominal 2.0 holds up in practice -
%                  the 10-01 run's pulses 2..N were all aligned at funcFreq_ao=790,
%                  so there's no measurable cumulative drift and 2.0 is correct. (If a
%                  future run DOES show offset growing with time-into-rep, that's a
%                  ratio error - recalibrate it from the logged AO.)
% ---------------------------------------------------------------------------
funcFreq_pos = 395;                  % position clock (build = play); match make_func_opto_write_in
funcFreq_ao  = 2 * funcFreq_pos;     % = 790; separate AO hardware clock (2 x position)

% FREE-RUN design: the protocol plays ONE continuous display and lets the position
% function loop internally n_reps times (internal loops are seamless - only the first
% startDisplay incurs the startup hold). So the AO function must span the WHOLE run,
% not one cycle. We build it to cover max_reps_ao cycles of pulses, each cycle's
% pulses placed at their own absolute time (no AO looping), so the protocol can run
% any n_reps up to this many. The display stops before the AO ends, leaving the
% surplus pulses unreached.
max_reps_ao = 50;                    % AO covers up to this many reps (protocol asserts n_reps <= this)

% Leading dark blank (s) at the start of the position CYCLE so the first bar is hidden
% during the startDisplay startup hold (keeps the first AO pulse aligned - nothing to
% discard). Because the cycle loops, this dark recurs before every rep; it only needs
% to exceed the ~150 ms hold. This ONE value feeds BOTH the .pfn (via make_func) and
% the AO timeline below, so they always match - a mismatch slips the AO by one blank
% PER REP (that was the 0.25 s/rep -> 1.3 s drift). The readback assert in the loop
% guards against an old make_func that silently ignores this argument.
leadBlankDur = 0.20;                 % s (> observed ~150 ms startup hold)

% ---- AO pulse design (applied to every version) ----
% A brief pulse marks the start of each bar presentation.
ao_amp       = 5;      % V, AO pulse amplitude
ao_delay     = 0.018;  % s, offset of each AO pulse relative to the frame change.
                       % Measured from the ADC2 loopback vs the Frame log: the
                       % displayed bar lags the function pointer by a ~12.8 ms display
                       % latency with ~+-3.4 ms jitter, so the NET AO-vs-bar offset =
                       % ao_delay - 12.8 ms. 18 ms centers the net at ~+5 ms (AO just
                       % after the bar), so the jitter mostly stays inside your target
                       % [0, +10 ms] (aligned or small lag, rarely a <2 ms lead). The
                       % ~+-3-7 ms jitter is DISPLAY latency (hardware) and can't be
                       % removed by ao_delay. Nudge up ~1 ms for fewer leads (more lag),
                       % down ~1 ms for the reverse.
ao_pulse_dur = 0.05;   % s, pulse width at each bar onset ([] = span the whole window)
ao_baseline  = 0;      % V, output between pulses

% ---- VERSIONS ----
% One row per matched pair. Columns are the make_func_opto_write_in inputs:
%    ID  barStartLoc  onDur  offDur  numMarkPoints  strobeBar  strobeOnDur  strobeOffDur
V = {
      1,   0,         2.4,   0,      8,             0,         0,           0
      2,   96,        2.4,   0,      8,             0,         0,           0
      3,   0,         2.4,   0,      8,             1,         0.4,         0.8
      4,   96,        2.4,   0,      8,             1,         0.4,         0.8
      5,   0,         2.4,   0,      8,             1,         0.15,        0.3
      6,   96,        2.4,   0,      8,             1,         0.15,        0.3
      7,   0,         2.4,   0,      8,             1,         0.03,        0.06
      8,   96,        2.4,   0,      8,             1,         0.03,        0.06
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
    % all three even when strobeBar == 0; the 4th optional arg is the leading blank.
    make_func_opto_write_in(ID, barStartLoc, onDur, offDur, numMarkPoints, ...
        strobeBar, strobeOnDur, strobeOffDur, leadBlankDur);

    % --- matching AO timeline (ONE position cycle) ---
    % Onsets/widths/totalDur are in SECONDS (real time), computed from the
    % position clock (funcFreq_pos) so they line up with the bar presentations.
    % totalDur is one position-function CYCLE (incl. the leading blank) - the period
    % the .pfn loops at. The leading blank shifts every onset so pulse 1 stays aligned.
    [onsets, widths, totalDur] = writein_ao_timeline(funcFreq_pos, onDur, offDur, ...
        numMarkPoints, strobeBar, strobeOnDur, strobeOffDur, ao_delay, ao_pulse_dur, ...
        leadBlankDur);

    % --- VERIFY the .pfn actually got the leading blank ---------------------------
    % An OLD make_func_opto_write_in silently ignores the leadBlankDur argument, which
    % leaves the position function WITHOUT the lead while the AO timeline above still
    % adds it -> the AO slips one blank PER REP (the 0.25 s/rep, 1.3 s-by-rep-5 drift).
    % Read the .pfn back and confirm its sample count matches the timeline AND it
    % starts with the dark blank; error loudly if not.
    N_expected = round(totalDur * funcFreq_pos);
    leadLenExp = round(leadBlankDur * funcFreq_pos);
    pfnMats = dir(fullfile(exp_path, 'Functions', sprintf('%04d_*.mat', ID)));
    pfnMats = pfnMats(~endsWith({pfnMats.name}, '_G4.mat'));      % exclude AO .mats
    assert(~isempty(pfnMats), 'No .pfn .mat found for ID %d to verify.', ID);
    [~, newest] = max([pfnMats.datenum]);
    Spf = load(fullfile(pfnMats(newest).folder, pfnMats(newest).name));
    nSampActual = numel(Spf.pfnparam.func);
    assert(nSampActual == N_expected, ...
        ['Position function ID %d has %d samples but the AO timeline expects %d. The ' ...
         'leading blank is missing/mismatched - your make_func_opto_write_in.m is almost ' ...
         'certainly an OLD version that ignores leadBlankDur. Update that file and rerun.'], ...
        ID, nSampActual, N_expected);
    assert(all(Spf.pfnparam.func(1:leadLenExp) == 184), ...
        'Position function ID %d does not start with the %d-sample (%.3f s) dark leading blank.', ...
        ID, leadLenExp, leadBlankDur);

    % --- repeat the cycle's pulses across the whole run (FREE-RUN) ---
    % The position .pfn loops internally every totalDur seconds. So pulse-set for
    % loop c sits at the same within-cycle onsets shifted by c*totalDur. Place each
    % pulse at its own absolute time (no AO looping) for max_reps_ao loops, so the
    % AO stays locked to the bars across the entire run with no per-loop rounding.
    onsets_all = [];  widths_all = [];
    for c = 0:max_reps_ao-1
        onsets_all = [onsets_all, onsets + c*totalDur];   %#ok<AGROW>
        widths_all = [widths_all, widths];                %#ok<AGROW>
    end
    % Baseline tail so the AO always OUTLASTS the display (the protocol stops it
    % after n_reps cycles, well before here) and never loops back to re-fire.
    ao_totalDur = max_reps_ao*totalDur + 0.5;

    % Build the AO function at the AO clock. Same real-time onsets, sampled at
    % funcFreq_ao so it plays back correctly.
    aoName = sprintf('writein_AO_ID%d_%dmark_on%g_off%g', ID, numMarkPoints, onDur, offDur);
    make_func_ao_pulses(ID, ao_totalDur, onsets_all, widths_all, ao_amp, ...
        'funcFreq', funcFreq_ao, 'baseline', ao_baseline, ...
        'name', aoName, 'overwrite', true);

    fprintf('  ID %d: %d presentations, cycle %.3f s, AO spans %d cycles = %.1f s, cycle onsets = %s s\n', ...
        ID, numMarkPoints, totalDur, max_reps_ao, ao_totalDur, mat2str(round(onsets,3)));
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
        ao_delay, ao_pulse_dur, leadBlankDur)

    % funcFreq is BOTH the build rate (for sample counts) and the play rate (for
    % seconds) - valid only because make_func_opto_write_in builds at this same
    % rate. The sample counts below must match its segment construction exactly.
    leadLen  = round(leadBlankDur * funcFreq);           % leading dark blank (matches make_func)
    breakLen = round(offDur * funcFreq);                 % "behind fly" break segment
    if strobeBar == 0
        onLen = round(onDur * funcFreq);                 % bar held for onDur
    else
        strobeCycle     = strobeOnDur + strobeOffDur;
        numStrobeCycles = round(onDur / strobeCycle);
        onLen = numStrobeCycles * (round(strobeOnDur*funcFreq) + round(strobeOffDur*funcFreq));
    end

    N        = leadLen + breakLen + numMarkPoints*(onLen + breakLen);
    totalDur = N / funcFreq;

    % 0-based sample onset of each presentation (make_func_ao_pulses adds the +1),
    % converted to real seconds so the AO lands when the bar does. The leading blank
    % shifts every onset by leadLen, matching the position function.
    onsetSamples = leadLen + breakLen + (0:numMarkPoints-1)*(onLen + breakLen);
    onsets = onsetSamples/funcFreq + ao_delay;

    if isempty(ao_pulse_dur)
        widths = repmat(onLen/funcFreq - ao_delay, 1, numMarkPoints);   % span the window
    else
        widths = repmat(ao_pulse_dur, 1, numMarkPoints);                % fixed width
    end
end
