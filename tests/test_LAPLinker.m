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
            
        end
        
        
end