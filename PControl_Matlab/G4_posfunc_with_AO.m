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
func_id = 2;
pos_func_id = func_id;         % ID of your custom position function (.pfn)
ao_func_id  = func_id;         % ID of your custom AO function (.afn)
ao_channel  = 2;         % FUNCTION-capable AO channel: 2, 3, 4, or 5 ONLY.
                         % (AO6/AO7 are static-only and cannot play a function -
                         %  wire your opto BNC into breakout-box AO2 for ao_channel=2.)
funcFreq    = 395;       % TRUE Mode-1 hardware playback rate (Hz), measured from the
                         % logged Frame_Position/Frame_Time trace of a 20-rep run:
                         % clean bar presentations are 954 build-samples and play in
                         % 2.4169 s -> 395 Hz (+-1). That is ~0.8% SLOWER than the 398
                         % Hz the .pfn is BUILT at (make_func_opto_write_in), NOT
                         % faster. func_dur_s below = nSampPos/funcFreq, so using the
                         % true 395 makes func_dur_s equal the real cycle length and
                         % centers dur_deci in the trailing dark. dur_trim_s still
                         % absorbs any residual.
n_reps      = 3;
dur_trim_s  = [];        % seconds shaved off each rep's runtime (dur_deci). With the
                         % blocking display, a rep runs for exactly dur_deci; if that
                         % exceeds the function's TRUE play length, Mode 1 restarts
                         % from frame 1 and you see an extra strobe at the start
                         % position. WHY A TRIM AT ALL: the function ends on a dark
                         % break (a trailing run at frame 184). If the display ends
                         % anywhere INSIDE that final break, every real strobe is
                         % shown, there's no restart, and the only thing clipped is
                         % invisible dark. That break (~0.5 s) is far wider than the
                         % few-% rate uncertainty, so we don't need the exact rate -
                         % we just aim dur_deci at the MIDDLE of the trailing break.
                         % [] (default) = auto: trim = half the function's own
                         % trailing-dark run, measured from the .pfn. Set a number to
                         % override with a fixed trim (s).

% -- Phase durations --
cl_dur   = 10;           % closed-loop seconds (phases 1 & 5)
dark_dur = 10;            % dark seconds (phases 2 & 4)

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

% ================== PHASE 3: position + AO, n_reps ==================
% Read the function durations now (not at the top) so phases 1-2 run even if the
% function files are misplaced. Position .pfn is sampled at funcFreq (~389 Hz);
% the AO .afn at ~778 Hz - different sample counts, same real-time duration.
[func_dur_s, nSampPos, ~, posFunc] = get_g4_func_dur(pos_func_id, 'pfn', funcFreq, posFuncDir);
ao_dur_s = get_g4_func_dur(ao_func_id, 'afn', [], aoFuncDir);   % [] -> the AO's own stored rate
assert(ao_dur_s >= func_dur_s - 0.02, ...
    'AO function (%.3f s) is shorter than the position function (%.3f s) - it will loop/repeat. Rebuild the AO with padding.', ...
    ao_dur_s, func_dur_s);

% Auto-trim: land dur_deci in the MIDDLE of the function's trailing dark break so a
% restart is impossible for any plausible true rate, and only invisible dark is
% clipped. Count the trailing run of samples equal to the dark frame (184) and shave
% half of it (in seconds, at funcFreq). Falls back to a fixed 0.5 s if the vector
% isn't available or the function doesn't end dark.
if isempty(dur_trim_s)
    if ~isempty(posFunc) && posFunc(end) == dark_frame_index
        k = numel(posFunc);
        while k > 1 && posFunc(k-1) == dark_frame_index; k = k - 1; end
        trailDark_samp = numel(posFunc) - k + 1;           % length of the trailing 184-run
        dur_trim_s = 0.5 * trailDark_samp / funcFreq;      % half of it, in seconds
        fprintf('Auto-trim: trailing dark run = %d samples (%.3f s); trimming half = %.3f s.\n', ...
            trailDark_samp, trailDark_samp/funcFreq, dur_trim_s);
    else
        dur_trim_s = 0.5;
        warning(['Could not read a trailing dark run from the position function; ' ...
                 'using dur_trim_s = 0.5 s. Check that it ends at frame %d.'], dark_frame_index);
    end
end
dur_deci = round((func_dur_s - dur_trim_s) * 10);
fprintf('Phase-3 functions (pos %d / ao %d): %d samples, %.4f s/rep (dur_deci %.1f s), AO on ch %d.\n', ...
    pos_func_id, ao_func_id, nSampPos, func_dur_s, dur_deci/10, ao_channel);

% Pattern was set once in CONNECT (it never changes). Only the fast mode/function/
% AO-ID commands are set per rep.
ctlr.stopDisplay();

for r = 1:n_reps
    fprintf('[%.1f s] Phase 3: function rep %d/%d\n', toc(protocol_timer), r, n_reps);
    ctlr.sendSyncLog(MARK, 30 + r);
    ctlr.setControlMode(1);                        % Fixed Rate Position Function
    ctlr.setPatternFunctionID(pos_func_id);
    ctlr.setAOFunctionID(ao_channel, ao_func_id);  % ao_channel is 2-5
    % BLOCKING display: MATLAB waits for the controller's own "Sequence completed"
    % after exactly dur_deci, instead of a MATLAB pause (which jittered and caused
    % early cut-offs / late restarts). The display self-terminates, so no pause and
    % no stopDisplay are needed between reps. Keep dur_deci = one function length
    % (raise dur_trim_s a hair only if you see a restarted strobe at the very end).
    ctlr.startDisplay(dur_deci, true);
end
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
