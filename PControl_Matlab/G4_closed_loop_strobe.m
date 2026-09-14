%% G4 Mode 1 + opto write in trigger
% MATLAB input drives x frame index (Mode 3).
% Analog output 5V signal to trigger mark points in Bruker software.
%
% USAGE: Edit the parameters section, then run from the MATLAB editor
% or command window. G4 Host must be running before you start.

% =========================================================
% PARAMETERS - edit these to suit your experiment
% =========================================================

% Experiment folder
exp_folder   = 'C:\Users\Fisher Lab\Documents\GitHub\G4_Display_Tools\PControl_Matlab\Experiment';
pattern_id   = 12;

% Trial structure
trial_dur    = 360;       % seconds

% Mode 3 x frame indices
total_frames = 192;
num_points = 8;
frame_increments = total_frames / num_points;
x_indices = 0:frame_increments:total_frames;

% Analog output for start/stop display
ao_channel   = 6;        % AO channel to use (0-3)
ao_high_val  = 5;        % 5V   - send when display is ON
ao_low_val   = 0;        % 0V   — sent at all other times

% =========================================================
% CONNECT
% =========================================================
ctlr = PanelsController();
ctlr.open(true);

ctlr.setRootDirectory(exp_folder);
ctlr.setPatternID(pattern_id);
ctlr.setControlMode(3);

ctlr.setActiveAOChannels(2);   % activate AO channel 0
                                % use 2 for ch1, 3 for ch0+ch1, etc.
ctlr.setAO(ao_channel, ao_low_val);  % ensure AO starts low

% =========================================================
% START LOG
% =========================================================
log_started = ctlr.startLog();
if ~log_started
    warning('Log failed to start. Check G4 Host.');
    ctlr.close();
    return;
end

% =========================================================
% RUN - non-blocking startDisplay + y loop
% =========================================================
fprintf('Starting trial (%.1f s)...\n', trial_dur);
ctlr.startDisplay(trial_dur * 10, false);


% =========================================================
% STOP AND CLOSE
% =========================================================
ctlr.setAO(ao_channel, ao_low_val);  % ensure AO returns to 0V at end
ctlr.stopDisplay();
ctlr.stopLog('timeout', 60.0, 'showTimeoutDialog', true);
ctlr.close();

% =========================================================
% TIMING REPORT
% =========================================================
jitter_ms = (actual_times - t_vec) * 1000;
fprintf('Done.\n');
fprintf('  Mean jitter : %.2f ms\n', mean(abs(jitter_ms)));
fprintf('  Max jitter  : %.2f ms\n', max(abs(jitter_ms)));
fprintf('  Std jitter  : %.2f ms\n', std(jitter_ms));
