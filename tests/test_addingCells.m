clearvars 
clc

TA = TrackArray;

data.cellData = {[1 2 3], [4 5 6], [9 1]};
data.nn = 1;

newdata.cellData = {[4 5 6], [2 3]};
newdata.nn = 2;

TA = addTrack(TA, 2, data);
TA = updateTrack(TA, 1, 3, newdata);

TA.Tracks(1).Data.cellData
TA.Tracks(1).Data.nn

getTrack(TA, 1)

TA = updateTrack(TA, 1, 1, newdata);

TA.Tracks(1).Data.cellData
TA.Tracks(1).Data.nn

getTrack(TA, 1)