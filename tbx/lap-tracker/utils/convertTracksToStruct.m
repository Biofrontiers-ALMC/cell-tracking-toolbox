%Auto-convert

%Get all MAT-files
fname = dir('D:\Jian\Documents\Projects\KraljLab\Datasets\ShawnsPEC\20190224 Plate 9\processed\20190613 - Copy\*.mat');

for iF = 1:numel(fname)
    
    S = load(fullfile(fname(iF).folder, fname(iF).name));

    fields = fieldnames(S);
    
    for iField = 1:numel(fields)
        
        if isa(S.(fields{iField}), 'TrackDataArray')
            
            [data, metadata] = trackArray2struct(S.(fields{iField}));
            
            if ~exist(fullfile(fname(iF).folder, 'Original'), 'dir')
                mkdir(fullfile(fname(iF).folder, 'Original'));               
            end
            
            %Copy the original mat-file
            copyfile(fullfile(fname(iF).folder, fname(iF).name), fullfile(fname(iF).folder, 'Original', fname(iF).name));
                        
            %Save the current data
            save(fullfile(fname(iF).folder, fname(iF).name), 'data', 'metadata');            
            
            break;
            
        end
        
        
    end
    
    
end

