clearvars
clc

reader = BioformatsImage('D:\Projects\Toolboxes\Linear Assignment Linker\data\2023_Holtzen_FUCCIsensor.nd2');

tracker = LAPLinker;

tracker.TrackDivision = true;
tracker.DivisionType = 'mitosis';

vid = VideoWriter('testmitosis.avi');
vid.FrameRate = 7;
open(vid);

for iT = 15:25

   currI = getPlane(reader, 1, 'Cy5', iT);
   mask = imbinarize(currI);

   dd = -bwdist(~mask);
   dd(~mask) = -Inf;
   dd = imhmin(dd, 5);

   L = watershed(dd);

   mask(L == 0) = 0;

   mask = bwareaopen(mask, 20);

   data = regionprops(mask, 'Area', 'Centroid');

   tracker = assignToTrack(tracker, iT, data);


   %Generate an output image to validate
   Iout = showoverlay(currI, bwperim(mask));
   Iout = double(Iout);
   Iout = Iout ./ max(Iout, [], 'all');

   %Insert the IDs of active tracks
   for iActive = tracker.activeTrackIDs
       trackData = getTrack(tracker, iActive);
       Iout = insertText(Iout, trackData.Centroid(end, :), trackData.ID, ...
           'BoxOpacity', 0, 'TextColor', 'blue', 'AnchorPoint', 'Center', 'FontSize', 25);
   end

   writeVideo(vid, Iout);

end
close(vid)