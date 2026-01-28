% make_patt_static_verticalbar_G4
% pattern generator, creates a single bar where DAC = 0 is the middle of
% the blank panel with an identical static bar

% INPUTS:
% pattN - pattern number when saving
% objWidth - size of bar
% objPolar - set polarity to dark or bright vs background

% 2025 - TLN created

function  make_patt_static_verticalbar_G4(pattN, objWidth, staticLoc, objPolar, maxGS)

%% set meta data

userSettings

pattern.x_num = 192; 	
pattern.y_num = 2;

pattern.num_panels = NumofRows*NumofColumns; 	
pattern.gs_val = 4; %1 or 4
pattern.stretch = zeros(pattern.x_num, pattern.y_num); %match frames
frameN = 16*NumofRows; %px per row
frameM = 16*NumofColumns; %px per col

%initialize pattern data
Pats = zeros(frameN, frameM, pattern.x_num, pattern.y_num);

%set brightness and object polarity
if contains(objPolar,'d') %dark bar on bright background
    objGS = 0; %object
    bckGS = maxGS; %background
else %bright bar on dark background
    objGS = maxGS; %object
    bckGS = 0; %background
end


%% generate pattern data

bckImage = ones(frameN, frameM) * bckGS; %initialize

% bar only
barImage = bckImage; 
barImage(:,1:objWidth) = objGS;
Pats(:, :, 1, 1) = barImage;
% background only
Pats(:, :, 1, 2) = bckImage;

%save lookup table
patlookup.fullname = [num2str(objWidth) 'px_' num2str(objGS) 'gs' objPolar '_bar_' num2str(bckGS) 'gsbck'];
patlookup.name = [num2str(objWidth) 'px_' objPolar 'bar'];
patlookup.size = num2str(objWidth);
patlookup.object = 'bar';
patlookup.objgs = objGS;
patlookup.bckgs = bckGS;

for x = 2:frameM
    Pats(:,:,x,1) = ShiftMatrix(Pats(:,:,x-1,1),1,'r','y');
    Pats(:,:,x,2) = ShiftMatrix(Pats(:,:,x-1,2),1,'r','y');
end

Pats = cat(3, Pats(:,:,137:end,:), Pats(:,:,1:136,:));

for i = 1:size(Pats, 3)
    Pats(:, staticLoc:staticLoc+objWidth, i, 1) = objGS;
end

%store pattern data
pattern.Pats = Pats;
%get the vector data
pattern.data = make_pattern_vector_g4(pattern);


%% save pattern data

%set and save pattern data
pattName = [sprintf('%04d', pattN) '_' num2str(objWidth) 'px_' objPolar 'bar'];
matFileName = fullfile([exp_path, '\Patterns'], [pattName, '.mat']);
save(matFileName, 'pattern');

%save pattern lookup table
pattLookUp = ['patt_lookup_' sprintf('%04d', pattN)];
matFileName = fullfile(pattern_path, [pattLookUp, '.mat']);
save(matFileName, 'patlookup');

%save pat file
patFileName = fullfile([exp_path, '\Patterns'], ['pat', sprintf('%04d', pattN), '.pat']);
fileID = fopen(patFileName,'w');
fwrite(fileID, pattern.data);
fclose(fileID);
end

