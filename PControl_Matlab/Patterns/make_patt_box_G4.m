% make_patt_box_G4
% pattern generator, creates a single box at set height

% INPUTS:
% pattN - pattern number when saving
% objWidth - size of box (px)
% objPolar - set polarity to dark or bright vs background
% distFromTop - set distance of object from top of arena (px)
% bckGS - background intensity

% 01/10/2021 - MC created

function  make_patt_box_G4(pattN, objWidth, objPolar, distFromTop, maxGS)

%% set meta data

userSettings

pattern.x_num = 192; 	
pattern.y_num = 1;

pattern.num_panels = NumofRows*NumofColumns; 	
pattern.gs_val = 4; %1 or 4
pattern.stretch = zeros(pattern.x_num, pattern.y_num); %match frames
frameN = 16*NumofRows; %px per row
frameM = 16*NumofColumns; %px per col

%initialize pattern data
Pats = zeros(frameN, frameM, pattern.x_num, pattern.y_num);

%set object parameters
if contains(objPolar,'d') %dark obj on bright background
    objGS = 0; %object
    bckGS = maxGS; %background
else %bright obj on dark background
    objGS = maxGS; %object
    bckGS = 0; %background
end


%% generate pattern data

%initialize images
bckImage = ones(frameN, frameM) * bckGS;

boxImage = bckImage;
boxImage((end-distFromTop-objWidth):(end-distFromTop-1),1:objWidth) = objGS;

%generate pattern image based on selection
patImage = boxImage;
Pats(:, :, 1, 1) = patImage;

%rotate
for x = 2:frameM
    Pats(:,:,x,1) = ShiftMatrix(Pats(:,:,x-1,1),1,'r','y');
end

%save lookup table
patlookup.fullname = [num2str(objWidth) 'px_' num2str(objGS) 'gs' objPolar '_box_' num2str(distFromTop) 'high_' num2str(bckGS) 'gsbck'];
patlookup.name = [num2str(objWidth) 'px_' objPolar 'box_' num2str(distFromTop) 'high_only'];
patlookup.size = objWidth;
patlookup.height = distFromTop;
patlookup.object = 'box';
patlookup.objgs = objGS;
patlookup.bckgs = bckGS;
        

%store pattern data
pattern.Pats = Pats;
%get the vector data
pattern.data = make_pattern_vector_g4(pattern);


%% save pattern data

%set and save pattern data
pattName = [sprintf('%04d', pattN) '_' patlookup.name];
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

