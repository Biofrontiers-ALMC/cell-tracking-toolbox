bfr = BioformatsImage('teto_red50_xy0002.nd2');
ROI = [1320, 1050, 340, 400];

vr = VideoWriter('output.avi');
vr.Quality = 100;
vr.FrameRate = 5;

vr_an = VideoWriter('output2.avi');
vr_an.Quality = 100;
vr_an.FrameRate = 5;

open(vr);
open(vr_an);

TL = LAPLinker;
TL.LinkedBy = 'PixelIdxList';
TL.LinkCostMetric = 'pxintersect';
TL.LinkScoreRange = [1, 12];
TL.MaxTrackAge = 2;

TL.TrackDivision = true;
TL.DivisionParameter = 'PixelIdxList';
TL.DivisionScoreMetric = 'pxintersect';
TL.DivisionScoreRange = [1, 12];
TL.MinFramesBetweenDiv = 2;

for iT = 1:(bfr.sizeT - 2)

    I = getPlane(bfr, 1, '555-mOrange', iT, 'ROI', ROI);
    
    IBF = getFalseColor(bfr, 1, 'Red', iT, 'ROI', ROI);
    IBF = double(IBF)/65535;
    
    mask = fluorescenceSeg(I, struct('thFactor', 4));
        
    outlines = bwperim(mask);
    outlines = imdilate(outlines, ones(1));
    Iout = showoverlay(double(I), outlines, 'normalize', true);
    
    writeVideo(vr, [IBF, Iout]);
    
    cellData = regionprops(mask, I, 'Centroid', 'MajorAxisLength', 'MeanIntensity', 'PixelIdxList');
    
    TL = assignToTrack(TL, iT, cellData);
    
    for iTrack = 1:numel(TL.tracks)
        
        if iT >= TL.tracks(iTrack).Frame(1) && iT <= TL.tracks(iTrack).Frame(end)
            
            Iout = insertText(Iout, TL.tracks(iTrack).Centroid{end}, iTrack,...
                'BoxOpacity', 0,'TextColor', 'blue', 'FontSize', 15, 'Font', 'Roboto Black', ...
                'AnchorPoint', 'center');
            

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

close(vr);
close(vr_an);
