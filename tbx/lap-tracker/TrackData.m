classdef TrackData
    %TRACKDATA  Data class to hold data for a single track
    %
    %  T = TRACKDATA will create an empty TrackData object.
    %
    %  TrackData Properties:
    %
    %  TrackData Methods:
    
    properties (Hidden)
        
        FrameIndex
        Data
        
    end
    
    properties
        
        ID = 0;
        MotherIdx = NaN;
        DaughterIdxs = NaN;
        
    end
    
    properties (Dependent)
        
        TrackDataProps
        
        FirstFrame
        LastFrame
        NumFrames
        
    end
    
    methods
        
        function obj = TrackData(varargin)
            %TRACKDATA  Constructor function for TrackData object
            
            if nargin > 0
                
                ip = inputParser;
                ip.addRequired('frameIndex', @(x) isnumeric(x) && isscalar(x));
                ip.addRequired('trackData', @(x) isstruct(x));
                ip.parse(varargin{:});
                
                obj = obj.addFrame(ip.Results.frameIndex, ip.Results.trackData);
                
            end
            
        end
        
        function numFrames = get.NumFrames(obj)
            %GET.NUMFRAMES  Get number of frames
            
            numFrames = (obj.LastFrame - obj.FirstFrame) + 1;
            
        end
        
        function dataProperties = get.TrackDataProps(obj)
            %GET.TRACKDATAPROPS  Get list of data properties
            %
            %  Data properties are quantities which are measured for each
            %  track.
            
            if isempty(obj.Data)
                dataProperties = '';
            else
                dataProperties = fieldnames(obj.Data);
            end
            
        end
        
        function firstFrame = get.FirstFrame(obj)
            
            if isempty(obj.Data)
                firstFrame = -Inf;
            else
                firstFrame = obj.FrameIndex(1);
            end
            
        end
        
        function lastFrame = get.LastFrame(obj)
            
            if isempty(obj.Data)
                lastFrame = -Inf;
            else
                lastFrame = obj.FrameIndex(end);
            end
            
        end
        
        function obj = addFrame(obj, tFrame, data)
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
            %
            %  See also: TrackData.updateTrack
            
            %Validate the frame number
            if ~isnumeric(tFrame)
                error('TrackData:addFrame:frameIndexNotNumeric',...
                    'Expected the frame index to be a number.');
                
            elseif ~isscalar(tFrame)
                error('TrackData:addFrame:frameIndexNotScalar',...
                    'Expected the frame index to be a scalar number.');
                
            else
                if ~(tFrame < obj.FirstFrame || tFrame > obj.LastFrame)
                    
                    error('TrackData:addFrame:frameIndexInvalid',...
                        'The frame index should be < %d or > %d.',...
                        obj.FirstFrame, obj.LastFrame);
                end
            end
            
            %Valide the input data
            if ~isstruct(data)
                error('TrackData:addFrame:dataNotStruct',...
                    'Expected data to be a struct.');
            end            
            
            %Add the frame to the track
            if tFrame > obj.LastFrame
                
                if isinf(obj.FirstFrame) && isinf(obj.LastFrame)
                    %If both start and end frames are infinite, then this
                    %is the first frame to be added
                    obj.Data = data;
                    obj.FrameIndex = tFrame;
                    
                else
                    %Calculate the number of frames to add
                    numFramesToAdd = tFrame - obj.LastFrame;
                    
                    %Add the frame to the end of the array
                    obj.Data(end + numFramesToAdd) = data;
                    
                    %Update the frame indices
                    obj.FrameIndex = obj.FirstFrame:tFrame;
                    
                end
                
            elseif tFrame < obj.FirstFrame
                %Overwrite the Data property with new frame data, then move
                %the old data to the end of the structure.
                oldData = obj.Data;         %Save a copy of the old data
                obj.Data = data;       %Overwrite the Data property
                
                %Move the old data to the end of the structure
                dataInd = obj.FirstFrame - tFrame + 1;
                obj.Data(dataInd:dataInd + numel(oldData) - 1) = oldData;
                
                %Update the frame indices
                obj.FrameIndex = tFrame:obj.LastFrame;
                
            end
            
        end
        
        function obj = deleteFrame(obj, tFrame)
            %DELETEFRAME  Deletes the specified frame
            %
            %  T = T.DELETEFRAME(f, frameIndex) deletes the specified
            %  frame(s) from the track.
            %
            %  Examples:
            %
            %    %Create a track with four frames
            %    trackObj = TrackData;
            %    trackObj = trackObj.addFrame(1, struct('Area',5));
            %    trackObj = trackObj.addFrame(2, struct('Area',10));
            %    trackObj = trackObj.addFrame(3, struct('Area',20));
            %    trackObj = trackObj.addFrame(4, struct('Area',40));
            %
            %    %Delete frame 2
            %    trackObj = trackObj.deleteFrame(2);
            %
            %    %Delete frames 1 and 4
            %    trackOb = trackObj.deleteFrame([1, 4]);
            %
            %  See also: TrackData.updateTrack
            
            %Validate the frame index input
            if isnumeric(tFrame)
                if ~(all(tFrame >= obj.FirstFrame & tFrame <= obj.LastFrame))
                    error('TrackData:deleteFrame:frameIndexInvalid',...
                        'The frame index should be between %d and %d.',...
                        obj.FirstFrame, obj.LastFrame);
                end
                
                %Convert the frame index into the index for the data array
                dataInd = tFrame - obj.FirstFrame + 1;
                
            elseif islogical(tFrame)
                if (numel(tFrame) ~= obj.NumFrames) || (~isvector(tFrame))
                    error('TrackData:deleteFrame:frameIndexInvalidSize',...
                        'If the frame index is a logical array, it must be a vector with the same number of elements as the number of frames.');
                end
                
                %If it is a logical array, the usual deletion syntax should
                %work
                dataInd = tFrame;
                
                %Calculate the frame indices to delete
                tFrame = obj.FirstFrame + find(dataInd) - 1;
                
            elseif ischar(tFrame)
                
                if any(strcmpi(tFrame,{'last','end'}))
                    dataInd = numel(obj.Data);
                else
                    error('TrackData:deleteFrame:frameIndexCharInvalid',...
                        'Expected the frame index to be a number, a logical array, or ''last''.');
                end
                
            else
                error('TrackData:deleteFrame:frameIndexNotNumericOrLogical',...
                    'Expected the frame index to be a number or a logical array.');
            end
            
            %Remove the frame(s)
            obj.Data(dataInd) = [];
            
            %Renumber the frames
            for iF = 1:numel(tFrame)
                if tFrame(iF) == obj.FirstFrame
                    obj.FrameIndex(1) = [];
                    
                elseif tFrame(iF) == obj.LastFrame
                    obj.FrameIndex(end) = [];
                    
                else
                    obj.FrameIndex = obj.FirstFrame:obj.FirstFrame + numel(obj.Data) - 1;
                end
            end

            
        end
                
        function plot(obj)
            
            figure(1);
            tt = obj.FirstFrame:obj.LastFrame;
            yy = zeros(1,obj.NumFrames);
            for ii = 1:obj.NumFrames
                yy(ii) = [obj.Data(ii).channel1.TotalIntensity]./[obj.Data(ii).channel15.TotalIntensity];
            end
            plot(tt,yy)
            title('Ratio')
            hold on
            
            figure(2);
            tt = obj.FirstFrame:obj.LastFrame;
            yych1 = zeros(1,obj.NumFrames);
            for ii = 1:obj.NumFrames
                yych1(ii) = [obj.Data(ii).channel1.TotalIntensity]./[obj.Data(ii).Area];
            end
            plot(tt,yych1)
            title('Channel 1')
            hold on
            
            figure(3);
            yych15 = zeros(1,obj.NumFrames);
            for ii = 1:obj.NumFrames
                yych15(ii) = [obj.Data(ii).channel15.TotalIntensity]./[obj.Data(ii).Area];
            end
            plot(tt,yych15)
            title('Channel 15')
            hold on
            
            figure;
            yyaxis left
            plot(tt,yych1)
            ylabel('Channel 1')
            yyaxis right
            plot(tt,yych15)
            ylabel('Channel 15')
            
            
        end
        
        function dataOut = getData(obj, reqData)
            %GETDATA  Get specified tracked data
            
            if ~ismember(reqData, obj.TrackDataProps)
                error('TrackData:getData:InvalidPropertyName',...
                    '''%s'' is not a valid property name.',...
                    reqData);
            end
            
            %Initialize the output data vector
            dataOut = nan(obj.NumFrames, size(obj.Data(1).(reqData),2));
            
            for iD = 1:obj.NumFrames
                currData = obj.Data(iD).(reqData);
                if ~isempty(currData)
                    dataOut(iD,:) = currData;
                end
            end
            
        end
        
    end
end
