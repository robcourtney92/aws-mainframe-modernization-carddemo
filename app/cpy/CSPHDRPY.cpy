      ******************************************************************
      * Copybook    : CSPHDRPY
      * Application : CardDemo
      * Type        : Procedure Division Copybook
      * Function    : Common POPULATE-HEADER-INFO logic
      ******************************************************************
      * Copyright Amazon.com, Inc. or its affiliates.
      * All Rights Reserved.
      *
      * Licensed under the Apache License, Version 2.0 (the "License").
      * You may not use this file except in compliance with the License.
      * You may obtain a copy of the License at
      *
      *    http://www.apache.org/licenses/LICENSE-2.0
      *
      * Unless required by applicable law or agreed to in writing,
      * software distributed under the License is distributed on an
      * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
      * either express or implied. See the License for the specific
      * language governing permissions and limitations under the License
      ******************************************************************
      * This copybook contains the common header population logic
      * shared across all CICS online programs. It retrieves the
      * current date/time and populates screen header fields.
      *
      * Prerequisites (Working-Storage copybooks):
      *   - COPY COTTL01Y (for CCDA-TITLE01, CCDA-TITLE02)
      *   - COPY CSDAT01Y (for WS-CURDATE-DATA and related fields)
      *
      * Usage:
      *   POPULATE-HEADER-INFO.
      *       COPY CSPHDRPY REPLACING
      *           ==:CDEMO-MAPNAME:== BY ==<map-output-name>==
      *           ==:CDEMO-TRANID:==  BY ==<tranid-variable>==
      *           ==:CDEMO-PGMNAME:== BY ==<pgmname-variable>==.
      *
      * Replacement Tokens:
      *   :CDEMO-MAPNAME: - BMS map output structure name
      *                     (e.g., COSGN0AO, COMEN1AO)
      *   :CDEMO-TRANID:  - Transaction ID variable
      *                     (e.g., WS-TRANID)
      *   :CDEMO-PGMNAME: - Program name variable
      *                     (e.g., WS-PGMNAME)
      ******************************************************************

           MOVE FUNCTION CURRENT-DATE  TO WS-CURDATE-DATA

           MOVE CCDA-TITLE01           TO TITLE01O OF :CDEMO-MAPNAME:
           MOVE CCDA-TITLE02           TO TITLE02O OF :CDEMO-MAPNAME:
           MOVE :CDEMO-TRANID:         TO TRNNAMEO OF :CDEMO-MAPNAME:
           MOVE :CDEMO-PGMNAME:        TO PGMNAMEO OF :CDEMO-MAPNAME:

           MOVE WS-CURDATE-MONTH       TO WS-CURDATE-MM
           MOVE WS-CURDATE-DAY         TO WS-CURDATE-DD
           MOVE WS-CURDATE-YEAR(3:2)   TO WS-CURDATE-YY

           MOVE WS-CURDATE-MM-DD-YY    TO CURDATEO OF :CDEMO-MAPNAME:

           MOVE WS-CURTIME-HOURS       TO WS-CURTIME-HH
           MOVE WS-CURTIME-MINUTE      TO WS-CURTIME-MM
           MOVE WS-CURTIME-SECOND      TO WS-CURTIME-SS

           MOVE WS-CURTIME-HH-MM-SS    TO CURTIMEO OF :CDEMO-MAPNAME:.
