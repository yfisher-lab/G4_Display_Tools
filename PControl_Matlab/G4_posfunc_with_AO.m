%% G4 experimental protocol - mode-switching sequence
%   Phase 1:  Mode 7 closed loop            cl_dur  s   (bar tracks ADC0 / FicTrac)
%   Phase 2:  Dark                          dark_dur s
%   Phase 3:  Position function + AO        n_reps  x   (Mode 1, custom .pfn + .afn)
%   Phase 4:  Dark                          dark_dur s
%   Phase 5:  Mode 7 closed loop            cl_dur  s
%   End:      Arena off (dark)
%
% DARK / OFF: "dark" is done with Mode 3 (single static frame) holding the pattern
% at its dark frame (index 184). Displays are FINITE and non-blocking - each phase
% runs for its duration on the controller's clock and self-terminates, so the last
% held frame stays up (dark, at the end).
%
% BEFORE RUNNING: your FicTrac -> Phidget heading output must be running in the
% background (live heading to ADC0) for the Mode 7 phases.

% ============================ PARAMETERS ============================
exp_folder       = 'C:\Users\Fisher Lab\Documents\GitHub\G4_Display_Tools\PControl_Matlab\Write-In Experiment';
pattern_id       = 1;    % write-in bar pattern (with dark frame) in the Write-In Experiment
dark_frame_index = 184;  % 0-based controller index of the dark/blank frame.
                         % The pattern sets it at MATLAB Pats(:,:,185) (1-based) =
                         % controller index 184, which is also the "bar behind the
                         % fly" break value (184) in make_func_opto_write_in.
                         % setPositionX is 0-based, so use 184, not 185. (If the
                         % dark phase isn't dark, confirm this pattern's dark index.)

% -- Mode 7 closed-loop calibration (phases 1 & 5) --
num_x_frames  = 192;
voltage_range = 10;
gain          = round(num_x_frames / voltage_range);   % = 19
offset        = 0;

% -- Phase 3 function playback --
pos_func_id = 7;         % ID of your custom position function (.pfn)
ao_func_id  = 7;         % ID of your custom AO function (.afn)
ao_channel  = 2;         % FUNCTION-capable AO channel: 2, 3, 4, or 5 ONLY.
                         % (AO6/AO7 are static-only and cannot play a function -
                         %  wire your opto BNC into breakout-box AO2 for ao_channel=2.)
funcFreq    = 395;       % TRUE Mode-1 hardware playback rate (Hz), measured from the
                         % logged Frame_Position/Frame_Time trace: clean bar
                         % presentations play in 2.4169 s -> 395 Hz (+-1). Used as
                         % func_dur_s = nSampPos/funcFreq = one cycle length, which
                         % sets the free-run display duration (n_reps * func_dur_s).
                         % NOTE: the true rate drifts ~2% run-to-run, so the number of
                         % COMPLETE loops in that fixed time = n_reps*(true_rate/395)
                         % may be off by ~+-1; count actual reps from the Frame log.
n_reps      = 5;

% -- Phase durations --
cl_dur   = 5;           % closed-loop seconds (phases 1 & 5)
dark_dur = 5;            % dark seconds (phases 2 & 4)

MARK = 99;               % sendSyncLog marker class for phase boundaries

assert(ao_channel >= 2 && ao_channel <= 5, ...
    'ao_channel must be 2-5 (function-capable). AO6/AO7 cannot play a function.');

% Folders holding the saved function files (as written by the writeInUserSettings
% generator): position .pfn in <exp>\Functions, AO .afn in <exp>\Analog Output
% Functions. Used only for the MATLAB-side duration reads below.
posFuncDir = fullfile(exp_folder, 'Functions');
aoFuncDir  = fullfile(exp_folder, 'Analog Output Functions');

% ============================ CONNECT ============================
ctlr = PanelsController();
ctlr.open(true);
ctlr.setRootDirectory(exp_folder);
ctlr.setPatternID(pattern_id);          % set ONCE here - the pattern never changes
                                        % across the protocol, and reloading it per
                                        % phase/rep caused multi-second G4-side load
                                        % delays that desynced the timing.
ctlr.setActiveAOChannels(ao_channel);
ctlr.setActiveAIChannels([0 1 2]);      % log AI0 (bar/ADC0), AI1 (marker, if wired),
                                        % and AI2 (AO monitor). Loop the AO2 BNC
                                        % output into the ADC2 input so the 5 V opto
                                        % pulses are recorded in ADC2 - the AO channel
                                        % does not log itself (AO2 writes 0 samples),
                                        % so this is how we verify the AO plays at the
                                        % expected ~790 Hz (measure pulse spacing in
                                        % ADC2 the way the bar rate came from Frame_*).

if ~ctlr.startLog()
    warning('Log failed to start. Check G4 Host.'); ctlr.close(); return;
end
protocol_timer = tic;

% ======================= PHASE 1: closed loop =======================
fprintf('[%.1f s] Phase 1: Mode 7 closed loop (%d s)\n', toc(protocol_timer), cl_dur);
ctlr.sendSyncLog(MARK, 1);
run_closed_loop(ctlr, gain, offset, cl_dur);

% ============================ PHASE 2: dark ============================
fprintf('[%.1f s] Phase 2: dark (%d s)\n', toc(protocol_timer), dark_dur);
ctlr.sendSyncLog(MARK, 2);
show_dark(ctlr, dark_frame_index, dark_dur);

