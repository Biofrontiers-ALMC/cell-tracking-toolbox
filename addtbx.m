function addtbx
%ADDTBX  Adds the toolbox to the path
%
%  ADDTBX will add all folders under the 'tbx' directory to the
%  current search path.
%
%  See also: rmtbx

%Get the list of folders under the tbx directory
dirlist = dir('tbx');
dirlist(~[dirlist.isdir] | ismember({dirlist.name}, {'.','..'})) = [];

%Add them to the current path
for ii = 1:numel(dirlist)
    addpath(fullfile(dirlist(ii).folder, dirlist(ii).name));
end

end