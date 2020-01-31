classdef TrackDataArray
    %TRACKDATAARRAY  Data class representing an array of tracks
    %
    %  TRACKDATAARRAY Properties:
    %     Filename - Filename of the movie this data was created from
    %     FileMetadata - Timestamps, pixel size and image size
    %     CreatedOn - Time and date the object was created on
    %     NumTracks - Number of tracks in array
    %     NumFrames - Length of tracked data in frames
    %     MeanDeltaT - Mean time between frames
    %     TrackedDataFields - Cell list of data fieldnames
    %
    %  TRACKDATAARRAY Methods:
    %     addTrack - Add a track to the array
    %     deleteTrack - Delete track from array
    %     getTrack - Get a specified track
    %     updateTrack - Update specified frames of a track
    %     deleteFrame - Delete frame(s) from a track
    %     updateMotherTrackIdx - Update track MotherTrackIdx property
    %     updateDaughterTrackIdxs - Update track DaugtherTrackIdxs property
    %     renameField - Rename data fields of all tracks in the array
    %
    %  See also: TrackData
        
    properties (Access = private)
        
        Tracks  %Object array of TrackData objects
        
    end
    
    properties (SetAccess = private)
        
        Filename = '';
        FileMetadata = struct(...
            'Timestamps', [], ...
            'TimestampUnit', '',...
            'PxSize', [], ...
            'PxSizeUnit', '', ...
            'ImgSize', [NaN, NaN]);
        
    end
    
    properties (Constant)
        
        CreatedOn = datestr(now); %Timestamp when object was created
        
    end
    
    properties (Dependent)
        
        NumTracks
        NumFrames
        MeanDeltaT
        
        TrackedDataFields
        
    end
    
    methods
        
        %--- Get/Set functions
        
        function numTracks = get.NumTracks(obj)
            
            numTracks = numel(obj.Tracks);
            
        end
        
        function numFrames = get.NumFrames(obj)
            
            firstFrame = min([obj.Tracks.FirstFrame]);
            
            lastFrame = max([obj.Tracks.LastFrame]);
            
            numFrames = lastFrame - firstFrame + 1;
            
        end
        
        function meanDeltaT = get.MeanDeltaT(obj)
            %Returns the mean time between frames
            
            if ~isempty(obj.FileMetadata.Timestamps)
                meanDeltaT = mean(diff(obj.FileMetadata.Timestamps));
            else
                meanDeltaT = [];
            end
            
        end
        
        function dataFieldnames = get.TrackedDataFields(obj)
            
            dataFieldnames = obj.getTrack(1).TrackDataProps;
            
        end
        
        function numTracks = numel(obj)
            %NUMEL  Count number of TrackData objects in the array 
            
            numTracks = numel(obj.Tracks);
            
        end
        
        function obj = setTimestampInfo(obj, tsIn, varargin)
            %SETTIMESTAMPINFO  Set timestamp information
            %
            %  A = A.SETTIMESTAMPS(V) where V is a 1xN vector will set the
            %  timestamp information to V. N must be equal to the number of
            %  frames in the array.
            %
            %  A = A.SETTIMESTAMPINFO(T) where T is a number will set the
            %  timestamp to (1:N) * T, i.e. T should be the time between
            %  frames.
            
            if nargin == 1
                %No timestamp units provided
                tsUnits = '';
            else
                tsUnits = varargin{1};
            end
            
            if numel(tsIn) == obj.NumFrames
                
                obj.FileMetadata.Timestamps = tsIn;
                
            elseif numel(tsIn) == 1
                
                obj.FileMetadata.Timestamps = (1:obj.NumFrames) * tsIn;
                
            else
                
                error('TrackDataArray:setTimestamps:UnexpectedInputLength',...
                    'Expected number of timestamps to match the number of frames (%d) or be equal to 1 to specify time between frames.',...
                    obj.NumFrames);
                
            end
            
            obj.FileMetadata.TimestampUnit = tsUnits;            
            
        end
        
        function [ts, tsUnits] = getTimestampInfo(obj)
            %GETTIMESTAMPINFO  Get timestamp information
            %
            %  [T, U] = A.GETTIMESTAMPINFO will return timestamps as vector
            %  T and units as string U.
            
            ts = obj.FileMetadata.Timestamps;
            tsUnits = obj.FileMetadata.TimestampUnit;
            
        end
        
        function obj = setPxSizeInfo(obj, pxLength, varargin)
            %SETPXSIZEINFO  Set pixel size information
            %
            %  A = A.SETPXSIZEINFO(L) will set the PxSize property of the
            %  FileMetadata to L. 
            %
            %  A = A.SETPXSIZEINFO(L,U) also sets a string U representing
            %  the unit of the property.
            
            obj.FileMetadata.PxSize = pxLength;
            
            if ~isempty(varargin)
                obj.FileMetadata.PxSizeUnit = varargin{1};                
            end
            
        end
        
        function [pxLength, pxUnits] = getPxSizeInfo(obj)
            %GETPXSIZEINFO  Get pixel size information
            %
            %  [L, U] = A.GETPXSIZEINFO returns the length of each image
            %  pixel L in physical units U.
            
            pxLength = obj.FileMetadata.PxSize;
            pxUnits = obj.FileMetadata.PxSizeUnit;
            
        end
        
        function obj = setImgSize(obj, imgSize)
            %SETIMGSIZE  Sets the image size in the file metadata
            %
            %  A = A.SETIMGSIZE([H W]) sets the image size to the height H
            %  and width W.
            
            obj.FileMetadata.ImgSize = imgSize;
            
        end
        
        function obj = setFilename(obj, fn)
            %SETFILENAME  Set filename property
            %
            %  The filename is linked to the dataset that this track data
            %  array was created from.
            %
            %  A = A.SETFILENAME(F) sets the filename to F.
            
            if ~isempty(obj.Filename)
                %Warn if not empty
                
                warning('TrackDataArray:setFilename:FilenameAlreadyExists',...
                    'The filename property is already set. Are you sure you want to change it?');
                s = input('Change filename (Y = change, anything else will cancel)? ','s');
                
                if ~strcmpi(s,'y')
                    return;
                end
            end
            
            obj.Filename = fn;
            
        end
        
        %--- Track functions
        
        function [obj, newTrackId] = addTrack(obj, frameIndex, trackData)
            %ADDTRACK  Add a track to the array
            %
            %  A.ADDTRACK(frameIndex, data) will add a new TrackData
            %  object, initializing it so it starts at the frame index
            %  and with the data specified. ''data'' should be a struct.
            
            if isempty(obj.Tracks)
                newTrackId = 1;
                obj.Tracks = TrackData(frameIndex,trackData);
                obj.Tracks(1).ID = newTrackId;
                
            else
                newTrackId = numel(obj) + 1;
                obj.Tracks(newTrackId) = TrackData(frameIndex,trackData);
                obj.Tracks(newTrackId).ID = newTrackId;
            end
            
        end
        
        function obj = updateTrack(obj, trackIndex, frameIndex, trackData)
            %UPDATETRACK  Update the specified track
            %
            %  A = A.UPDATETRACK(I, F, D) will update track I, frame F,
            %  with the data D.
            
            if trackIndex > numel(obj)
                error('TrackDataArray:updateTrack:InvalidIndex',...
                    'Expected track index to be between 1 and %d.',numel(obj));                
            end
            
            if frameIndex > obj.Tracks(trackIndex).LastFrame || frameIndex < obj.Tracks(trackIndex).FirstFrame
                obj.Tracks(trackIndex) = obj.Tracks(trackIndex).addFrame(frameIndex, trackData);
