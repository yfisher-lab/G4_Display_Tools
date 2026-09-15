%% G4 experimental protocol - mode-switching sequence
%   Phase 1:  Mode 7 closed loop            cl_dur  s   (bar tracks ADC0 / FicTrac)
%   Phase 2:  Dark                          dark_dur s
%   Phase 3:  Position function + AO        n_reps  x   (Mode 1, custom .pfn + .afn)
%   Phase 4:  Dark                          dark_dur s
%   Phase 5:  Mode 7 closed loop            cl_dur  s
%   End:      Arena off (dark)
%
% DARK / OFF: stopDisplay does NOT blank the panels - it freezes the last frame.
% So "dark" is done with Mode 3 (Stream Pattern Position) holding the current
% pattern at its DARK frame (index 185). Because we command the index directly,
% no ADC/gain mapping is involved. When we stopDisplay, the held frame is the
% dark one, so the arena stays dark.
%
% BEFORE RUNNING: your FicTrac -> Phidget heading output must be running in the
% background (live heading to ADC0) for the Mode 7 phases.

% ============================ PARAMETERS ============================
exp_folder       = 'C:\Users\Fisher Lab\Documents\GitHub\G4_Display_Tools\PControl_Matlab\Write-In Experiment';
pattern_id       = 1;   % bar pattern (closed loop + position function + dark frame)
dark_frame_index = 185;  % index of the all-dark frame in pattern_id (shown in Mode 3)
                         % NOTE: if this doesn't look dark, try 184 - some tools are
                         % 1-based while the controller position index is 0-based.

% -- Mode 7 closed-loop calibration (phases 1 & 5) --
num_x_frames  = 192;
voltage_range = 10;
gain          = round(num_x_frames / voltage_range);   % = 19
offset        = 0;

% -- Phase 3 function playback --
pos_func_id = 1;         % ID of your custom position function (.pfn)
ao_func_id  = 1;         % ID of your custom AO function (.afn)
ao_channel  = 2;         % FUNCTION-capable AO channel: 2, 3, 4, or 5 ONLY.
                         % (AO6/AO7 are static-only and cannot play a function -
                         %  wire your opto BNC into breakout-box AO2 for ao_channel=2.)
funcFreq    = 389;       % playback rate commanded to the controller
n_reps      = 3;

% -- Phase durations --
cl_dur   = 10;           % closed-loop seconds (phases 1 & 5)
dark_dur = 5;            % dark seconds (phases 2 & 4)

MARK = 99;               % sendSyncLog marker class for phase boundaries

assert(ao_channel >= 2 && ao_channel <= 5, ...
    'ao_channel must be 2-5 (function-capable). AO6/AO7 cannot play a function.');

% Read per-rep duration from the saved position function (no manual entry).
% Compare DURATIONS, not sample counts: the position function is sampled at
% funcFreq (~389 Hz) but the AO function is sampled at 1 kHz, so the two have
% different sample counts even though they last the same real time.
posFuncDir = fullfile(exp_folder, 'Functions');
aoFuncDir = fullfile(exp_folder, 'Analog Output Functions');
[func_dur_s, nSampPos] = get_g4_func_dur(pos_func_id, 'pfn', funcFreq, posFuncDir);
ao_dur_s = get_g4_func_dur(ao_func_id, 'afn', [], aoFuncDir);   % [] -> use the AO's own stored rate (1 kHz)
assert(abs(func_dur_s - ao_dur_s) < 0.02, ...
    'Position (%.3f s) and AO (%.3f s) durations differ - rebuild as a matched pair.', ...
    func_dur_s, ao_dur_s);
dur_deci = round(func_dur_s * 10);

% Map the AO function ID to the right combinedCommand slot (ao0=ch2 ... ao3=ch5).
aoIDs = [0 0 0 0];
aoIDs(ao_channel - 1) = ao_func_id;

fprintf('Phase-3 functions (pos %d / ao %d): %d samples, %.4f s/rep at %g Hz, AO on ch %d.\n', ...
    pos_func_id, ao_func_id, nSampPos, func_dur_s, funcFreq, ao_channel);

