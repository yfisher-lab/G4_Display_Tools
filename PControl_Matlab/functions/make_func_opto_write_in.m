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

%% load settings
userSettings
funcFreq = 398;
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

% set function
func = breakFunc;
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

