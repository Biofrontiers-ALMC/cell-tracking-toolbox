classdef trackarray
    %TRACKARRAY  Container class to hold multiple trackdata objects
    %
    %  
    
    properties (SetAccess = private)
        tracks
    end
    
    properties (Dependent)
        
        numTracks
               
    end
    
    methods
        
        function obj = trackarray(varargin)
            %
            %  TA = timedata.trackarray(10) will initialize a trackarray
            %  object with 10 tracks
            
            if nargin ~= 0
                obj.tracks = timedata.trackdata(varargin{1});
            end
            
        end
        
        function numTracks = get.numTracks(obj)
            numTracks = numel(obj.tracks);
        end
        
        function [obj, newTrackID] = addTrack(obj, varargin)
            %ADDTRACK  Add track to the array
            %
            %  OBJ = addTrack(OBJ) will add an empty trackdata object to
            %  the array.
            
            newTrackID = obj.numTracks + 1;
            
            if newTrackID == 1
                obj.tracks = timedata.trackdata;
            else
                obj.tracks(newTrackID) = timedata.trackdata;
            end
            
            obj.tracks(newTrackID).trackID = newTrackID;
            
            
        end
        
        function obj = delTrack(obj, trackIndex, varargin)
            %DELTRACK  Delete track(s) from the array
            %
            %  OBJ = DELTRACK(OBJ, I) will delete track I from the array. I
            %  can be either a vector listing the tracks to delete or a
            %  logical array. If I is logical, it should have the same
            %  number of elements as the number of tracks in the array.
            %
            % 
            
            
        end
        
    end
    
    
end