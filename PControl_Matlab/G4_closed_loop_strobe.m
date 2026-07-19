%% G4 Mode 7 + Square Wave Y - Standalone Script
% External voltage on ADC0 drives x frame index (Mode 7).
% MATLAB loop drives y as a repeating square wave simultaneously.
%
% USAGE: Edit the parameters section, then run from the MATLAB editor
% or command window. G4 Host must be running before you start.

% =========================================================
% PARAMETERS - edit these to suit your experiment
% =========================================================

% Experiment folder
exp_folder   = 'C:\Users\Fisher Lab\Documents\GitHub\G4_Display_Tools\PControl_Matlab\Experiment';
pattern_id   = 13;

% Trial structure
trial_dur    = 360;       % seconds

% Mode 7 gain calibration: frame_index = gain * (voltage + offset)
% Example: 0-10V input, 96 x-frames → gain = 9.6
num_x_frames  = 192;
voltage_range = 10;      % max voltage from your external hardware (V)
gain          = round(num_x_frames / voltage_range);
offset        = 0;

% Y square wave
num_y_frames  = 2;       % number of y frames in your pattern
y_high_frame  = num_y_frames;
y_low_frame   = 1;
y_on_dur      = 0.5;     % seconds y stays at y_high_frame per cycle
y_off_dur     = 1;     % seconds y stays at y_low_frame per cycle
y_update_ms   = 2;       % loop update interval — don't go below ~1ms

% Analog output for start/stop display
ao_channel   = 6;        % AO channel to use (0-3)
ao_high_val  = 1; %32767;    % ~10V — sent when display is ON
ao_low_val   = 0;        % 0V   — sent when display is OFF

% =========================================================
% CONNECT
% =========================================================
ctlr = PanelsController();
ctlr.open(true);

ctlr.setRootDirectory(exp_folder);
ctlr.setPatternID(pattern_id);
ctlr.setControlMode(7);
ctlr.setGain(gain, offset);

ctlr.setActiveAOChannels(2);   % activate AO channel 0
                                % use 2 for ch1, 3 for ch0+ch1, etc.
ctlr.setAO(ao_channel, ao_low_val);  % ensure AO starts low

% =========================================================
% PRE-COMPUTE Y TRAJECTORY
% =========================================================
t_vec      = 0 : (y_update_ms/1000) : (trial_dur - y_update_ms/1000);
n_steps    = length(t_vec);
period     = y_on_dur + y_off_dur;
y_phase    = mod(t_vec, period);
y_indices  = ones(1, n_steps) * y_low_frame;
y_indices(y_phase < y_on_dur) = y_high_frame;

actual_times = zeros(1, n_steps);  % for jitter logging

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

t_trial  = tic;
prev_state = 0;  % 1 = on, 0 = off

for i = 1:n_steps

    % Determine desired state from square wave
    desired_state = double(y_indices(i) == y_high_frame);  % 1=on, 0=off

    % Only send command on transitions
    if desired_state ~= prev_state
        if desired_state == 0
            ctlr.stopDisplay();
            ctlr.setAO(ao_channel, ao_low_val);  % pulse AO low on OFF
        else
            ctlr.startDisplay(trial_dur * 10, false);
            ctlr.setAO(ao_channel, ao_high_val);   % pull AO high on ON
        end
        prev_state = desired_state;
    end

    actual_times(i) = toc(t_trial);

    next_t    = i * (y_update_ms / 1000);
    sleep_dur = next_t - toc(t_trial) - 0.0005;
    if sleep_dur > 0; pause(sleep_dur); end
    while toc(t_trial) < next_t; end

end

% ctlr.startDisplay(trial_dur * 10, false);  % false = non-blocking
%
% t_trial = tic;
% prev_y  = -1;
%
% for i = 1:n_steps
%
%     % Only send on transitions to minimise TCP load
%     if y_indices(i) ~= prev_y
%         ctlr.setPositionY(y_indices(i));
%         prev_y = y_indices(i);
%     end
%
%     actual_times(i) = toc(t_trial);
%
%     % Hybrid sleep: pause most of interval, spin-wait the last 0.5ms
%     next_t    = i * (y_update_ms / 1000);
%     sleep_dur = next_t - toc(t_trial) - 0.0005;
%     if sleep_dur > 0
%         pause(sleep_dur);
%     end
%     while toc(t_trial) < next_t; end  % spin-wait
%
% end

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
