classdef trackmetadataTests < matlab.unittest.TestCase
    
   methods (Test)
       
       function set_setFilename_filenameSet(TestObj)
           
           MD = timedata.trackmetadata;
           MD = set(MD, 'filename', 'new filename');
           TestObj.assertMatches(MD.filename, 'new filename');
           
       end
       
       function set_setUserData_userdataFieldCreated(TestObj)
           
           MD = timedata.trackmetadata;
           
           MD = set(MD, 'WellLocation', 'A01');
           
           TestObj.assertMatches(MD.userdata.welllocation, 'A01');
           
       end
       
       function set_userFieldInvalidChars_ExceptionThrown(TestObj)
           
           MD = timedata.trackmetadata;
           TestObj.assertError(@() set(MD, 'Well Location', 'A01'),'trackmetadata:InvalidFieldName');
           
       end
       
       
       function get_getFilename_retrieveFilename(TestObj)
           
           MD = timedata.trackmetadata;
           MD = set(MD, 'filename', 'new filename');
           
           TestObj.assertMatches(get(MD, 'filename'), 'new filename');
           
       end
       
       function get_getUserData_retrieveData(TestObj)
           
           MD = timedata.trackmetadata;
           
           MD = set(MD, 'WellLocation', 'A01');
           
           TestObj.assertMatches(get(MD, 'WellLocation'), 'A01');
           
       end
       
       
       function set_setMultipleFields(TestObj)
           
           MD = timedata.trackmetadata;
           
           MD = set(MD, 'filename', 'New filename', 'WellLocation', 'A01', ...
               'pixelsize', 0.52);
           
           TestObj.assertMatches(MD.filename, 'New filename');
           TestObj.assertMatches(get(MD,'WellLocation'), 'A01');
           TestObj.assertEqual(get(MD, 'pixelsize'), 0.52);
           
       end
       
   end
    
    
    
end