      ******************************************************************
      *Procedure Division Copybook for POPULATE-HEADER-INFO
      ******************************************************************
      *Populates common screen header fields:
      *  - Application title lines
      *  - Transaction name and program name
      *  - Current date (MM/DD/YY) and time (HH:MM:SS)
      *Accompanying Working Storage copybooks: COTTL01Y, CSDAT01Y
      ******************************************************************
      * Usage: COPY CSPHDRPY REPLACING ==:SCRNMAP:== BY ==mapname==.
      *   where mapname is the BMS output map record (e.g. COSGN0AO)
      ******************************************************************

           MOVE FUNCTION CURRENT-DATE  TO WS-CURDATE-DATA

           MOVE CCDA-TITLE01           TO TITLE01O OF :SCRNMAP:
           MOVE CCDA-TITLE02           TO TITLE02O OF :SCRNMAP:
           MOVE WS-TRANID              TO TRNNAMEO OF :SCRNMAP:
           MOVE WS-PGMNAME             TO PGMNAMEO OF :SCRNMAP:

           MOVE WS-CURDATE-MONTH       TO WS-CURDATE-MM
           MOVE WS-CURDATE-DAY         TO WS-CURDATE-DD
           MOVE WS-CURDATE-YEAR(3:2)   TO WS-CURDATE-YY

           MOVE WS-CURDATE-MM-DD-YY    TO CURDATEO OF :SCRNMAP:

           MOVE WS-CURTIME-HOURS       TO WS-CURTIME-HH
           MOVE WS-CURTIME-MINUTE      TO WS-CURTIME-MM
           MOVE WS-CURTIME-SECOND      TO WS-CURTIME-SS

           MOVE WS-CURTIME-HH-MM-SS    TO CURTIMEO OF :SCRNMAP:
