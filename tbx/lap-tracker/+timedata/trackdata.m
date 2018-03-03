classdef trackdata
    %TRACKDATA  Class for holding timeseries data for a single track
    %
    
    properties
        
        trackID(1, 1) uint32 = 0;
        seriesID(1, 1) uint32 = 0;
        motherTrackID(1, 1) uint32 = 0;
        daughterTrackIDs(1, 2) uint32 = [0 0];
                
    end
    
    properties (SetAccess = private)
       
        frames uint16
        data
        
    end
    
    properties (Dependent)
        
        TrackDataProps
        
        FirstFrame
        LastFrame
        NumFrames
        
    end
    
    methods
        
        function obj = trackdata(varargin)
            %TRACKDATA  Constructor function for the trackdata class
            %
            %  T = TRACKDATA creates a (1-by-1) scalar trackdata object
            %  with default properties.
            %
            %  T = TRACKDATA(n) returns a 1-by-n trackdata object array.
            %
            %  T = TRACKDATA(n, property, value) returns a 1-by-n trackdata
            %  object array. The trackdata object properties will be
            %  populated using the property/value pair specified.
            %
            %  Example: 
            %    T = TRACKDATA(5, 'seriesID', 1) will return a 1-by-5
            %    trackdata object array. The 'seriesID' property of each
            %    object will be set to 1.
            
            if nargin ~= 0
                
                %Validate the input(s)
                if ~isnumeric(varargin{1}) || ~isscalar(varargin{1})
                    error('trackdata:InvalidSize', ...
                        'The size parameter must be numeric and scalar.');
                end
                
                %Initialize an empty array
                obj(varargin{1}) = timedata.trackdata;
                
                %If additional parameters exist, then treat them as
                %property assignments
                for iP = 2:2:(numel(varargin) - 1)
                    for iN = 1:numel(obj)
                        obj(iN).(varargin{iP}) = varargin{iP + 1};
                    end
                end
                
            end
            
        end
        
        function firstFrame = get.FirstFrame(obj)
            
            if isempty(obj.frames)
                firstFrame = Inf;
            else
                firstFrame = double(obj.frames(1));
            end            
            
        end
        
        function lastFrame = get.LastFrame(obj)
            
            if isempty(obj.frames)
                lastFrame = -Inf;
            else
                lastFrame = double(obj.frames(end));
            end
        end
        
        function numFrames = get.NumFrames(obj)
            
            numFrames = double(obj.LastFrame - obj.FirstFrame + 1);
             
        end
        
        function obj = addFrame(obj, tFrame, data, varargin)
            %ADDFRAME  Add data for a frame
            %
            %  T = T.ADDFRAME(f, dataStruct) adds a new frame at index f to
            %  the start or the end of the track. The frame data should be
            %  in a structure, with the fieldnames of the structure
            %  corresponding to the measured data property name.
            %
            %  If the new frame data has a new property that was not
            %  present in the previous frames, the value for the missing
            %  data will be empty ([]).
            %
            %  Example:
            %
            %    T = TrackData(1, struct('Area', 5));
            %
            %    %In frame 2, 'Area' is no longer measured, but 'Centroid'
            %    %is
            %    T = T.ADDFRAME(2, struct('Centroid', [10 20]));
            %
            %    %These are the expected outputs:
            %    T.Data(1).Area = 2
            %    T.Data(1).Centroid = []
            %
            %    T.Data(2).Area = []
            %    T.Data(2).Centroid = [10 20]
            
            %Validate the frame number
            if ~isnumeric(tFrame) || ~isscalar(tFrame)
                error('trackdata:addFrame:InvalidFrameIndex',...
                    'Expected frame index to be numeric and scalar.');
            end
            
            %Validate the input data
            if ~isstruct(data)
                error('trackdata:addFrame:DataNotStruct',...
                    'Expected input data to be a struct.');
            end
            
            %Check if the overwrite option is selected
            overwriteFlag = false;
            if ~isempty(varargin)
                if strcmpi(varargin{1}, 'overwrite')
                    overwriteFlag = true;
                end
            end
                        
            %Add the frame to the track
            if isinf(obj.FirstFrame) && isinf(obj.LastFrame)
                %If both start and end frames are infinite, then this
                %is the first frame to be added
                obj.data = data;
                obj.frames = tFrame;
                
            elseif tFrame > obj.LastFrame
                
                    %Calculate the number of frames to add
                    numFramesToAdd = tFrame - obj.LastFrame;
                    
                    %Add the frame to the end of the array
                    obj.data(end + numFramesToAdd) = data;
                    
                    %Update the frame indices
                    obj.frames = obj.FirstFrame:tFrame;
                
            elseif tFrame < obj.FirstFrame
                
                %Overwrite the Data property with new frame data, then move
                %the old data to the end of the structure.
                oldData = obj.data;         %Save a copy of the old data
                obj.data = data;       %Overwrite the Data property
                
                %Move the old data to the end of the structure
                dataInd = obj.FirstFrame - tFrame + 1;
                obj.data(dataInd:dataInd + numel(oldData) - 1) = oldData;
                
                %Update the frame indices
                obj.frames = tFrame:obj.LastFrame;
                
            else %tFrame > obj.FirstFrame and tFrame < obj.LastFrame
                
                %If no data currently exists, then overwrite
                dataInd = tFrame - obj.FirstFrame + 1;
                
                if all(structfun(@isempty, obj.data(dataInd))) || overwriteFlag
                    obj.data(dataInd) = data;
                else
                    error('trackdata:addFrame:FrameDataExists',...
                        'Data already exists at frame %d. Use the ''overwrite'' option to overwrite this data.',...
                        tFrame);
                end
                
            end
            
        end

        function obj = delFrame(obj, framesToDel)
            %DELFRAME  Deletes the specified frame
            %
            %  delFrame(T, F) will delete frame F from the trackdata
            %  object. If F is the first or last frame, the frame index
            %  will be updated accordingly. Otherwise, the frame data is
            %  emptied, but the frame index is kept the same.
            
            %Validate the input
            if isnumeric(framesToDel)
                if ~(all(framesToDel >= obj.FirstFrame & framesToDel <= obj.LastFrame))
                    error('trackdata:delFrame:frameIndexInvalid',...
                        'Frame numbers to be deleted should be between %d (first frame) and %d (last frame).',...
                        obj.FirstFrame, obj.LastFrame);
                end
                
            elseif ischar(tFrame)
                
                if strcmpi(framesToDel, 'first')
                    framesToDel = obj.FirstFrame;
                    
                elseif strcmpi(framesToDel, 'last')
                    framesToDel = obj.LastFrame;
                    
                else
                    error('trackdata:delFrame:InvalidCharInput',...
                        'Expected the input to be ''first'' or ''last''');
                end
                
            else
                error('trackdata:delFrame:InvalidInput',...
                    'Expected the frame index to be numerical,''first'' or ''last''');
            end

            %Sort the indices in descending order. This will ensure that
            %when deleting from the end of the array, the data will be
            %deleted sequentially (i.e. delFrame(T, 7:10) will make the new
            %first frame number = 6).
            %
            %A 'while' loop is in place to handle deletion of empty frames
            %when the indices are from the start. The reason I wrote the
            %code this way is to favor faster deletion from the end of the
            %track (which is performed during mitosis detection)
            framesToDel = sort(framesToDel, 'descend');
            
            %Convert the frame index into the index for the data array
            dataInd = framesToDel - obj.FirstFrame + 1;
            
            %Delete the data
            for iDel = 1:numel(framesToDel)
                if framesToDel(iDel) == obj.FirstFrame
                    obj.frames(1) = [];
                    obj.data(1) = [];
                    
                    %Remove empty frames from the start
                    while all(structfun(@isempty ,obj.data(1)))
                        obj.frames(1) = [];
                        obj.data(1) = [];
                    end
                    
                elseif framesToDel(iDel) == obj.LastFrame
                    obj.frames(end) = [];
                    obj.data(end) = [];
                    
                else
                    
                    fn = fieldnames(obj.data(dataInd(iDel)))';
                    fn{2, 1} = cell(1);
                    
                    %Make the data empty
                    obj.data(dataInd(iDel)) = struct(fn{:});

                end
            end
                        
        end
        
        function newTrackdata = getFrame(obj, framesToGet)
            %GETFRAMES  Subset of time series samples
            %
            %  ST = GETFRAMES(T, F) returns a new trackdata object
            %  containing data from the specified frames. All other object
            %  properties (e.g. trackID, seriesID...) will be copied from
            %  the original object
            
            %Validate the input
            if isnumeric(framesToGet)
                if ~(all(framesToGet >= obj.FirstFrame & framesToGet <= obj.LastFrame))
                    error('trackdata:getFrame:frameIndexInvalid',...
                        'Frame numbers to be deleted should be between %d (first frame) and %d (last frame).',...
                        obj.FirstFrame, obj.LastFrame);
                end
                
            elseif ischar(tFrame)
                
                if strcmpi(framesToGet, 'first')
                    framesToGet = obj.FirstFrame;
                    
                elseif strcmpi(framesToGet, 'last')
                    framesToGet = obj.LastFrame;
                    
                else
                    error('trackdata:getFrame:InvalidCharInput',...
                        'Expected the input to be ''first'' or ''last''');
                end
                
            else
                error('trackdata:getFrame:InvalidInput',...
                    'Expected the frame index to be numerical,''first'' or ''last''');
            end
            
            %Duplicate the object
            newTrackdata = obj;
            
            %Delete unwanted frames
            framesToDel = obj.FirstFrame:obj.LastFrame;
            for iG = framesToGet
                framesToDel(framesToDel == iG) = [];
            end
            
            newTrackdata = delFrame(newTrackdata, framesToDel);
             
            
        end
        
        %TODO
%         function getData
%             
%         end
        
    end
    
    
    
end