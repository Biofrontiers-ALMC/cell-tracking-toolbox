clearvars
testDir = 'D:\Projects\Linear Assignment Linker\code\tbx\docs\examples\three-particles';

imgs = dir(fullfile(testDir, '3p_*.png'));

TL = LAPLinker;
TL.LinkScoreRange = [0 100];

for ii = 1:numel(imgs)
    
    I = imread(fullfile(testDir, imgs(ii).name));
    I = rgb2gray(I);
    
    mask = I > 0;
    data = regionprops(mask, 'Centroid');
    
    TL = assignToTrack(TL, ii, data);    
    
end

imshow(I);
hold on
for ii = 1:numel(TL.activeTrackIDs)
    
    track = getTrack(TL, TL.activeTrackIDs(ii));
    plot(track.Centroid(:,1) ,track.Centroid(:, 2));
    
end
hold off