% make_func_opto_write_in
% function generator - makes a function for holding at the center position

% INPUTS
% funcN - specify function # to save as

% 09/21/2026 - TLN created

function make_func_opto_write_in(funcN,barStartLoc,onDur,offDur,numMarkPoints,varargin)

% optional inputs
strobeBar = varargin{1};
strobeOnDur = varargin{2}; %sec
strobeOffDur = varargin{3}; %sec
% Leading dark blank (sec) at the very start of the function. The display engine
% latches sample 0 and holds it for a jittery 0-150 ms at startDisplay; if sample 0
% is a bar it is shown during that hold while the AO's first pulse (held at baseline)
% is not, so the first pulse lands up to ~150 ms after the already-visible bar.
% Starting dark means the bar isn't shown until the engine is advancing, so the first
% bar and first AO pulse are delayed together and stay aligned - no pulse to discard.
% In the free-run protocol this cycle loops, so the blank recurs each loop (extra dark
% before every rep); it only NEEDS to cover the one startup hold. Keep equal to
% leadBlankDur in generate_opto_writein_and_ao_G4.m (the AO timeline adds it too).
if numel(varargin) >= 4 && ~isempty(varargin{4})
    leadBlankDur = varargin{4}; %sec
else
    leadBlankDur = 0.20;        %sec, default (> observed ~150 ms startup hold)
end

%% load settings
writeInUserSettings
funcFreq = 395;   % build at the TRUE measured hardware play rate (Frame_Position
                  % log: 954-sample bars play in 2.4169 s -> 395 Hz), so the .pfn's
                  % sample counts and the real-time playback agree. If you change
                  % this, change funcFreq_pos in generate_opto_writein_and_ao_G4.m to
                  % match, OR re-split it back into build/play rates there.
totalFrames = 192;

%% generate function data
% get evenly spaced pattern indices based on start location and number of
% mark points
frameIncrements = round(totalFrames / numMarkPoints);
frameIndices = barStartLoc:frameIncrements:(barStartLoc+(frameIncrements*numMarkPoints-1));

% unwrap frame indices
if any(frameIndices > totalFrames)
    indicesToUnwrap = frameIndices(frameIndices>totalFrames);
    unwrappedIndices = indicesToUnwrap - totalFrames;
    frameIndices(frameIndices>totalFrames) = unwrappedIndices;
end
   
barLocs = frameIndices;

% set locations
if strobeBar == 0
    locFuncs = zeros(length(barLocs), round(onDur*funcFreq));
    for loc = 1:length(barLocs)
        locFuncs(loc, :) = ones(1, round(onDur*funcFreq)) * barLocs(loc);
    end
elseif strobeBar == 1
    strobeCycle = strobeOnDur + strobeOffDur; %sec
    numStrobeCycles = round(onDur / strobeCycle);

    locFuncs = [];
    for loc = 1:length(barLocs)
        strobeOn = ones(1, round(strobeOnDur*funcFreq)) * barLocs(loc);
        strobeOff = ones(1, round(strobeOffDur*funcFreq)) * 184;
        strobeFunc = repmat([strobeOn strobeOff], 1, numStrobeCycles);
        locFuncs(loc, :) = strobeFunc;
    end

end

breakFunc = ones(1, round(offDur*funcFreq)) * 184; % location where 19 pix bar is centered behind the fly
leadBlank = ones(1, round(leadBlankDur*funcFreq)) * 184; % dark hold absorbing the startDisplay startup latency

% set function - START with the leading dark blank so the first bar is not shown
% during the startup hold (keeps the first AO pulse aligned with the first bar).
func = [leadBlank breakFunc];
for loc = 1:length(barLocs)
    func = [func locFuncs(loc,:) breakFunc];
end

%% set function data
pfnparam.func = func;
pfnparam.size = length(func);
pfnparam.dur = length(func)/funcFreq;

%set lookup table
if strobeBar == 0
    funlookup.name = ['write_in_' num2str(numMarkPoints) '_bars_start_pos_' num2str(barStartLoc) '_on_' num2str(onDur) '_sec'];
elseif strobeBar == 1
    funlookup.name = ['write_in_' num2str(numMarkPoints) '_bars_start_pos_' num2str(barStartLoc) '_on_' num2str(onDur) '_sec_' num2str(strobeOnDur) '-' num2str(strobeOffDur) '_strobe'];
end

funlookup.sweepRange = 0;
funlookup.sweepRangePx = 0;
funlookup.sweepRate = 0;
funlookup.frequency = funcFreq;

%% save function data

%set and save function data
funcName = [sprintf('%04d', funcN) '_' funlookup.name];
matFileName = fullfile([exp_path, '\Functions'], [funcName, '.mat']);
save(matFileName, 'pfnparam');

%save function lookup table
funcLookUp = ['func_lookup_' sprintf('%04d', funcN)];
matFileName = fullfile(function_path, [funcLookUp, '.mat']);
save(matFileName, 'funlookup');


%save header in the first block
block_size = 512; % all data must be in units of block size
Header_block = zeros(1, block_size);
Header_block(1:4) = dec2char(length(func)*2, 4);     %each function datum is stored in two bytes in the currentFunc card
Header_block(5) = length(funcName);
Header_block(6: 6 + length(funcName) -1) = funcName;
%concatenate the header data with function data
functionData = signed_16Bit_to_char(func);     
Data_to_write = [Header_block functionData];

%write to the fun image file
fid = fopen(fullfile([exp_path '\Functions'], ['func', sprintf('%04d', funcN), '.pfn']), 'w');
fwrite(fid, Data_to_write(:),'uchar');
fclose(fid);



end

