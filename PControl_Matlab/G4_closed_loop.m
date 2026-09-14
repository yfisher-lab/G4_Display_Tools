% --- connect & configure (same as your script) ---
exp_folder = 'C:\Users\Fisher Lab\Documents\GitHub\G4_Display_Tools\PControl_Matlab\Experiment';
pattern_id = 16;
num_x_frames = 192; 
voltage_range = 10;
gain = round(num_x_frames / voltage_range); 
offset = 0;
ctlr = PanelsController();
ctlr.open(true);
ctlr.setRootDirectory(exp_folder);
ctlr.setPatternID(pattern_id);
ctlr.setControlMode(7);
% ADC sets x index
ctlr.setGain(gain, offset);

% --- run continuously, non-blocking ---
ctlr.startDisplay(6000, false); % 6000 deciSeconds = 600 s; false = DON'T wait% MATLAB returns immediately; the display keeps running and x tracks the ADC.