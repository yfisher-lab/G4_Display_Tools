%% G4 experimental protocol - mode-switching sequence
% Runs one full protocol, switching G4 control modes between phases:
%
%   Phase 1:  Mode 7 closed loop            cl_dur  s   (bar tracks ADC0 / FicTrac)
%   Phase 2:  Dark                          dark_dur s
%   Phase 3:  Position function + AO        n_reps  x   (Mode 1, custom .pfn + .afn)
%   Phase 4:  Dark                          dark_dur s
%   Phase 5:  Mode 7 closed loop            cl_dur  s
%
% The whole run is logged to one TDMS (startLog..stopLog) with sendSyncLog phase
% markers so you can segment it in analysis.
%
% BEFORE RUNNING: your FicTrac -> Phidget heading output must be RUNNING in the
% background, outputting LIVE heading to ADC0 (no strobe gating) - that drives
% the bar during the Mode 7 phases. The strobe/AO for phase 3 now lives in the
% G4 position/AO functions, not the Phidget.
%
% Build the phase-3 functions first (they must already exist by ID):
%   - position function (.pfn): your custom bar-motion function
%   - AO function (.afn): e.g. make_func_ao_pulses(ao_func_id, func_dur_s, ...)
% Both must be built at the SAME funcFreq used below and be func_dur_s long.

% ============================ PARAMETERS ============================
exp_folder  = 'C:\Users\Fisher Lab\Documents\GitHub\G4_Display_Tools\PControl_Matlab\Experiment';
pattern_id  = 16;        % 192-frame bar pattern (used by both closed loop and position function)

% -- Mode 7 closed-loop calibration (phases 1 & 5) --
num_x_frames  = 192;
voltage_range = 10;
gain          = round(num_x_frames / voltage_range);   % = 19
offset        = 0;

% -- Phase 3 function playback --
pos_func_id = 1;         % ID of your custom position function (.pfn)
ao_func_id  = 1;         % ID of your custom AO function (.afn)
ao_channel  = 2;         % function-capable AO channel (2-5); 2 = G4 "Channel 0"
funcFreq    = 389;       % PLAYBACK rate commanded to the controller (your achievable rate)
n_reps      = 5;

% Read the per-rep duration straight from the saved position function - no need
% to enter it by hand. Computed at the playback funcFreq (samples/funcFreq),
% which is what the run-time (deciSeconds) must cover. The AO function must be
% the same length (matched pair); checked here.
funcDir = fullfile(exp_folder, 'Functions');
[func_dur_s, nSampPos] = get_g4_func_dur(pos_func_id, 'pfn', funcFreq, funcDir);
[~,          nSampAO ] = get_g4_func_dur(ao_func_id,  'afn', funcFreq, funcDir);
assert(nSampPos == nSampAO, ...
    'Position (%d samp) and AO (%d samp) functions differ - rebuild them as a matched pair.', ...
    nSampPos, nSampAO);
fprintf('Phase-3 functions (pos %d / ao %d): %d samples, %.4f s per rep at %g Hz.\n', ...
    pos_func_id, ao_func_id, nSampPos, func_dur_s, funcFreq);

% -- Phase durations --
cl_dur   = 30;           % closed-loop seconds (phases 1 & 5)
dark_dur = 5;            % dark seconds (phases 2 & 4)

% Log marker class for phase boundaries (arbitrary; appears in the TDMS)
MARK = 99;

% ============================ CONNECT ============================
ctlr = PanelsController();
ctlr.open(true);
ctlr.setRootDirectory(exp_folder);
ctlr.setPatternID(pattern_id);
ctlr.setActiveAOChannels(ao_channel);   % activate the function-capable AO channel
ctlr.setActiveAIChannels([0 1]);        % log AI0 (bar/ADC0) and AI1 (marker, if wired)

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
go_dark(ctlr, dark_dur);

% ================== PHASE 3: position + AO, n_reps ==================
dur_deci = round(func_dur_s * 10);
for r = 1:n_reps
    fprintf('[%.1f s] Phase 3: function rep %d/%d\n', toc(protocol_timer), r, n_reps);
    ctlr.sendSyncLog(MARK, 30 + r);
    % Mode 1 = Fixed Rate Position Function. Plays the position function AND the
    % AO function together at funcFreq. waitForEnd=true blocks until this rep
    % completes, so reps run back-to-back with exact controller-clocked timing.
    ctlr.combinedCommand(1, pattern_id, pos_func_id, ...
        ao_func_id, 0, 0, 0, ...     % ao0=ch2, ao1=ch3, ao2=ch4, ao3=ch5
        funcFreq, dur_deci, true);
end

% ============================ PHASE 4: dark ============================
fprintf('[%.1f s] Phase 4: dark (%d s)\n', toc(protocol_timer), dark_dur);
ctlr.sendSyncLog(MARK, 4);
go_dark(ctlr, dark_dur);

% ======================= PHASE 5: closed loop =======================
fprintf('[%.1f s] Phase 5: Mode 7 closed loop (%d s)\n', toc(protocol_timer), cl_dur);
ctlr.sendSyncLog(MARK, 5);
run_closed_loop(ctlr, gain, offset, cl_dur);

% ============================ STOP ============================
ctlr.sendSyncLog(MARK, 0);
ctlr.stopDisplay();
ctlr.allOff();
ctlr.stopLog('timeout', 60.0, 'showTimeoutDialog', true);
ctlr.close();
fprintf('[%.1f s] Protocol complete.\n', toc(protocol_timer));

% ============================ HELPERS ============================
function run_closed_loop(ctlr, gain, offset, dur_s)
    % Mode 7: ADC0 (FicTrac heading) sets the bar x-index. Continuous display.
    ctlr.setControlMode(7);
    ctlr.setGain(gain, offset);
    ctlr.startDisplay(round(dur_s * 10), false);   % non-blocking
    pause(dur_s);
    ctlr.stopDisplay();
end

function go_dark(ctlr, dur_s)
    % All LEDs off. stopDisplay first so nothing is refreshing, then allOff so
    % the blank holds for the whole dark period.
    ctlr.stopDisplay();
    ctlr.allOff();
    pause(dur_s);
end
