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

% -- Run metadata (goes into the saved file names) --
fly_num   = 1;           % fly number for this run
trial_num = [];          % [] = AUTO: scan the save folders for the highest existing
                         % <date>_fly<n>_trial<m> and use m+1. Set a number to override.

% -- External programs launched at startup (background), closed at the end --
fictrac_lnk   = 'C:\Users\Public\Desktop\FicTrac.lnk';                    % FicTrac shortcut
fictrac_exe   = 'FicTrac.exe';   % process name to close at the end (check Task Manager
                                 % > Details if the FicTrac process is named differently)
phidget_py    = 'C:\Users\Fisher Lab\Desktop\fictrac_phidget_output.py';  % Phidget AO driver
python_cmd    = 'python';        % interpreter for phidget_py - MUST be 'python' (not python 3.13)
phidget_title = 'G4_PhidgetDriver';  % console-window title given to the python driver so we
                                     % can close THAT window only (not other python processes)
launch_delay  = 2;               % s to wait after launching for them to initialize

% -- Start trigger pulse (tells the other equipment to start) --
trig_channel = 6;           % AO6 (static-only output; the only AO setAO can drive is 6/7)
trig_volt    = 5;           % V
trig_dur     = 0.05;        % s (50 ms)

% -- Post-run log saving (and the naming convention) --
fictrac_dat_dir = 'C:\Users\Fisher Lab\Documents\FicTrac 2.1.1';  % FicTrac writes its .dat here
fictrac_dest    = 'D:\Lily\FicTrac';                   % copy this run's .dat here
g4_log_parent   = fullfile(exp_folder, 'Log Files');   % where the G4 Host writes its log folder
g4_log_dest     = 'D:\Lily\G4 logs';                   % move this run's G4 log folder here
save_subfolder  = 'debugging';          % optional subfolder created inside BOTH dests to group runs
                               % (e.g. 'fly1' or '2026-10-02'); '' = save directly in the dest.
                               % created automatically if it does not exist.
% Base name: <date>_fly<n>_trial<m>  e.g. 2026-10-02_fly1_trial1. If trial_num is [],
% auto-pick the next trial: scan both save folders (within save_subfolder) for existing
% entries matching this date+fly and use the highest trial number + 1.
date_str = datestr(now, 'yyyy-mm-dd');
if isempty(trial_num)
    trial_num = next_trial_num({fullfile(fictrac_dest, save_subfolder), ...
                                fullfile(g4_log_dest,  save_subfolder)}, date_str, fly_num);
end
save_basename = sprintf('%s_fly%d_trial%d', date_str, fly_num, trial_num);
fprintf('Run name: %s\n', save_basename);

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
funcFreq    = 395;       % .pfn build rate (make_func_opto_write_in). Only used here for
                         % the AO length sanity check; the run duration is HARD-CODED
                         % below (rep_dur_s), not derived from this.
n_reps      = 5;

% -- HARD-CODED per-rep cycle duration (s) for the strobe conditions you test --------
% The free-run display runs n_reps * rep_dur_s, so pick the value for the strobe you
% are running and it plays EXACTLY n_reps cycles (no partial extra rep / extra strobe).
% These are the real rep periods at the current ~392.8 Hz play rate (onDur 2.4 s,
% 8 marks, leadBlank 0.2 s, offDur 0):
%     strobe 0.40 / 0.80  ->  rep_dur_s = 19.51
%     strobe 0.15 / 0.30  ->  rep_dur_s = 18.22
%     strobe 0.03 / 0.06  ->  rep_dur_s = 19.99   (measured from the 10-02 log)
% They are tied to the play rate (which drifts ~2% run-to-run). If a run shows a restart
% (extra strobe at the start), lower rep_dur_s a touch; if the LAST strobe is clipped,
% raise it. Re-measure the rep period from any Frame log (location-0 onset to the next
% location-0 onset) to recalibrate.
rep_dur_s   = 19.4;     % <- set to the strobe condition being run

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

