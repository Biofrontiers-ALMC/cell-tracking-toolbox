classdef test_TrackLinker < matlab.unittest.TestCase
    
    properties
        
        %Test file
        testFile = 'D:\Jian\Documents\Projects\CameronLab\cyanobacteria-toolbox\data\17_08_30 2% agarose_561\MOVIE_10min_561.nd2';
        
    end
    
    methods (TestClassSetup)
        
        function addTbx(obj)
            %ADDTBX  Add the 'tbx' folder and sub-folders to the path
            
            currPath = path;
            obj.addTeardown(@path,currPath);
            addpath(genpath('../tbx/'));
        end
        
    end
    
    methods (Test)
        
        function assert_class_TrackLinker(obj)
            %Make sure that the object is named correctly
            testObj = TrackLinker;
            obj.assertClass(testObj,'TrackLinker');
            
            %Check that this is the TrackLinker object is from this project
            whichTL = which('TrackLinker.m');
            currFolder = pwd;
            
            obj.assertNotEmpty(strncmp(currFolder, whichTL, length(currFolder)));
            
        end
        
        function verify_computeScore_Euclidean_colvectors(obj)
            %Check that the compute score is giving the right values
            
            testObj = TrackLinker;
            
            AA = [1 4 2 3 4]';
            BB = [1 3 5 3 5]';
            
            testScore = testObj.computeScore(AA,BB,'Euclidean');
            
            expectedResults = zeros(size(AA,1),1);
            for ii = 1:size(AA,1)
                expectedResults(ii) = sqrt((AA(ii) - BB(ii)).^2);
            end
            
            obj.verifyEqual(testScore, expectedResults);
        end
        
        function verify_computeScore_Euclidean_vectors(obj)
            %Check that the euclidean score is correct when given a list of
            %vectors representing xy locations.
            
            testObj = TrackLinker;
            
            %Make sample data representing XY coordinates
            XY1 = rand(10,2);
            XY2 = [5, 2];
            
            expectedScore = zeros(size(XY1,1),1);
            for ii = 1:size(XY1,1)
                expectedScore(ii) = sqrt((XY1(ii,1) - XY2(1)).^2 + (XY1(ii,2) - XY2(2)).^2);
            end
            
            testScore = testObj.computeScore(XY1,XY2,'Euclidean');
            
            obj.verifyEqual(testScore, expectedScore);
            
            
        end
        
        function verify_computeScore_PxIntersectUnique(obj)
            %Check that the compute score is giving the right values
            
            testObj = TrackLinker;
            
            AA = [1 2 3 4 5 6 7 8 9 10];
            BB = [1 2 5 8 100];
            
            testScore = testObj.computeScore(AA,BB,'pxintersectunique');
            
            obj.verifyEqual(testScore, 1/(4/11));
            
        end
        
        function verify_computeScore_PxIntersect(obj)
            %Check that the compute score is giving the right values
            
            testObj = TrackLinker;
            
            AA = [1 2 3 4 5 6 7 8 9 10];
            BB = [1 2 5 8 100];
            
            testScore = testObj.computeScore(AA,BB,'pxintersect');
            
            %Expected score is 1/Jacard similrity index
            expectedScore = 1/(numel(intersect(AA,BB))/numel(union(AA,BB)));
            
            obj.verifyEqual(testScore, expectedScore);
            
        end
        
        function verify_initializeLinkerWithTracks(obj)
            %Try initializing the linker with new tracks
            
            %Create sample track data
            for ii = 1:5
                newTrackData(ii).Area = round(rand(1) * 10);
                newTrackData(ii).Centroid = round(rand(1, 2) * 10);
            end
            
            %Initialize the linker object
            linkerObj = TrackLinker(1, newTrackData);
            
            obj.verifyEqual(numel(linkerObj.TrackArray), 5);
            
        end
        
        function verify_initializeLinkerWithTracks_ParamList(obj)
            %Try initializing the linker with new tracks
            
            %Create sample track data
            newTrackData.Area = rand(5,1);
            newTrackData.Centroid = rand(5,2);
            
            %Initialize the linker object
            linkerObj = TrackLinker(1, 'Area', newTrackData.Area,...
                'Centroid',newTrackData.Centroid);
            
            obj.verifyEqual(numel(linkerObj.TrackArray), 5);
            
            for ii = 1:5
                currTrack = linkerObj.getTrack(ii);
                obj.verifyEqual(currTrack.Data.Area, newTrackData.Area(ii));
                obj.verifyEqual(currTrack.Data.Centroid, newTrackData.Centroid(ii));
            end
            
        end
        
        function verify_stopTrack(obj)
            %Verify that the StopTrack() method works
            
            %Create sample track data
            for ii = 1:5
                newTrackData(ii).Area = round(rand(1) * 10);
                newTrackData(ii).Centroid = round(rand(1, 2) * 10);
            end
            
            %Initialize the linker object
            linkerObj = TrackLinker(1, newTrackData);
            
            obj.assertEqual(numel(linkerObj.TrackArray), 5);
            obj.assertEqual([linkerObj.activeTracks.trackIdx], 1:5);
            
            %Stop tracking track 3
            linkerObj = linkerObj.StopTrack(3);
            
            obj.verifyEqual([linkerObj.activeTracks.trackIdx], [1, 2, 4, 5]);
            
        end
        
        function verify_assignToTrack_Euclidean(obj)
            %Verify that the assignToTrack() method works with ;euclidean'
            %calculation
            
            %Create sample track data
            newTrackData(1).Centroid = [1, 1];
            newTrackData(2).Centroid = [10, 10];
            newTrackData(3).Centroid = [40, 40];
            newTrackData(4).Centroid = [80, 80];
            newTrackData(5).Centroid = [100, 100];
            
            %Initialize the linker object
            linkerObj = TrackLinker(1, newTrackData);
            obj.assertEqual(numel(linkerObj.TrackArray), 5);
            obj.assertEqual([linkerObj.activeTracks.trackIdx], 1:5);
            
            %Make move the tracks slightly.
            for ii = 1:5
                newTrackDataMoved(ii).Centroid = newTrackData(ii).Centroid + rand(1, 2);
            end
            
            %Assign the new detections to track
            linkerObj = linkerObj.assignToTrack(2, newTrackDataMoved);
            
            %Check that the tracks were assigned correctly
            for ii = 1:5
                currTrack = linkerObj.getTrack(ii);
                obj.verifyEqual(cat(1,currTrack.Data.Centroid), [newTrackData(ii).Centroid; newTrackDataMoved(ii).Centroid]);
            end
            
        end
        
        function verify_assignToTrack_PxIntersect(obj)
            %Test linking with an intersect calculation
            
            %Create sample track data
            newTrackData(1).PixelIdxList = [1, 2, 3, 4, 5];
            newTrackData(2).PixelIdxList = [10, 11, 12, 13, 14];
            newTrackData(3).PixelIdxList = [400, 401, 402, 403, 404, 405, 406];
            
            %Initialize the linker object
            linkerObj = TrackLinker(1, newTrackData);
            linkerObj.LinkedBy = 'PixelIdxList';
            linkerObj.LinkCalculation = 'PxIntersect';
            
            obj.assertEqual(numel(linkerObj.TrackArray), 3);
            
            %Make move the tracks slightly.
            newTrackDataMoved(1).PixelIdxList = [2, 3, 4, 5];
            newTrackDataMoved(2).PixelIdxList = [12, 13, 14, 16, 20];
            newTrackDataMoved(3).PixelIdxList = [308, 309, 400, 401, 402];
            
            %Assign the new detections to track
            linkerObj = linkerObj.assignToTrack(2, newTrackDataMoved);
            
            %Check that the tracks were assigned correctly
            for ii = 1:3
                currTrack = linkerObj.getTrack(ii);
                obj.verifyEqual(currTrack.Data(1).PixelIdxList, newTrackData(ii).PixelIdxList);
                obj.verifyEqual(currTrack.Data(2).PixelIdxList, newTrackDataMoved(ii).PixelIdxList);
            end
            
            
        end
        
        function verify_assignToTrack_WithMitosis_PxIntersect(obj)
            %Test linking with an intersect calculation
            
            %Create sample track data
            origMotherTrack.PixelIdxList = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
            randomCell.PixelIdxList = [400, 401, 402, 403, 404, 405, 406];
            
            %Initialize the linker object
            linkerObj = TrackLinker(1, [origMotherTrack; randomCell]);
            linkerObj.LinkedBy = 'PixelIdxList';
            linkerObj.LinkCalculation = 'PxIntersect';
            linkerObj.TrackMitosis = true;
            linkerObj.MitosisParameter = 'PixelIdxList';
            linkerObj.MitosisCalculation = 'pxintersect';
            linkerObj.MitosisScoreRange = [1, 1/0.3];
            
            obj.assertEqual(numel(linkerObj.TrackArray), 2);
            
            %Split the mother track
            newTrackDataMoved(1).PixelIdxList = [1, 2, 3, 4, 5]; %daughter 1
            newTrackDataMoved(2).PixelIdxList = [6, 7, 8, 9];  %daughter 2
            newTrackDataMoved(3).PixelIdxList = [308, 309, 400, 401, 402];  %the random cell
            
            %Assign the new detections to track
            linkerObj = linkerObj.assignToTrack(2, newTrackDataMoved);
            
            %Check that there are now four tracks (mother, 2 daughters, and
            %the random cell)
            obj.assertEqual(numel(linkerObj.TrackArray), 4);
            
            %Check that the tracks were assigned correctly
            motherTrack = linkerObj.getTrack(1);
            obj.verifyEqual(motherTrack.Data.PixelIdxList, origMotherTrack.PixelIdxList);
            obj.verifyEqual(motherTrack.DaughterIdxs, [3, 4]);
            obj.verifyEqual(motherTrack.FirstFrame, 1);
            obj.verifyEqual(motherTrack.LastFrame, 1);
            
            d1 = linkerObj.getTrack(3);
            obj.verifyEqual(d1.Data.PixelIdxList, newTrackDataMoved(1).PixelIdxList);
            obj.verifyEqual(d1.MotherIdx, 1);
            obj.verifyEqual(d1.FirstFrame, 2);
            obj.verifyEqual(d1.LastFrame, 2);
            
            d2 = linkerObj.getTrack(4);
            obj.verifyEqual(d2.Data.PixelIdxList, newTrackDataMoved(2).PixelIdxList);
            obj.verifyEqual(d2.MotherIdx, 1);
            obj.verifyEqual(d2.FirstFrame, 2);
            obj.verifyEqual(d2.LastFrame, 2);
            
            randoCell = linkerObj.getTrack(2);
            obj.verifyEqual(randoCell.Data(1).PixelIdxList, randomCell.PixelIdxList);
            obj.verifyEqual(randoCell.Data(2).PixelIdxList, newTrackDataMoved(3).PixelIdxList);
            obj.verifyEqual(randoCell.MotherIdx, NaN);
            obj.verifyEqual(randoCell.FirstFrame, 1);
            obj.verifyEqual(randoCell.LastFrame, 2);
        end
        
        function verify_assignToTrack_WithMultipleMitosis_PxIntersect(obj)
            %Test linking with an intersect calculation
            
            %Create sample track data
            origMotherTrack.PixelIdxList = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
            origMotherTrack2.PixelIdxList = 100:110;
            
            %Initialize the linker object
            linkerObj = TrackLinker(1, [origMotherTrack; origMotherTrack2]);
            linkerObj.LinkedBy = 'PixelIdxList';
            linkerObj.LinkCalculation = 'PxIntersect';
            linkerObj.TrackMitosis = true;
            linkerObj.MitosisParameter = 'PixelIdxList';
            linkerObj.MitosisCalculation = 'pxintersect';
            linkerObj.MitosisScoreRange = [1, 1/0.3];
            
            obj.assertEqual(numel(linkerObj.TrackArray), 2);
            
            %Split the mother track
            newTrackDataMoved(1).PixelIdxList = [1, 2, 3, 4, 5]; %daughter 1
            newTrackDataMoved(2).PixelIdxList = [6, 7, 8, 9];  %daughter 2
            
            newTrackDataMoved(3).PixelIdxList = [100, 101, 102, 103];  %daughter 1
            newTrackDataMoved(4).PixelIdxList = [104, 105, 106, 107,108];  %daughter 2
            
            
            %Assign the new detections to track
            linkerObj = linkerObj.assignToTrack(2, newTrackDataMoved);
            
            %Check that there are now six tracks (4 daughters, and
            %2 mothers)
            obj.assertEqual(numel(linkerObj.TrackArray), 6);
            
            %Check that the tracks were assigned correctly
            motherTrack = linkerObj.getTrack(1);
            obj.verifyEqual(motherTrack.Data.PixelIdxList, origMotherTrack.PixelIdxList);
            obj.verifyEqual(motherTrack.DaughterIdxs, [3, 4]);
            obj.verifyEqual(motherTrack.FirstFrame, 1);
            obj.verifyEqual(motherTrack.LastFrame, 1);
            
            d1 = linkerObj.getTrack(3);
            obj.verifyEqual(d1.Data.PixelIdxList, newTrackDataMoved(1).PixelIdxList);
            obj.verifyEqual(d1.MotherIdx, 1);
            obj.verifyEqual(d1.FirstFrame, 2);
            obj.verifyEqual(d1.LastFrame, 2);
            
            d2 = linkerObj.getTrack(4);
            obj.verifyEqual(d2.Data.PixelIdxList, newTrackDataMoved(2).PixelIdxList);
            obj.verifyEqual(d2.MotherIdx, 1);
            obj.verifyEqual(d2.FirstFrame, 2);
            obj.verifyEqual(d2.LastFrame, 2);
            
            %--- Mother 2 (should be sufficient to test the track idxs---%
            motherTrack = linkerObj.getTrack(2);
            obj.verifyEqual(motherTrack.DaughterIdxs, [5, 6]);
            
            d1 = linkerObj.getTrack(5);
            obj.verifyEqual(d1.Data.PixelIdxList, newTrackDataMoved(3).PixelIdxList);
            obj.verifyEqual(d1.MotherIdx, 2);
            
            d2 = linkerObj.getTrack(6);
            obj.verifyEqual(d2.Data.PixelIdxList, newTrackDataMoved(4).PixelIdxList);
            obj.verifyEqual(d2.MotherIdx, 2);
            
        end
        
        function verify_import_exportSettings(obj)
            %Verify that import and export works
            
            %Create a TrackLinker object and change some of the properties
            linkerObj1 = TrackLinker;
            linkerObj1.LinkedBy = 'PixelValues';
            linkerObj1.LinkCalculation = 'PxIntersect';
            linkerObj1.LAPSolver = 'munkres';
            
            %Export these settings
            obj.verifyWarningFree(@() linkerObj1.exportOptions('temp_settings.txt'));
            
            %Create a new object
            linkerObjNew = TrackLinker;
            
            %Import the settings
            linkerObjNew = linkerObjNew.importOptions('temp_settings.txt');
            
            %Check that the imported settings match
            linkerProps = properties(linkerObj1);
            for iP = 1:numel(linkerProps)
                obj.verifyEqual(linkerObj1.(linkerProps{iP}), linkerObjNew.(linkerProps{iP}));
            end
            
            %Remove the temp_settings txt file
            delete('temp_settings.txt');
            
        end
        
    end
    
    methods (Test)
        
        function verifyError_MakeCostMatrix(obj)
            
            %Create sample track data
            for ii = 1:5
                newTrackData(ii).Area = round(rand(1) * 10);
                newTrackData(ii).Centroid = round(rand(1, 2) * 10);
            end
            
            %Initialize the linker object
            linkerObj = TrackLinker(1, newTrackData);
            linkerObj.LinkedBy = 'NotAProperty';
            
            obj.verifyError(@() linkerObj.assignToTrack(2, newTrackData),...
                'TrackLinker:MakeCostMatrix:NewDataMissingLinkField');
            
        end
        
    end
    
end