function [dur, nSamples, funcFreqUsed] = get_g4_func_dur(funcID, funcType, funcFreq, funcDir)
%GET_G4_FUNC_DUR  Duration (s) of a saved G4 position (.pfn) or AO (.afn) function.
%
% Reads the sample count from the function's .mat (written by
% make_func_opto_write_in / make_func_ao_pulses via save_function_G4) and returns
% the duration. Compute it at whatever rate you will PLAY the function, since the
% run-time (deciSeconds in combinedCommand) must cover nSamples/playRate.
%
% USAGE
%   dur = get_g4_func_dur(3)                       % position fn, build rate, default folder
%   dur = get_g4_func_dur(3,'afn')                 % AO function
%   [dur,N] = get_g4_func_dur(3,'pfn',389)         % duration if PLAYED at 389 Hz
%   dur = get_g4_func_dur(3,'afn',389,myFolder)    % explicit Functions folder
%
% INPUTS
%   funcID    integer function ID
%   funcType  'pfn' (position, default) or 'afn' (analog output)
%   funcFreq  playback rate (Hz) -> dur = nSamples/funcFreq. [] or omitted uses
%             the rate the function was built at (read from the .mat).
%   funcDir   folder with the function .mat files. default [exp_path filesep 'Functions']
%
% OUTPUTS
%   dur           duration in seconds ( nSamples / funcFreqUsed )
%   nSamples      number of function samples
%   funcFreqUsed  the rate used to compute dur

    if nargin < 2 || isempty(funcType); funcType = 'pfn'; end
    if nargin < 3; funcFreq = []; end
    if nargin < 4 || isempty(funcDir)
        userSettings;                                   % defines exp_path
        funcDir = fullfile(exp_path, 'Functions');
    end

    % Find the .mat for this ID. AO (.afn) files are saved as *_G4.mat by
    % save_function_G4; position (.pfn) .mats from make_func_opto_write_in are not.
    files = dir(fullfile(funcDir, sprintf('%04d_*.mat', funcID)));
    assert(~isempty(files), 'No function .mat for ID %d in %s', funcID, funcDir);
    isG4 = endsWith({files.name}, '_G4.mat');
    if strcmpi(funcType, 'afn'); files = files(isG4); else; files = files(~isG4); end
    assert(~isempty(files), 'No %s .mat for ID %d in %s', funcType, funcID, funcDir);
    if numel(files) > 1
        [~, newest] = max([files.datenum]);
        warning('Multiple %s .mats for ID %d; using newest (%s).', funcType, funcID, files(newest).name);
        files = files(newest);
    end

    S = load(fullfile(files(1).folder, files(1).name));
    if     isfield(S, 'pfnparam'); p = S.pfnparam;
    elseif isfield(S, 'afnparam'); p = S.afnparam;
    else;  error('No pfnparam/afnparam in %s', files(1).name); end

    % Sample count: numel(func) is correct for BOTH types. (Note: afnparam.size
    % is a BYTE count = 2*nSamples, so don't use it for AO functions.)
    if     isfield(p, 'func'); nSamples = numel(p.func);
    elseif isfield(p, 'size'); nSamples = p.size;          % pfn only
    else;  error('Cannot determine sample count from %s', files(1).name); end

    if isempty(funcFreq)
        if     isfield(p, 'funcFreq');           funcFreq = p.funcFreq;         % afn stores it
        elseif isfield(p, 'dur') && p.dur > 0;   funcFreq = nSamples / p.dur;   % derive for pfn
        else;  error('Build funcFreq not stored for ID %d; pass funcFreq explicitly.', funcID); end
    end

    funcFreqUsed = funcFreq;
    dur = nSamples / funcFreq;
end