% ============================ CONNECT ============================
ctlr = PanelsController();
ctlr.open(true);
ctlr.setRootDirectory(exp_folder);
ctlr.setActiveAOChannels(ao_channel);
ctlr.setActiveAIChannels([0 1]);        % log AI0 (bar/ADC0) and AI1 (marker, if wired)

if ~ctlr.startLog()
    warning('Log failed to start. Check G4 Host.'); ctlr.close(); return;
end
protocol_timer = tic;

% ======================= PHASE 1: closed loop =======================
fprintf('[%.1f s] Phase 1: Mode 7 closed loop (%d s)\n', toc(protocol_timer), cl_dur);
ctlr.sendSyncLog(MARK, 1);
run_closed_loop(ctlr, pattern_id, gain, offset, cl_dur);

% ============================ PHASE 2: dark ============================
fprintf('[%.1f s] Phase 2: dark (%d s)\n', toc(protocol_timer), dark_dur);
ctlr.sendSyncLog(MARK, 2);
show_dark(ctlr, pattern_id, dark_frame_index, dark_dur);

% ================== PHASE 3: position + AO, n_reps ==================
for r = 1:n_reps
    fprintf('[%.1f s] Phase 3: function rep %d/%d\n', toc(protocol_timer), r, n_reps);
    ctlr.sendSyncLog(MARK, 30 + r);
    ctlr.combinedCommand(1, pattern_id, pos_func_id, ...
        aoIDs(1), aoIDs(2), aoIDs(3), aoIDs(4), ...
        funcFreq, dur_deci, true);
end
ctlr.stopDisplay();

% ============================ PHASE 4: dark ============================
fprintf('[%.1f s] Phase 4: dark (%d s)\n', toc(protocol_timer), dark_dur);
ctlr.sendSyncLog(MARK, 4);
show_dark(ctlr, pattern_id, dark_frame_index, dark_dur);

% ======================= PHASE 5: closed loop =======================
fprintf('[%.1f s] Phase 5: Mode 7 closed loop (%d s)\n', toc(protocol_timer), cl_dur);
ctlr.sendSyncLog(MARK, 5);
run_closed_loop(ctlr, pattern_id, gain, offset, cl_dur);

% ==================== END: arena off (dark) ====================
ctlr.sendSyncLog(MARK, 0);
show_dark(ctlr, pattern_id, dark_frame_index, 0.3);   % leaves the held frame dark
ctlr.allOff();                                        % extra, harmless if unsupported
ctlr.stopLog('timeout', 60.0, 'showTimeoutDialog', true);
ctlr.close();
fprintf('[%.1f s] Protocol complete - arena dark.\n', toc(protocol_timer));

% ============================ HELPERS ============================
function run_closed_loop(ctlr, pattern_id, gain, offset, dur_s)
    % Mode 7: ADC0 (FicTrac heading) sets the bar x-index. Run until we stop it
    % (65535 = "don't self-complete") so MATLAB controls the phase duration.
    ctlr.stopDisplay();
    ctlr.setControlMode(7);
    ctlr.setPatternID(pattern_id);
    ctlr.setGain(gain, offset);
    ctlr.startDisplay(65535, false);
    pause(dur_s);
    ctlr.stopDisplay();
end

function show_dark(ctlr, pattern_id, dark_frame_index, dur_s)
    % Reliable dark: Mode 3 (Stream Pattern Position) holds the current pattern
    % at its dark frame. In Mode 3 the host STREAMS the x index to a RUNNING
    % display, so startDisplay must come FIRST and the index is (re)sent while it
    % runs. Setting the position before startDisplay (as before) was ignored,
    % which is why the arena stayed on the previous frame. When we stopDisplay,
    % the held frame is the dark one, so the arena stays dark.
    ctlr.stopDisplay();
    ctlr.setControlMode(3);
    ctlr.setPatternID(pattern_id);
    ctlr.startDisplay(65535, false);              % start the display FIRST
    t0 = tic;
    while toc(t0) < dur_s
        ctlr.setPositionX(dark_frame_index);      % stream the dark index while running
        pause(0.05);
    end
    ctlr.stopDisplay();                            % held frame = dark index
end