%             else
%                 obj.Tracks(trackIndex) = obj.Tracks(trackIndex).updateFrame(frameIndex, trackData);
            end
            
        end
        
        function obj = deleteTrack(obj, trackIndex)
            %DELETETRACK  Remove a track
            %
            %  A.DELETETRACK(trackIndex) will remove the TrackData object
            %  at the index specified.
            
            if isempty(obj.Tracks)
                error('TrackDataArray:deleteTrack:ArrayIsEmpty',...
                    'The track data array is empty.');
            else
                obj.Tracks(trackIndex) = [];
            end
            
        end
        
        function trackOut = getTrack(obj, trackIndex)
            %GETTRACK  Get the selected track
            %
            %  T = A.GETTRACK(I) will get the track at index I, returning a
            %  TrackData object to T.
            
            trackOut = obj.Tracks(trackIndex);
                        
        end
        
        function obj = deleteFrame(obj, trackIndex, frameIndex)
            
            obj.Tracks(trackIndex) = obj.Tracks(trackIndex).deleteFrame(frameIndex);
            
        end
        
        function obj = updateMotherTrackIdx(obj, trackIndex, motherTrackIdx)
            
            obj.Tracks(trackIndex).MotherIdx = motherTrackIdx;
            
        end
        
        function obj = updateDaughterTrackIdxs(obj, trackIndex, daughterTrackIdxs)
            
            obj.Tracks(trackIndex).DaughterIdxs = daughterTrackIdxs;
            
        end
                
        function obj = renameField(obj, oldFieldname, newFieldname)
            %RENAMEFIELD  Rename a tracked data field
            %
            %  A = A.RENAMEFIELD(O, N) renames the tracked data field O to
            %  N.
            %
            %  Example:
            %  
            %    A = A.RENAMEFIELD('MajorAxisLength','CellLength') will
            %    rename the tracked data field 'MajorAxisLength' to
            %    'CellLength' for all tracks within the array.

            for iT = 1:obj.NumTracks
                obj.Tracks(iT) = renameField(obj.Tracks(iT), oldFieldname, newFieldname);
            end
            
        end
        
        %--- Export data
        function exportToCSV(obj, fn)
            
            fid = fopen(fn, 'w');
            
            fprintf(fid, 'TID, MotherIdx, DaughterIdx1, DaughterIdx2, Frame, ');
            
            fprintf(fid,'%s ,', obj.TrackedDataFields{1:end-1});
            fprintf(fid,'%s \n', obj.TrackedDataFields{end});
            
            for iTrack = 1:numel(obj)
                
                ct = obj.getTrack(iTrack);
                
                fprintf(fid, '%d, %d, %d, %d', ct.ID, ct.MotherIdx, ct.DaughterIdxs(1), ct.DaughterIdxs(end));
                
                for iF = 1:ct.NumFrames
                    
                    if iF > 1
                        fprintf(fid, ', , , ');
                    end
                    
                    fprintf(fid, ', %d', ct.FrameIndex(iF));
                    
                    for iP = 1:numel(obj.TrackedDataFields)
                        
                        if numel(ct.Data(iF).(obj.TrackedDataFields{iP})) > 5
                            
                            fprintf(fid, ', %%');
                            
                        elseif numel(ct.Data(iF).(obj.TrackedDataFields{iP})) > 1
                            
                            fprintf(fid, ', %s', mat2str(ct.Data(iF).(obj.TrackedDataFields{iP}), 3));
                            
                        else
                            fprintf(fid, ', %d', ct.Data(iF).(obj.TrackedDataFields{iP}));
                            
                        end
                    end
                    fprintf(fid, '\n');
                end
                fprintf(fid, '\n');
                
            end
            
            fclose(fid);
            
            
        end
        
        function structOut = struct(obj)
            %STRUCT  Convert the object to struct
            %
            %  STRUCT(OBJ) will convert the object to a MATLAB
            %  structured array.
            
            %Initialize the track data struct
            structOut.TrackData = struct('FirstFrame', {}, ...
                'LastFrame', {}, ...
                'MotherIdx', {}, ...
                'DaughterIdx', {});
            
            trackProps = obj.TrackedDataFields;
            
