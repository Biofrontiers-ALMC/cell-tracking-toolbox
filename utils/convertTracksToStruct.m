%Auto-convert

%Get all MAT-files
fname = dir('D:\Documents\MATLAB\genescreening\Plate 9\20190613\*.mat');

for iF = 1:numel(fname)
    
    S = load(fullfile(fname(iF).folder, fname(iF).name));

    fields = fieldnames(S);
    
    for field = 1:numel(fields)
        
        if isa(S.(fields(field)), 'TrackDataArray')
            
            structOut = track
            
        end
        
        
    end
    
    
end

