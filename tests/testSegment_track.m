clearvars
clc

bfr = BioformatsImage('teto_red50_xy0002.nd2');
ROI = [1320, 1050, 340, 400];

vr_an = VideoWriter('testOutput.avi');
vr_an.Quality = 100;
vr_an.FrameRate = 5;

open(vr_an);

TL = LAPLinker;
TL.LinkedBy = 'PixelIdxList';
TL.LinkCostMetric = 'pxintersect';
TL.LinkScoreRange = [1, 12];
Tl.MaxTrackAge = 2;

%Mitosis detection parameters
TL.TrackDivision = true;
TL.MinFramesBetweenDiv = 2;
TL.DivisionParameter = 'PixelIdxList';          %What property is used for mitosis detection?
TL.DivisionScoreMetric = 'pxintersect';
TL.DivisionScoreRange = [1, 12];
TL.Solver = 'lapjv';

for iT = 1:(bfr.sizeT - 2)

    I = getPlane(bfr, 1, '555-mOrange', iT, 'ROI', ROI);
    
    IBF = getPlane(bfr, 1, 'Red', iT, 'ROI', ROI);
    IBF = double(IBF)/65535;
    
    IBF = repmat(IBF, [1, 1, 3]);
    
    mask = fluorescenceSeg(I, struct('thFactor', 5));
        
    outlines = bwperim(mask);
    outlines = imdilate(outlines, ones(1));
    Iout = showoverlay(double(I), outlines, 'normalize', true);
    
    
    cellData = regionprops(mask, I, 'Centroid', 'MajorAxisLength', 'MeanIntensity', 'PixelIdxList');
    
    TL = assignToTrack(TL, iT, cellData);
    
        
    for iTrack = 1:TL.NumTracks
        
        currTrack = TL.tracks.Tracks(iTrack);
        
        if iT >= currTrack.Frames(1) && iT <= currTrack.Frames(end)
            
            trackCentroid = cat(2,currTrack.Data.Centroid);
            
            if isfield(currTrack, 'RegCentroid')
                Iout = insertText(Iout, currTrack.Data.RegCentroid{end}, iTrack,...
                    'BoxOpacity', 0,'TextColor',[237, 85, 59]./255);
            else
                Iout = insertText(Iout, currTrack.Data.Centroid{end}, iTrack,...
                    'BoxOpacity', 0,'TextColor', 'blue', 'FontSize', 15, 'Font', 'Roboto Black', ...
                    'AnchorPoint', 'center');
            end
            
%             if iT > currTrack.FirstFrame
%                 Iout = insertShape(Iout, 'line', trackCentroid, 'color','white');
%             end
            
        end
    end    
    
    writeVideo(vr_an, [IBF, Iout]);
    
    [A,map] = rgb2ind([IBF, Iout],256);

    
%     if iT == 1
%         imwrite(A,map,'movie.gif', 'Loopcount', inf, 'DelayTime', 0.14);
%         
%     else
%         imwrite(A,map, 'movie.gif', 'Writemode', 'append', 'DelayTime', 0.14);
%     end   
    
end

close(vr_an);

array = TL.tracks;

save('trackdata.mat', 'array');

%% Plot data




