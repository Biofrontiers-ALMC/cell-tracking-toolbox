classdef trackmetadata
    %TRACKMETADATA  Class to hold metadata for a dataset
    %
    %  OBJ = TRACKMETADATA(OBJ, 'property', value, ...) will set the
    %  metadata property to the value specified. Commonly-used information
    %  is included in the object properties, while user-specified metadata
    %  information will be listed under the 'userdata' property.
    %
    %  trackmetadata Properties:
    %    filename       - File linked to this dataset
    %    description    - User-specified description of the dataset
    %    pixelsize      - Physical size of a pixel (used to convert data
    %                     values into real units)
    %    pixelsizeunits - Unit of the pixel size
    %    timestamps     - Timestamps for each frame in the movie
    %    timestampunits - Unit of the timestamps
    %
    %    userdata       - Stores user-specified properties
    %
    %    createdon      - Date and time the object was created (Constant)
    %    version        - Toolbox version when the object was created
    %                     (Constant)
    %
    %  trackmetadata Methods:
    %    set     - Set metadata property
    %    get     - Get metadata property
    
    properties
        
        filename char
        description char
        
        pixelsize double
        pixelsizeunits char
        
        timestamps double
        timestampunits char
        
        userdata
        
    end
    
    properties (Constant)
        
        createdOn = datestr(now);
        version = ver('lap-cell-tracker');
        
    end
    
    methods
        
        function obj = set(obj, varargin)
            %SET  Set metadata properties
            %
            %  OBJ = SET(OBJ, 'property', value...) sets the value for the
            %  metadata property specified.
            %
            %  Example:
            %      %Set the filename related to this dataset
            %      OBJ = set(OBJ, 'filename', 'newFile.nd2');
            %
            %      %Create a new user-specified metadata property called
            %      %well location
            %      OBJ = set(OBJ, 'WellLocation', 'A01');
            %
            %  See also: get
            
            %Validate the input
            if rem(numel(varargin),2) ~= 0
                error('Input arguments must be property/value pairs');
            end
            
            propNames = lower(varargin(1:2:end));
            propValues = varargin(2:2:end);
            
            objProperties = properties(obj);
            
            for iP = 1:numel(propNames)
                
                if ismember(propNames{iP}, objProperties)
                    
                    obj.(propNames{iP}) = propValues{iP};
                    
                else
                    
                    %Check fieldname is valid
                    if ~isvarname(propNames{iP})
                        error('trackmetadata:InvalidFieldName',...
                            'Invalid field name: ''%s''. Names must follow MATLAB variable naming requirements.',...
                            propNames{iP});
                    end
                    
                    obj.userdata.(propNames{iP}) = propValues{iP};
                    
                end
                
            end
            
        end
        
        function mdValue = get(obj, reqProperty)
            %GET  Get metadata value
            %
            %  OBJ = GET(OBJ, 'property') returns the metadata property
            %  specified.
            %
            %  Example:
            %    md = trackmetadata;
            %    md = set(md, 'filename', 'new filename');
            %
            %    get(md, 'filename')
            
            reqProperty = lower(reqProperty);
            
            if ismember(reqProperty, properties(obj))
                mdValue = obj.(reqProperty);
            else
                mdValue = obj.userdata.(reqProperty);
            end
            
        end
        
    end
    
end