% ==================== LAUNCH EXTERNAL EQUIPMENT ====================
% Mark the run start so the post-run save can pick THIS run's files (those created
% after now), not stale ones. Launch FicTrac + the Phidget driver in the background
% (the `start` command returns immediately) so they are up for the closed-loop phases.
run_start_dnum = now;
fprintf('Launching FicTrac and the Phidget driver...\n');
system(sprintf('start "" "%s"', fictrac_lnk));                     % FicTrac (.lnk shortcut)
% Launch the python driver in a console window TITLED phidget_title, so it can be closed
% by that exact title later (image-name kill would hit unrelated python processes).
system(sprintf('start "%s" %s "%s"', phidget_title, python_cmd, phidget_py));
pause(launch_delay);                                               % let them initialize

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

% ===================== START TRIGGER (before Phase 1) =====================
% Brief AO6 pulse to tell the other equipment to start. Logged (after startLog) so the
% trigger time is in the TDMS record. setAO drives AO6/AO7 only, in volts.
fprintf('[%.1f s] Start trigger: %g V, %g ms on AO%d\n', toc(protocol_timer), trig_volt, trig_dur*1000, trig_channel);
ctlr.sendSyncLog(MARK, 10);
ctlr.setAO(trig_channel, trig_volt);
pause(trig_dur);
ctlr.setAO(trig_channel, 0);

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
% the .pfn loops at). The AO .afn is ALSO one cycle and loops in sync (see generator).
[func_dur_s, nSampPos] = get_g4_func_dur(pos_func_id, 'pfn', funcFreq, posFuncDir);
ao_dur_s = get_g4_func_dur(ao_func_id, 'afn', [], aoFuncDir);   % [] -> the AO's own stored rate

% FREE-RUN: instead of one startDisplay per rep, run ONE continuous display and let
% BOTH functions LOOP internally. The position .pfn (nSampPos) and the AO .afn
% (2*nSampPos at 2x the rate) have the same real cycle duration, so they loop locked
% together for the whole run (ratio 2, measured). Internal loops are seamless (no
% startup hold), so only the FIRST bar/pulse of the whole run sees the startDisplay
% hold; discard that one pulse in analysis.
%
% Run duration is HARD-CODED from the measured rep period (rep_dur_s), NOT computed
% from func_dur_s - the build-rate estimate overshoots the true cycle and ran a partial
% 6th rep. n_reps * rep_dur_s lands exactly on the n_reps-cycle boundary.
run_dur_s  = n_reps * rep_dur_s;
total_deci = round(run_dur_s * 10);

% Sanity: the AO cycle should be ~one position cycle (it loops WITH the .pfn). A much
% longer AO means an old generator built a multi-cycle AO that the G4 truncates at its
% ~65536-sample limit and loops mid-run (that caused the extra pulse / drift).
assert(ao_dur_s <= func_dur_s*1.5 + 0.05, ...
    ['AO function is %.2f s but one position cycle is %.2f s. The AO should be a SINGLE ' ...
     'cycle that loops - regenerate with the current generator (one-cycle AO).'], ...
    ao_dur_s, func_dur_s);

fprintf(['Phase 3 (free-run): hard-coded %.2f s/rep x %d reps = %.1f s continuous.\n' ...
         '  Discard the first pulse of the run (startDisplay startup hold). If you see a\n' ...
         '  restart or a clipped last strobe, nudge rep_dur_s and re-check the Frame log.\n'], ...
    rep_dur_s, n_reps, run_dur_s);

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