% ================== PHASE 3: position + AO, n_reps (FREE-RUN) ==================
% Read the function durations now (not at the top) so phases 1-2 run even if the
% function files are misplaced. func_dur_s is ONE position-function cycle (the period
% the .pfn loops at). The AO .afn is built to span many cycles (see the generator).
[func_dur_s, nSampPos] = get_g4_func_dur(pos_func_id, 'pfn', funcFreq, posFuncDir);
ao_dur_s = get_g4_func_dur(ao_func_id, 'afn', [], aoFuncDir);   % [] -> the AO's own stored rate

% FREE-RUN: instead of one startDisplay per rep, run ONE continuous display and let
% the position function LOOP internally n_reps times. Internal loops are seamless (no
% startup hold - verified from the Frame log), so only the FIRST bar/pulse of the
% whole run sees the startDisplay hold; discard that one pulse in analysis. This
% removes the per-rep first-pulse misalignment entirely.
run_dur_s  = n_reps * func_dur_s;
total_deci = round(run_dur_s * 10);

% The AO must outlast the display or it would loop and desync. (Generator builds it to
% cover max_reps_ao cycles.)
assert(ao_dur_s >= run_dur_s - 0.02, ...
    ['AO function covers %.1f s but this run needs %.1f s (n_reps=%d). Raise max_reps_ao ' ...
     'in the generator and rebuild, or lower n_reps.'], ao_dur_s, run_dur_s, n_reps);

fprintf(['Phase 3 (free-run): %d samples/cycle, %.4f s/cycle, %d reps -> %.1f s continuous.\n' ...
         '  NOTE: complete reps = n_reps * (true_rate/funcFreq) ~ %d; count actual reps from the\n' ...
         '  Frame log and discard the first pulse (startDisplay startup hold).\n'], ...
    nSampPos, func_dur_s, n_reps, run_dur_s, n_reps);

% Pattern was set once in CONNECT. Set mode/function/AO-ID ONCE, then one display.
ctlr.stopDisplay();
ctlr.sendSyncLog(MARK, 30);
ctlr.setControlMode(1);                        % Fixed Rate Position Function
ctlr.setPatternFunctionID(pos_func_id);
ctlr.setAOFunctionID(ao_channel, ao_func_id);  % ao_channel is 2-5
% BLOCKING display for the whole run: MATLAB waits for the controller's own "Sequence
% completed" after exactly total_deci. The function loops internally the whole time.
ctlr.startDisplay(total_deci, true);
% Deactivate the AO channel so the assigned AO function does NOT re-fire on the
% startDisplay of the later dark/closed-loop phases. (Cannot deassign with
% function ID 0 - the G4 rejects it as "out of range" - so turn the channel off.)
ctlr.setActiveAOChannels([]);

% ============================ PHASE 4: dark ============================
fprintf('[%.1f s] Phase 4: dark (%d s)\n', toc(protocol_timer), dark_dur);
ctlr.sendSyncLog(MARK, 4);
show_dark(ctlr, dark_frame_index, dark_dur);

% ======================= PHASE 5: closed loop =======================
fprintf('[%.1f s] Phase 5: Mode 7 closed loop (%d s)\n', toc(protocol_timer), cl_dur);
ctlr.sendSyncLog(MARK, 5);
run_closed_loop(ctlr, gain, offset, cl_dur);

% ==================== END: arena off (dark) ====================
ctlr.sendSyncLog(MARK, 0);
show_dark(ctlr, dark_frame_index, 0.3);   % leaves the held frame dark
ctlr.allOff();                                        % extra, harmless if unsupported
ctlr.stopLog('timeout', 60.0, 'showTimeoutDialog', true);
ctlr.close();
fprintf('[%.1f s] Protocol complete - arena dark.\n', toc(protocol_timer));

% ============================ HELPERS ============================
function run_closed_loop(ctlr, gain, offset, dur_s)
    % Mode 7: ADC0 (FicTrac heading) sets the bar x-index. FINITE, NON-BLOCKING
    % display (waitForEnd=false, same as the working continuous script) - it runs
    % for dur_s on the CONTROLLER's clock and self-terminates. The finite duration
    % (not run-until-stopped) is what makes it stop precisely; MATLAB just waits
    % it out. pause overshoot is harmless because the display already self-ended.
    % STOP the previous display first. Mode 7 runs continuously and IGNORES live
    % host commands while running, so a mode switch only takes effect once the
    % current display is stopped.
    ctlr.stopDisplay();
    ctlr.setControlMode(7);               % pattern was set once in CONNECT
    ctlr.setGain(gain, offset);
    ctlr.startDisplay(round(dur_s*10), false);
    pause(dur_s + 0.2);
end

function show_dark(ctlr, dark_frame_index, dur_s)
    % Mode 3 shows a SINGLE static frame chosen by the frame index. CRITICAL:
    % stopDisplay first, or the running Mode-7 loop ignores setControlMode(3).
    % The frame index must be (re)sent AFTER startDisplay - set before the start
    % it doesn't take, and the panel stays frozen on the last closed-loop frame.
    ctlr.stopDisplay();
    ctlr.setControlMode(3);               % pattern was set once in CONNECT
    ctlr.startDisplay(round(dur_s*10), false);
    for k = 1:3                            % re-send the dark frame to the running display
        ctlr.setPositionX(dark_frame_index);
        pause(0.05);
    end
    pause(dur_s);
end
