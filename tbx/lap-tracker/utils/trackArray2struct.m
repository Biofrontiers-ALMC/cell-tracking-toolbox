function [data, metadata] = trackArray2struct(trackarray)

%Autorun


if ~isa(trackarray, 'TrackDataArray')
    error('trackArray2struct:NotTrackDataArray', ...
        'Expected input to be a TrackDataArray object but it is a %s object instead.', ...
        class(trackarray));
end

data = struct('FirstFrame', {});

%Import each track as a new struct
for iTrack = 1:trackarray.NumTracks
    
    ct = getTrack(trackarray, iTrack);
    
    newIdx = numel(data) + 1;
    data(newIdx).FirstFrame = ct.FirstFrame;
    data(newIdx).LastFrame = ct.LastFrame;
    
    for iP = 1:numel(ct.TrackDataProps)
        data(newIdx).(ct.TrackDataProps{iP}) = ...
            getData(ct, ct.TrackDataProps{iP});
    end
end

if nargout > 1
    
    metadata.NumTracks = trackarray.NumTracks;
    metadata.NumFrames = trackarray.NumFrames;
    
    %Copy the file metadata
    mdFields = fieldnames(trackarray.FileMetadata);
    for iMD = 1:numel(mdFields)
        
        metadata.(mdFields{iMD}) = trackarray.FileMetadata.(mdFields{iMD});
        
    end
    
    metadata.MeanDeltaT = trackarray.MeanDeltaT;
    metadata.CreatedOn = trackarray.CreatedOn;
    
end

end