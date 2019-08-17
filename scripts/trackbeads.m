%Demo code to track beads
%------------------------
%
%Instructions:
% 1. Download the movie fluorescentBeads.nd2 from
%
% 2. Download latest BioFormatsImage toolbox

bfr = BioformatsImage('fluorescentBeads.nd2');

Linker = LAPLinker;
Linker.LinkCostMetric = 'euclidean';
Linker.LinkedBy = 'Centroid';
Linker.LinkScoreRange = [0, 30];
Linker.TrackDivision = true;
Linker.DivisionScoreRange = [0, 10];

v = VideoWriter('beads.avi');
v.FrameRate = 10;
v.Quality = 95;
open(v)
for iT = 1:10%bfr.sizeT
    
    I = getPlane(bfr, 1, 'EGFP', iT);
    
    mask = I > 3000;
    mask = bwareaopen(mask, 10);
    
    rp = regionprops(mask, 'Centroid');
    
    Linker = assignToTrack(Linker, iT, rp);
    
    %Make a movie
    Iout = imadjust(getPlane(bfr, 1, 'EGFP', iT));   
        
    for ii = 1:numel(Linker.tracks)
        if numel(Linker.tracks(ii).Centroid) > 1
            Iout = insertShape(Iout, 'Line', cell2mat(Linker.tracks(ii).Centroid));
        end
        if Linker.tracks(ii).Frame(end) == iT
        Iout = insertText(Iout, Linker.tracks(ii).Centroid{end}, ii, ...
            'BoxOpacity', 0, 'TextColor', 'y');
        end
    end
    
    Iout = double(Iout);
    Iout = Iout ./ max(Iout(:));
    
    writeVideo(v, Iout);    
end
close(v);
