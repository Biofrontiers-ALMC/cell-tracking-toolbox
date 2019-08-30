classdef test_LAPLinker < matlab.unittest.TestCase
    
    
        methods (Test)
            
            function newTrack_addnew(TestObj)
                
                %Create some test data
                testData.Area = 100;
                testData(2).Area = 100;
                
                testData(1).MajorAxisLength = 10;
                testData(2).MajorAxisLength = 20;
                
                L = LAPLinker;
                L = newTrack(L, 3, testData);
            
                TestObj.assertEqual(L.NumTracks, 2);
                TestObj.assertEqual(L.tracks(1).Area, {testData(1).Area});
                TestObj.assertEqual(L.tracks(1).Frame, 3);
                TestObj.assertEqual(L.tracks(2).MajorAxisLength, ...
                    {testData(2).MajorAxisLength});
                
            end
            
            function assignToTrack_link(TestObj)
                
                %Create some test data
                testData.Centroid = [1 1];
                testData(2).Centroid = [10 10];
                
                newData.Centroid = [10, 10.2];
                newData(2).Centroid = [1.1, 1];
                
                L = LAPLinker;
                L = assignToTrack(L, 1, testData);
                
                L = assignToTrack(L, 2, newData);
                
                TestObj.assertEqual(L.NumTracks, 2);
                TestObj.assertEqual(L.tracks(1).Centroid, ...
                    {testData(1).Centroid, newData(2).Centroid});
                TestObj.assertEqual(L.tracks(2).Centroid, ...
                    {testData(2).Centroid, newData(1).Centroid});
            end
            
            function assignToTrack_withAgingTracks(TestObj)
                
                %Create some test data
                testData.Centroid = [1 1];
                testData(2).Centroid = [10 10];
                
                intData.Centroid = [10, 10.2];
                
                newData.Centroid = [1, 1.2];
                newData(2).Centroid = [10, 10.2];
                
                
                L = LAPLinker;
                L.MaxTrackAge = 2;
                
                L = assignToTrack(L, 1, testData);
                L = assignToTrack(L, 2, intData);
                L = assignToTrack(L, 3, intData);
                L = assignToTrack(L, 4, intData);
                L = assignToTrack(L, 5, newData);
                
                TestObj.assertEqual(L.NumTracks, 3);
                
                TestObj.assertEqual(L.tracks(1).Centroid, ...
                    {testData(1).Centroid});
                
                TestObj.assertEqual(L.tracks(2).Centroid, ...
                    {testData(2).Centroid, intData.Centroid, intData.Centroid, intData.Centroid, newData(2).Centroid});
                
                TestObj.assertEqual(L.tracks(3).Centroid, ...
                    {newData(1).Centroid});
                
            end
            
            function splitTrack(TestObj)
                
                %Create some test data
                L = LAPLinker;
                L.MaxTrackAge = 2;
                
                centroids = rand(10, 2);
                               
                for iT = 1:size(centroids, 1)
                    L = assignToTrack(L, iT, struct('Centroid', centroids(iT, :)));                    
                end
                
                [L, newTrack] = splitTrack(L, 1, 5);
                
                TestObj.assertEqual(L.NumTracks, 2);
                TestObj.assertEqual(newTrack, 2);
                
                TestObj.assertEqual(L.tracks(1).Centroid, ...
                    (mat2cell(centroids(1:4, :), ones(1, 4), 2))');
                TestObj.assertEqual(L.tracks(1).Frame, ...
                    1:4);
                
                TestObj.assertEqual(L.tracks(2).Centroid, ...
                    (mat2cell(centroids(5:end, :), ones(1, 6), 2))');
                TestObj.assertEqual(L.tracks(2).Frame, ...
                    5:10);

            end
            
            function assignToTrack_division(TestObj)
                
                %Create some test data
                L = LAPLinker;
                L.MaxTrackAge = 2;
                L.TrackDivision = true;
                
                L = assignToTrack(L, 1, struct('Centroid', [0, 0]));
                
                data.Centroid = [0.5, 0.5];
                data(2).Centroid = [-0.5, 0.5];
                L = assignToTrack(L, 2, data);
                
                data2.Centroid = [0.8, 0.8];
                data2(2).Centroid = [-0.8, 0.5];
                L = assignToTrack(L, 3, data2);

                TestObj.assertEqual(L.NumTracks, 3);
                                
                TestObj.assertEqual(L.tracks(1).Centroid, ...
                    {[0, 0]});
                TestObj.assertEqual(L.tracks(1).Frame, 1);
                
                TestObj.assertEqual(L.tracks(2).Centroid, ...
                    {[0.5, 0.5], [0.8, 0.8]});
                TestObj.assertEqual(L.tracks(2).Frame, [2, 3]);
                
                TestObj.assertEqual(L.tracks(3).Centroid, ...
                    {[-0.5, 0.5], [-0.8, 0.5]});
                TestObj.assertEqual(L.tracks(3).Frame, [2, 3]);
                
            end
            
            function updateTrack_insertPre(TestObj)
                
                L = LAPLinker;
                L = assignToTrack(L, 5, struct('Centroid', [1, 1]));
                                
                L = updateTrack(L, 1, 2, struct('Centroid', [0, 1]));
                
                TestObj.assertEqual(L.tracks(1).Frame, 2:5);
                TestObj.assertEqual(L.tracks(1).Centroid, ...
                    {[0, 1], [], [], [1, 1]});
                
            end
            
            function updateTrack_insertPost(TestObj)
                
                L = LAPLinker;
                L = assignToTrack(L, 5, struct('Centroid', [1, 1]));
                
                L = updateTrack(L, 1, 8, struct('Centroid', [0, 1]));
                
                TestObj.assertEqual(L.tracks(1).Frame, 5:8);
                TestObj.assertEqual(L.tracks(1).Centroid, ...
                    {[1, 1], [], [], [0, 1]});
                
            end
            
            function updateTrack_existing(TestObj)
                
                L = LAPLinker;
                L = assignToTrack(L, 5, struct('Centroid', [1, 1]));
                
                L = updateTrack(L, 1, 5, struct('Centroid', [0, 1]));
                
                TestObj.assertEqual(L.tracks(1).Frame, 5);
                TestObj.assertEqual(L.tracks(1).Centroid, ...
                    {[0, 1]});
                
            end
            
            function updateTrack_insertMultPre(TestObj)
                
                L = LAPLinker;
                L = assignToTrack(L, 8, struct('Centroid', [1, 1]));
                
                L = updateTrack(L, 1, 3, struct('Centroid', [0, 1]));
                L = updateTrack(L, 1, 1, struct('Centroid', [1, 0]));
                
                TestObj.assertEqual(L.tracks(1).Frame, 1:8);
                TestObj.assertEqual(L.tracks(1).Centroid, ...
                    {[1, 0], [], [0, 1], [], [], [], [], [1, 1]});
                
            end
            
            function updateTrack_insertMultPost(TestObj)
                
                L = LAPLinker;
                L = assignToTrack(L, 1, struct('Centroid', [1, 1]));
                
                L = updateTrack(L, 1, 3, struct('Centroid', [0, 1]));
                L = updateTrack(L, 1, 8, struct('Centroid', [1, 0]));
                
                TestObj.assertEqual(L.tracks(1).Frame, 1:8);
                TestObj.assertEqual(L.tracks(1).Centroid, ...
                    {[1, 1], [], [0, 1], [], [], [], [], [1, 0]});
                
            end
            
            function updateTrack_existingMult(TestObj)
                
                L = LAPLinker;
                L = assignToTrack(L, 5, struct('Centroid', [1, 1]));
                L = updateTrack(L, 1, 6, struct('Centroid', [1, 1]));
                L = updateTrack(L, 1, 7, struct('Centroid', [1, 1]));
                L = updateTrack(L, 1, 8, struct('Centroid', [1, 1]));
                
                updatedData.Centroid = [10, 10];
                updatedData(2).Centroid = [11, 10];
                updatedData(3).Centroid = [12, 10];
                
                L = updateTrack(L, 1, [6, 7, 5], updatedData);
                
                TestObj.assertEqual(L.tracks(1).Frame, 5:8);
                TestObj.assertEqual(L.tracks(1).Centroid, ...
                    {[12, 10], [10, 10], [11, 10], [1, 1]});
                
            end
            
            function updateTrack_multiOperation(TestObj)
                
                L = LAPLinker;
                L = assignToTrack(L, 5, struct('Centroid', [1, 1]));
                
                updatedData.Centroid = [10, 10];
                updatedData(2).Centroid = [11, 10];
                updatedData(3).Centroid = [12, 10];
                
                L = updateTrack(L, 1, [3, 8, 5], updatedData);
                
                TestObj.assertEqual(L.tracks(1).Frame, 3:8);
                TestObj.assertEqual(L.tracks(1).Centroid, ...
                    {[10, 10], [], [12, 10], [] [], [11, 10]});
                
            end
            
            function assignToTrack_UnknownSolver_error(TestObj)
                
                L = LAPLinker;
                L.Solver = 'NotASolver';
                L = assignToTrack(L, 1, struct('Centroid', [1, 1]));
                updatedData.Centroid = [10, 10];
                
                TestObj.verifyError(@() assignToTrack(L, 2, updatedData), ...
                    'LAPLinker:assignToTrack:UnknownSolver');
                
            end
        end
        
        
end