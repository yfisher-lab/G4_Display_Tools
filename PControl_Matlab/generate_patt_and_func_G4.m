% generate_patt_and_func_G4
% generate a series of patterns and functions for the G4 display

% load settings
userSettings


%% Generate patterns
disp('generating g4 patterns...')

% clear patterns folder contents
delete([exp_path '\Patterns\*'])
delete([pattern_path '\patt_lookup*'])
p = 1; %initialize counter


% courtship experiments
% set variables
barWidth = 6; %px
boxWidth = 16; %px

bckGS = 6;
grtGS = 0;

%blank background
make_patt_blank_G4(p, bckGS)
p = p+1;

%dark bar
make_patt_verticalbar_G4(p, barWidth, 'dark', bckGS)
p = p+1;
%bright bar
make_patt_verticalbar_G4(p, barWidth, 'bright', bckGS)
p = p+1;
%dark box only 
make_patt_box_opt_background_G4(p, boxWidth, 4, 0, 'dark', grtGS, bckGS)
p = p+1;

%vertical grating
grtWidth = 8; %px
make_patt_verticalgrating_G4(p, grtWidth, grtGS, bckGS)
p=p+1;
%vertical grating
grtWidth = 12; %px
make_patt_verticalgrating_G4(p, grtWidth, grtGS, bckGS)
p=p+1;

%horizontal grating
grtWidth = 16; %px
make_patt_horizontalgrating_G4(p, grtWidth, grtGS, bckGS)
p=p+1;



%% Generate functions
disp('generating g4 functions...')

% clear functions folder contents
delete([exp_path '\Functions\*'])
delete([function_path '\func_lookup*'])

% set variables
f = 1; %initialize counter
sweepLength = [75 120 180 300];
sweepVelocity = [25 50 75];
objs = [6 16];

% hold center
for o = 1:length(objs)
    make_func_hold_center_G4(f,objs(o))
    f = f+1;
end

% alternating sweep
for s = 1:length(sweepLength)
    for v = 1:length(sweepVelocity)
        for o = 1:length(objs)
            make_func_alternating_sweep_G4(f,sweepLength(s),sweepVelocity(v),objs(o))
            f = f+1;
        end
    end
end

% optomotor reflex
for v = 1:length(sweepVelocity)
    make_func_optomotor_sweep_G4(f, sweepVelocity(v))
    f = f+1;
end

% set variables
sweepLength = 75;
sweepVelocity = [50 75];
objs = [6 16];

% alternating sweep
for s = 1:length(sweepLength)
    for v = 1:length(sweepVelocity)
        for o = 1:length(objs)
            make_func_pause_alternating_sweep_G4(f,sweepLength(s),sweepVelocity(v),objs(o))
            f = f+1;
        end
    end
end

% % % coherent path
% sweepRange = 110; %deg
% funcDur = 120; %sec
% objSize = 6; %px
% for cp = 1:10
%     make_func_coherentpath_G4(f, sweepRange, funcDur, objSize)
%     f = f+1;
% end

%% TLN pattern and functions
make_patt_verticalbar_G4(8, 4, 'b', 1); % 4 pix bright bar
make_patt_verticalbar_G4(9, 19, 'b', 1); % 19 pix bright bar
make_patt_verticalbar_G4(10, 19, 'd', 1); % 19 pix dark bar
make_patt_verticalbar_reverse_G4(11, 19, 'b', 1); % 19 pix bright bar ccw
make_patt_verticalbar_dac_G4(12, 4, 'b', 1); % 4 pix bar where 0 = middle of blank panel
make_patt_verticalbar_dac_G4(13, 19, 'b', 1); % 19 pix bar where 0 = middle of blank panel
make_patt_verticalbar_dac_G4(14, 19, 'b', 3); % 19 pix bar where 0 = middle of blank panel
make_patt_verticalbar_dac_G4(15, 19, 'b', 5); % 19 pix bar where 0 = middle of blank panel

% vertical bars with one static bar
staticBarLocs = [71, 168];
barSizes = [4, 19];
f = 16;
for l = 1:length(staticBarLocs)
    for b = 1:length(barSizes)
        make_patt_static_verticalbar_G4(f, barSizes(b), staticBarLocs(l), 'b', 1)
        f = f + 1;
    end
end

% % squares at different elevations
% heights = 32:4:60;
% f = 16;
% for h = 1:length(heights)
%     make_patt_box_G4(f, 4, 'b', heights(h), 1); % 4x4 pix square
%     f = f + 1;
% end