%             for iP = 1:numel(trackProps)
%                 structOut.TrackData.(trackProps{iP}) = {};
%             end
            
            structOut.TrackData(obj.NumTracks).FirstFrame = 0;
            
            
            %Copy the data
            for iTrack = 1:obj.NumTracks
                
                ct = getTrack(obj, iTrack);
                
                structOut.TrackData(iTrack).FirstFrame = ct.FirstFrame;
                structOut.TrackData(iTrack).LastFrame = ct.LastFrame;
                structOut.TrackData(iTrack).MotherIdx = ct.MotherIdx;
                structOut.TrackData(iTrack).DaughterIdx = ct.DaughterIdxs;
                structOut.TrackData(iTrack).NumFrames = ct.NumFrames;
                structOut.TrackData(iTrack).FrameIndex = ct.FrameIndex;
                
                for iP = 1:numel(trackProps)
                    structOut.TrackData(iTrack).(trackProps{iP}) = ...
                       getData(ct, trackProps{iP});
                end
                
            end
            
            
            %Copy the metadata
            structOut.MeanDeltaT = obj.MeanDeltaT;
            structOut.Timestamps = obj.FileMetadata.Timestamps;
            structOut.TimestampUnit = obj.FileMetadata.TimestampUnit;
            structOut.PxSize = obj.FileMetadata.PxSize;
            structOut.PxSizeUnit = obj.FileMetadata.PxSizeUnit;
            structOut.ImgSize = obj.FileMetadata.ImgSize;
            structOut.NumTracks = obj.NumTracks;
            structOut.NumFrames = obj.NumFrames;
            structOut.TrackedDataFields = obj.TrackedDataFields;
            structOut.CreatedOn = obj.CreatedOn;
            structOut.Filename = obj.Filename;
            
        end
        
    end
    
end