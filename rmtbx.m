function rmtbx
%TMTBX  Removes the toolbox to the path
%
%  RMTBX will remove all folders under the 'tbx' directory from the
%  current search path.
%
%  See also: addtbx

%Get the list of folders under the tbx directory
dirlist = dir('tbx');
dirlist(~[dirlist.isdir] | ismember({dirlist.name}, {'.','..'})) = [];

%Remove them from current path
for ii = 1:numel(dirlist)
    rmpath(fullfile(dirlist(ii).folder, dirlist(ii).name));
end

end