make_func_alternating_sweep_G4(34, 360, 22, 96) % 22 deg/sec 4 pix
make_func_alternating_sweep_G4(35, 356, 22, 116) % 22 deg/sec 19 pix
make_func_alternating_sweep_G4(36, 356, 72, 116) % 72 deg/sec 
make_func_alternating_sweep_G4(37, 360, 72, 250)
make_func_alternating_sweep_ctr_G4(38, 360, 72, -20) % 72 deg/sec 19 pix ccw
make_func_alternating_sweep_ctr_G4(39, 180, 72, -20) % 72 deg/sec 180 sweep 19 pix ccw
make_func_alternating_sweep_G4(40, 356, 40, 116) % 40 deg/sec 19 pix
make_func_alternating_sweep_ctr_G4(41, 360, 40, -20) % 40 deg/sec 19 pix ccw
make_func_alternating_sweep_ctr_G4(42, 360, 40, 19) % 40 deg/sec 19 pix cw centered at back panel
make_func_pause_alternating_sweep_G4_TLN(43, 360, 40, 15, 19) % alternate cw and ccw rotations with 19 sec pause in between
make_func_pause_alternating_sweep_G4_TLN(44, 360, 20, 15, 19) % alternate cw and ccw rotations with 19 sec pause in between
make_func_pause_alternating_sweep_G4_TLN(45, 360, 80, 15, 19) % alternate cw and ccw rotations with 19 sec pause in between
make_func_pause_alternating_sweep_G4_TLN(46, 360, 100, 5, 19) % alternate cw and ccw rotations with 19 sec pause in between
make_func_pause_alternating_sweep_G4_TLN(47, 360, 40, 15, 4) % alternate cw and ccw rotations
make_func_pause_alternating_sweep_G4_TLN(48, 360, 20, 15, 4) % alternate cw and ccw rotations
make_func_pause_alternating_sweep_G4_TLN(49, 360, 100, 15, 4) % alternate cw and ccw rotations
make_func_pause_alternating_sweep_G4_TLN(56, 360, 180, 15, 19) % alternate cw and ccw rotations with 19 sec pause in between
make_func_pause_alternating_sweep_G4_TLN(57, 360, 180, 15, 4) % alternate cw and ccw rotations with 19 sec pause in between
make_func_pause_alternating_sweep_G4_TLN(59, 360, 200, 5, 19) % alternate cw and ccw rotations with 19 sec pause in between
make_func_pause_alternating_sweep_G4_TLN(60, 360, 300, 5, 19) % alternate cw and ccw rotations with 19 sec pause in between
make_func_pause_alternating_sweep_G4_TLN(61, 360, 400, 5, 19) % alternate cw and ccw rotations with 19 sec pause in between
make_func_pause_alternating_sweep_G4_TLN(62, 360, 500, 5, 19) % alternate cw and ccw rotations with 19 sec pause in between
make_func_pause_alternating_sweep_G4_TLN(63, 360, 600, 5, 19) % alternate cw and ccw rotations with 19 sec pause in between
make_func_pause_alternating_sweep_G4_TLN(64, 360, 700, 5, 19) % alternate cw and ccw rotations with 19 sec pause in between
make_func_pause_alternating_sweep_G4_TLN(65, 360, 800, 5, 19) % alternate cw and ccw rotations with 19 sec pause in between
make_func_pause_alternating_sweep_G4_TLN(66, 360, 900, 5, 19) % alternate cw and ccw rotations with 19 sec pause in between

barLocs = [19:8:77 116];
make_func_bar_flashing(50, barLocs, 0.01, 2) % randomly flash bar in different locations
make_func_bar_flashing(51, barLocs, 0.05, 2) % randomly flash bar in different locations
make_func_bar_flashing(52, barLocs, 0.1, 2) % randomly flash bar in different locations
make_func_bar_flashing(53, barLocs, 0.2, 2) % randomly flash bar in different locations
make_func_bar_flashing(54, barLocs, 0.5, 2) % randomly flash bar in different locations
make_func_bar_flashing(55, barLocs, 1, 2) % randomly flash bar in different locations
make_func_bar_flashing(58, barLocs, 2, 3) % randomly flash bar in different locations

%% store current experiment data
create_currentExp(exp_path)

%% end
disp('complete!')
close all
clear


