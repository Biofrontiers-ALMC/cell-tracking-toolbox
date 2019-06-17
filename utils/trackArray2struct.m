function structOut = trackArray2struct(trackarray)

%Autorun


if ~isa(trackarray, 'TrackDataArray')
    error('trackArray2struct:NotTrackDataArray', ...
        'Expected input to be a TrackDataArray object but it is a %s object instead.', ...
        class(trackarray));
end

structOut = struct;

%Import each track as a new struct
for iTrack = 1:trackarray.NumTracks
    
    ct = getTrack(trackarray, iTrack);
    
    newIdx = numel(structOut) + 1;
    structOut(newIdx).FirstFrame = ct.FirstFrame;
    structOut(newIdx).LastFrame = ct.LastFrame;
    
    for iP = 1:numel(ct.TrackDataProps)
        structOut(newIdx).(ct.TrackDataProps{iP}) = ...
            getData(ct, ct.TrackDataProps{iP});
    end
    
end

end