% ==================== CLOSE EXTERNAL EQUIPMENT ====================
% Close the Phidget console (matched by its unique window title) and FicTrac (by image
% name). Done BEFORE saving so FicTrac releases its .dat file. /T also ends child
% processes; /F forces. Errors are ignored (nothing to close is fine).
fprintf('Closing FicTrac and the Phidget driver...\n');
% Close the python driver by matching its COMMAND LINE (the script path). taskkill by
% window title does not reliably close console windows, which is why the window stayed
% open. This finds the python.exe running phidget_py and stops it.
[~, scriptkey] = fileparts(phidget_py);   % e.g. 'fictrac_phidget_output'
[~,~] = system(sprintf(['powershell -NoProfile -Command "Get-CimInstance Win32_Process | ' ...
    'Where-Object { $_.Name -eq ''python.exe'' -and $_.CommandLine -like ''*%s*'' } | ' ...
    'ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"'], scriptkey));
[~,~] = system(sprintf('taskkill /IM "%s" /F', fictrac_exe));   % FicTrac GUI, by image name
pause(1);   % let file handles release before copying the .dat

% ==================== SAVE LOGS (renamed, relocated) ====================
% Pick the files created during THIS run (modified after run_start_dnum) and save them
% under save_basename. Each is wrapped so a failure only warns - the raw logs are still
% in their original folders. FicTrac is already closed above, so its .dat is released.
pause(1);   % let the G4 Host finish flushing the TDMS files

% FicTrac .dat -> copy to fictrac_dest\<basename>.dat  (copy, not move: FicTrac may still
% hold the file open).
try
    ft_outdir = fullfile(fictrac_dest, save_subfolder);
    if ~exist(ft_outdir, 'dir'); mkdir(ft_outdir); end
    dats = dir(fullfile(fictrac_dat_dir, '*.dat'));
    dats = dats([dats.datenum] >= run_start_dnum - 1/1440);   % created this run (1 min slack)
    assert(~isempty(dats), 'no new .dat in %s since the run started', fictrac_dat_dir);
    [~, ix] = max([dats.datenum]);
    dst = fullfile(ft_outdir, [save_basename '.dat']);
    copyfile(fullfile(dats(ix).folder, dats(ix).name), dst);
    fprintf('Saved FicTrac .dat -> %s\n', dst);
catch ME
    warning('FicTrac .dat not saved (%s). Copy it manually from %s.', ME.message, fictrac_dat_dir);
end

% G4 log folder -> move to g4_log_dest\<basename>  (the whole timestamped TDMS folder).
try
    g4_outdir = fullfile(g4_log_dest, save_subfolder);
    if ~exist(g4_outdir, 'dir'); mkdir(g4_outdir); end
    d = dir(g4_log_parent);
    d = d([d.isdir] & ~ismember({d.name}, {'.','..'}));
    d = d([d.datenum] >= run_start_dnum - 1/1440);
    assert(~isempty(d), 'no new G4 log folder in %s since the run started', g4_log_parent);
    [~, ix] = max([d.datenum]);
    dst = fullfile(g4_outdir, save_basename);
    movefile(fullfile(d(ix).folder, d(ix).name), dst);
    fprintf('Saved G4 log -> %s\n', dst);
catch ME
    warning('G4 log not saved (%s). Move it manually from %s.', ME.message, g4_log_parent);
end

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

function tn = next_trial_num(searchDirs, dateStr, flyNum)
    % Highest existing trial number for this date+fly across searchDirs, + 1 (1 if none).
    % Matches names like '<dateStr>_fly<flyNum>_trial<m>' - both the .dat files and the
    % G4 log folders, since they share the base name.
    prefix = sprintf('%s_fly%d_trial', dateStr, flyNum);
    maxt = 0;
    for i = 1:numel(searchDirs)
        D = searchDirs{i};
        if isempty(D) || ~exist(D, 'dir'); continue; end
        items = dir(fullfile(D, [prefix '*']));
        for k = 1:numel(items)
            tok = regexp(items(k).name, [regexptranslate('escape', prefix) '(\d+)'], 'tokens', 'once');
            if ~isempty(tok); maxt = max(maxt, str2double(tok{1})); end
        end
    end
    tn = maxt + 1;
end
