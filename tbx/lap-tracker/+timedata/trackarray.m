classdef trackarray
    
    properties
        tracks@timedata.trackdata
        series = 1;
    end
    
    properties (Dependent)
        
        numtracks
               
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
        
        function numTracks = get.numtracks(obj)
            numTracks = numel(obj.tracks);
        end
        
        function obj = addTrack(obj)
            %Add track to current series
            
            
            
        end
        
    end
    
    
end