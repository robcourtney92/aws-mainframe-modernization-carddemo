# CardDemo Conversion Test Specifications

Test specifications for validating Java-converted modules against original COBOL behavior.
Each test is derived directly from the COBOL source logic and copybook data structures.

These tests assume the converted Java application uses:
- **Spring Boot** with JPA/JDBC for data access
- **PostgreSQL** as the target database (replacing VSAM)
- **JUnit 5** as the test framework
- **BigDecimal** for all financial calculations

---

## Table of Contents

1. [Online Module Tests](#1-online-module-tests)
   - [1.1 Sign-On (COSGN00C)](#11-sign-on-cosgn00c)
   - [1.2 Account View (COACTVWC)](#12-account-view-coactvwc)
   - [1.3 Account Update (COACTUPC)](#13-account-update-coactupc)
   - [1.4 Card Update (COCRDUPC)](#14-card-update-cocrdupc)
   - [1.5 Transaction List (COTRN00C)](#15-transaction-list-cotrn00c)
2. [Batch Module Tests](#2-batch-module-tests)
   - [2.1 Post Transactions (CBTRN02C)](#21-post-transactions-cbtrn02c)
   - [2.2 Interest Calculator (CBACT04C)](#22-interest-calculator-cbact04c)
   - [2.3 Statement Generation (CBSTM03A)](#23-statement-generation-cbstm03a)
3. [Data Migration Validation Tests](#3-data-migration-validation-tests)
   - [3.1 Account Record (CVACT01Y)](#31-account-record-cvact01y)
   - [3.2 Customer Record (CVCUS01Y)](#32-customer-record-cvcus01y)
   - [3.3 Transaction Record (CVTRA05Y)](#33-transaction-record-cvtra05y)
   - [3.4 Card Cross-Reference (CVACT03Y)](#34-card-cross-reference-cvact03y)
   - [3.5 Transaction Category Balance (CVTRA01Y)](#35-transaction-category-balance-cvtra01y)
   - [3.6 Disclosure Group (CVTRA02Y)](#36-disclosure-group-cvtra02y)
   - [3.7 User Security (CSUSR01Y)](#37-user-security-csusr01y)
4. [Cross-Cutting Concern Tests](#4-cross-cutting-concern-tests)
   - [4.1 EBCDIC Sort Order](#41-ebcdic-sort-order)
   - [4.2 Numeric Precision](#42-numeric-precision)
   - [4.3 Timestamp Conversion](#43-timestamp-conversion)
5. [End-to-End Scenario Tests](#5-end-to-end-scenario-tests)

---

## 1. Online Module Tests

### 1.1 Sign-On (COSGN00C)

**Source**: `app/cbl/COSGN00C.cbl`
**CICS Transaction**: CC00
**VSAM File**: USRSEC (User Security)

#### Test: Successful admin login

```
GIVEN a user security record exists:
  SEC-USR-ID       = "ADMIN001"
  SEC-USR-PWD      = "PASSWORD"
  SEC-USR-TYPE     = "A"
INPUT:
  USERIDI          = "admin001"  (lowercase -- COBOL uppercases via FUNCTION UPPER-CASE)
  PASSWDI          = "password"  (lowercase)
EXPECTED:
  - User ID is uppercased to "ADMIN001" before lookup
  - Password is uppercased to "PASSWORD" before comparison
  - CDEMO-USER-ID   = "ADMIN001"
  - CDEMO-USER-TYPE = "A"
  - Control transfers to COADM01C (admin menu)
  - No error message displayed
```

#### Test: Successful regular user login

```
GIVEN a user security record exists:
  SEC-USR-ID       = "USER0001"
  SEC-USR-PWD      = "PASSWORD"
  SEC-USR-TYPE     = "U"
INPUT:
  USERIDI          = "USER0001"
  PASSWDI          = "PASSWORD"
EXPECTED:
  - CDEMO-USER-TYPE = "U"
  - Control transfers to COMEN01C (user menu), NOT COADM01C
```

#### Test: Wrong password

```
GIVEN a user security record exists:
  SEC-USR-ID       = "ADMIN001"
  SEC-USR-PWD      = "PASSWORD"
INPUT:
  USERIDI          = "ADMIN001"
  PASSWDI          = "WRONGPWD"
EXPECTED:
  - Error message: "Wrong Password. Try again ..."
  - Cursor positioned on password field (PASSWDL = -1)
  - No transfer to admin or user menu
```

#### Test: User not found (RESP code 13)

```
GIVEN no user security record for "UNKNOWN1"
INPUT:
  USERIDI          = "UNKNOWN1"
  PASSWDI          = "PASSWORD"
EXPECTED:
  - Error message: "User not found. Try again ..."
  - Cursor positioned on user ID field (USERIDL = -1)
  - WS-ERR-FLG = "Y"
```

#### Test: Empty user ID

```
INPUT:
  USERIDI          = SPACES
  PASSWDI          = "PASSWORD"
EXPECTED:
  - Error message: "Please enter User ID ..."
  - Cursor positioned on user ID field
  - No VSAM read attempted
```

#### Test: Empty password

```
INPUT:
  USERIDI          = "ADMIN001"
  PASSWDI          = SPACES
EXPECTED:
  - Error message: "Please enter Password ..."
  - Cursor positioned on password field
  - No VSAM read attempted
```

#### Test: PF3 key press (exit)

```
INPUT:
  EIBAID           = DFHPF3
EXPECTED:
  - Message displayed: CCDA-MSG-THANK-YOU
  - CICS RETURN issued (session ends)
```

#### Test: Invalid key press

```
INPUT:
  EIBAID           = DFHPF1 (or any key other than ENTER/PF3)
EXPECTED:
  - Error message: CCDA-MSG-INVALID-KEY
  - WS-ERR-FLG = "Y"
  - Sign-on screen re-displayed
```

---

### 1.2 Account View (COACTVWC)

**Source**: `app/cbl/COACTVWC.cbl`
**CICS Transaction**: CAVW
**VSAM Files**: ACCTDAT, CARDDAT, CARDAIX, CXACAIX, CUSTDAT

#### Test: View account by account number

```
GIVEN account record exists:
  ACCT-ID              = 00000000011
  ACCT-ACTIVE-STATUS   = "Y"
  ACCT-CURR-BAL        = 1500.75
  ACCT-CREDIT-LIMIT    = 5000.00
AND card xref record exists linking to this account
AND customer record exists for linked customer
INPUT:
  Account number       = "00000000011"
EXPECTED:
  - Account details displayed on screen
  - Customer name and address populated
  - No error message
  - WS-INFORM-OUTPUT set ("Displaying details of given Account")
```

#### Test: Account number not provided

```
INPUT:
  Account number       = SPACES
EXPECTED:
  - Error message: "Account number not provided"
```

#### Test: Account number is all zeros

```
INPUT:
  Account number       = "00000000000"
EXPECTED:
  - Error message: "Account number must be a non zero 11 digit number"
```

#### Test: Non-numeric account number

```
INPUT:
  Account number       = "ABCDEFGHIJK"
EXPECTED:
  - Error message: "Account number must be a non zero 11 digit number"
```

#### Test: Account not found in card xref

```
GIVEN no card xref record for account 99999999999
INPUT:
  Account number       = "99999999999"
EXPECTED:
  - Error message: "Did not find this account in account card xref file"
```

#### Test: Account not found in account master

```
GIVEN card xref exists but no account master record
INPUT:
  Account number       = "00000000011"
EXPECTED:
  - Error message: "Did not find this account in account master file"
```

#### Test: PF3 returns to calling program or menu

```
GIVEN CDEMO-FROM-PROGRAM = "COMEN01C"
INPUT:
  EIBAID = DFHPF3
EXPECTED:
  - Control transfers back to COMEN01C
  - CDEMO-FROM-TRANID set to "CAVW"
  - CDEMO-FROM-PROGRAM set to "COACTVWC"
```

#### Test: PF3 with no calling program defaults to menu

```
GIVEN CDEMO-FROM-PROGRAM = SPACES
INPUT:
  EIBAID = DFHPF3
EXPECTED:
  - Control transfers to COMEN01C (default menu)
```

---

### 1.3 Account Update (COACTUPC)

**Source**: `app/cbl/COACTUPC.cbl`
**CICS Transaction**: CAUP

#### Test: SSN validation - invalid prefix 000

```
INPUT:
  SSN part1 = "000"
EXPECTED:
  - SSN validation fails (INVALID-SSN-PART1 condition for value 0)
```

#### Test: SSN validation - invalid prefix 666

```
INPUT:
  SSN part1 = "666"
EXPECTED:
  - SSN validation fails (INVALID-SSN-PART1 condition for value 666)
```

#### Test: SSN validation - invalid prefix 900-999

```
INPUT:
  SSN part1 = "950"
EXPECTED:
  - SSN validation fails (INVALID-SSN-PART1 condition for values 900 THRU 999)
```

#### Test: SSN validation - valid SSN

```
INPUT:
  SSN = "123456789"
EXPECTED:
  - SSN validation passes (part1=123 is not 0, 666, or 900-999)
```

#### Test: Account active status must be Y or N

```
INPUT:
  ACCT-ACTIVE-STATUS = "X"
EXPECTED:
  - Validation fails (FLG-ACCT-STATUS-ISVALID only for VALUES 'Y', 'N')
```

#### Test: Phone number format validation

```
INPUT:
  Phone = "(206)555-1234"
  (parsed as: area="206", exchange="555", subscriber="1234")
EXPECTED:
  - Phone validation passes
  - All three segments are numeric
```

#### Test: Date validation - leap year

```
INPUT:
  Date = "2024-02-29"
EXPECTED:
  - Date validation passes (2024 is divisible by 4 -- WS-DIV-BY = 4)
  - Uses COMP-3 WS-REMAINDER to check divisibility
```

---

### 1.4 Card Update (COCRDUPC)

**Source**: `app/cbl/COCRDUPC.cbl`
**CICS Transaction**: CCUP
**VSAM Files**: CARDDAT, CARDAIX

#### Test: Valid card update

```
GIVEN card record exists:
  CARD-NUM             = "4111111111111111"
  CARD-ACCT-ID         = 00000000011
  CARD-CVV-CD          = 123
  CARD-NAME            = "JOHN DOE"
  CARD-STATUS          = "Y"
  CARD-EXPIRY-YEAR     = "2027"
  CARD-EXPIRY-MONTH    = "12"
INPUT:
  New card name        = "JANE DOE"
  New status           = "Y"
  New expiry month     = "06"
  New expiry year      = "2028"
EXPECTED:
  - Card record updated with new values
  - Message: "Changes committed to database"
```

#### Test: Card name must be alphabetic

```
INPUT:
  Card name            = "JOHN123"
EXPECTED:
  - Error: "Card name can only contain alphabets and spaces"
  - Uses INSPECT with LIT-ALL-ALPHA-FROM to verify alpha-only
```

#### Test: Card active status must be Y or N

```
INPUT:
  Card status          = "X"
EXPECTED:
  - Error: "Card Active Status must be Y or N"
  - FLG-YES-NO-VALID condition checks VALUES 'Y', 'N'
```

#### Test: Expiry month validation

```
INPUT:
  Expiry month         = "13"
EXPECTED:
  - Error: "Card expiry month must be between 1 and 12"
  - VALID-MONTH condition checks VALUES 1 THRU 12
```

#### Test: Expiry year validation

```
INPUT:
  Expiry year          = "1800"
EXPECTED:
  - Error: "Invalid card expiry year"
  - VALID-YEAR condition checks VALUES 1950 THRU 2099
```

#### Test: No changes detected

```
GIVEN existing card data displayed
INPUT:
  All fields unchanged
EXPECTED:
  - Message: "No change detected with respect to values fetched."
  - No REWRITE issued
```

#### Test: Concurrent modification detection

```
GIVEN card record was changed by another user between read and update
INPUT:
  User submits changes
EXPECTED:
  - Error: "Record changed by some one else. Please review"
  - CCUP-CHANGES-FAILED condition triggered
```

#### Test: F5 required to confirm changes

```
GIVEN user has entered valid changes
INPUT:
  EIBAID = DFHENTER (not F5)
EXPECTED:
  - Message: "Changes validated.Press F5 to save"
  - CCUP-CHANGES-OK-NOT-CONFIRMED state
  - No REWRITE until F5 pressed
```

---

### 1.5 Transaction List (COTRN00C)

**Source**: `app/cbl/COTRN00C.cbl`
**CICS Transaction**: CT00
**VSAM File**: TRANSACT

#### Test: Display first page of transactions

```
GIVEN TRANSACT file contains 25 transaction records
INPUT:
  Initial entry (EIBAID = DFHENTER, no filter)
EXPECTED:
  - First 10 transactions displayed (WS-IDX iterates 1 to 10)
  - Page number = 1
  - NEXT-PAGE-YES flag set (more records available)
  - Transaction amounts formatted as +99999999.99
```

#### Test: Page forward (PF8)

```
GIVEN currently on page 1, 25 total records
INPUT:
  EIBAID = DFHPF8
EXPECTED:
  - Next 10 transactions displayed (records 11-20)
  - Page number = 2
  - NEXT-PAGE-YES still set
```

#### Test: Page backward (PF7)

```
GIVEN currently on page 2
INPUT:
  EIBAID = DFHPF7
EXPECTED:
  - Previous 10 transactions displayed
  - Page number = 1
```

#### Test: Already at top of page

```
GIVEN currently on page 1
INPUT:
  EIBAID = DFHPF7
EXPECTED:
  - Message: "You are already at the top of the page..."
  - Page remains at 1
```

#### Test: Already at bottom of page

```
GIVEN on last page, NEXT-PAGE-NO flag set
INPUT:
  EIBAID = DFHPF8
EXPECTED:
  - Message: "You are already at the bottom of the page..."
```

#### Test: Transaction ID filter must be numeric

```
INPUT:
  TRNIDINI = "ABCDEF1234567890"
EXPECTED:
  - Error: "Tran ID must be Numeric ..."
  - WS-ERR-FLG = "Y"
```

#### Test: Select transaction for detail view

```
INPUT:
  SEL0003I = "S"
  TRNID03I = "0000000000000042"
EXPECTED:
  - CDEMO-CT00-TRN-SEL-FLG = "S"
  - CDEMO-CT00-TRN-SELECTED = "0000000000000042"
  - Control transfers to COTRN01C (transaction detail)
```

#### Test: Invalid selection character

```
INPUT:
  SEL0001I = "X"
  TRNID01I = "0000000000000001"
EXPECTED:
  - Message: "Invalid selection. Valid value is S"
```

---

## 2. Batch Module Tests

### 2.1 Post Transactions (CBTRN02C)

**Source**: `app/cbl/CBTRN02C.cbl`
**JCL Job**: POSTTRAN
**Input Files**: DALYTRAN (daily transactions), XREFFILE, ACCTFILE
**Output Files**: TRANSACT, DALYREJS (rejected transactions), TCATBALF

#### Test: Successfully post a valid transaction

```
GIVEN daily transaction record:
  DALYTRAN-ID              = "2026020800000001"
  DALYTRAN-TYPE-CD         = "01"
  DALYTRAN-CAT-CD          = 5000
  DALYTRAN-SOURCE          = "POS"
  DALYTRAN-DESC            = "GROCERY STORE PURCHASE"
  DALYTRAN-AMT             = +0000000125.50
  DALYTRAN-MERCHANT-ID     = 000123456
  DALYTRAN-MERCHANT-NAME   = "WHOLE FOODS"
  DALYTRAN-MERCHANT-CITY   = "SEATTLE"
  DALYTRAN-MERCHANT-ZIP    = "98101"
  DALYTRAN-CARD-NUM        = "4111111111111111"
  DALYTRAN-ORIG-TS         = "2026-02-08-10.30.00.000000"
AND card xref record exists:
  XREF-CARD-NUM            = "4111111111111111"
  XREF-ACCT-ID             = 00000000011
AND account record exists:
  ACCT-ID                  = 00000000011
  ACCT-CREDIT-LIMIT        = +0000005000.00
  ACCT-CURR-BAL            = +0000001000.00
  ACCT-CURR-CYC-CREDIT     = +0000000500.00
  ACCT-CURR-CYC-DEBIT      = +0000000200.00
  ACCT-EXPIRAION-DATE       = "2027-12-31"

EXPECTED:
  Transaction file write:
    - TRAN-ID through TRAN-CARD-NUM copied from DALYTRAN fields
    - TRAN-PROC-TS = current timestamp in DB2 format (YYYY-MM-DD-HH.MM.SS.mmnnnn)
  Account record update:
    - ACCT-CURR-BAL = 1000.00 + 125.50 = 1125.50
    - ACCT-CURR-CYC-CREDIT = 500.00 + 125.50 = 625.50 (positive amount)
    - ACCT-CURR-CYC-DEBIT unchanged (amount >= 0)
  Transaction category balance:
    - TRAN-CAT-BAL updated: existing balance + 125.50
  Counters:
    - WS-TRANSACTION-COUNT incremented by 1
    - WS-REJECT-COUNT unchanged
    - RETURN-CODE = 0
```

#### Test: Post a negative (refund) transaction

```
GIVEN valid card and account as above
  DALYTRAN-AMT             = -0000000050.00
EXPECTED:
  Account record update:
    - ACCT-CURR-BAL = 1000.00 + (-50.00) = 950.00
    - ACCT-CURR-CYC-CREDIT unchanged (amount < 0)
    - ACCT-CURR-CYC-DEBIT = 200.00 + (-50.00) = 150.00 (note: debit accumulates negatives)
```

#### Test: Reject - invalid card number (validation code 100)

```
GIVEN DALYTRAN-CARD-NUM = "9999999999999999"
AND no card xref record exists for this card number
EXPECTED:
  - WS-VALIDATION-FAIL-REASON = 100
  - WS-VALIDATION-FAIL-REASON-DESC = "INVALID CARD NUMBER FOUND"
  - Record written to DALYREJS file with validation trailer
  - WS-REJECT-COUNT incremented
  - RETURN-CODE = 4 (at end of job, if any rejects exist)
```

#### Test: Reject - account not found (validation code 101)

```
GIVEN card xref exists with XREF-ACCT-ID = 99999999999
AND no account record for account 99999999999
EXPECTED:
  - WS-VALIDATION-FAIL-REASON = 101
  - WS-VALIDATION-FAIL-REASON-DESC = "ACCOUNT RECORD NOT FOUND"
  - Written to rejects file
```

#### Test: Reject - over credit limit (validation code 102)

```
GIVEN account:
  ACCT-CREDIT-LIMIT        = +0000001000.00
  ACCT-CURR-CYC-CREDIT     = +0000000800.00
  ACCT-CURR-CYC-DEBIT      = +0000000100.00
AND transaction:
  DALYTRAN-AMT             = +0000000500.00
VALIDATION LOGIC (from 1500-B-LOOKUP-ACCT):
  WS-TEMP-BAL = ACCT-CURR-CYC-CREDIT - ACCT-CURR-CYC-DEBIT + DALYTRAN-AMT
              = 800.00 - 100.00 + 500.00 = 1200.00
  ACCT-CREDIT-LIMIT (1000.00) < WS-TEMP-BAL (1200.00) => REJECT
EXPECTED:
  - WS-VALIDATION-FAIL-REASON = 102
  - WS-VALIDATION-FAIL-REASON-DESC = "OVERLIMIT TRANSACTION"
```

#### Test: Reject - expired account (validation code 103)

```
GIVEN account:
  ACCT-EXPIRAION-DATE      = "2025-12-31"
AND transaction:
  DALYTRAN-ORIG-TS         = "2026-02-08-10.30.00.000000"
VALIDATION LOGIC:
  ACCT-EXPIRAION-DATE ("2025-12-31") < DALYTRAN-ORIG-TS(1:10) ("2026-02-08") => REJECT
EXPECTED:
  - WS-VALIDATION-FAIL-REASON = 103
  - WS-VALIDATION-FAIL-REASON-DESC = "TRANSACTION RECEIVED AFTER ACCT EXPIRATION"
```

#### Test: Transaction category balance - create new record

```
GIVEN no existing TCATBAL record for key (ACCT-ID=11, TYPE-CD="01", CAT-CD=5000)
EXPECTED:
  - New TRAN-CAT-BAL-RECORD created (WS-CREATE-TRANCAT-REC = 'Y')
  - TRAN-CAT-BAL = DALYTRAN-AMT (initialized then added)
  - Record written via WRITE (not REWRITE)
```

#### Test: Transaction category balance - update existing record

```
GIVEN existing TCATBAL record:
  TRANCAT-ACCT-ID = 00000000011
  TRANCAT-TYPE-CD = "01"
  TRANCAT-CD      = 5000
  TRAN-CAT-BAL    = +0000001000.00
AND DALYTRAN-AMT = +0000000125.50
EXPECTED:
  - TRAN-CAT-BAL = 1000.00 + 125.50 = 1125.50
  - Record updated via REWRITE
```

#### Test: DB2 format timestamp generation

```
GIVEN FUNCTION CURRENT-DATE returns "20260208103000000000000"
  (YYYYMMDDHHMMSSCC...)
EXPECTED DB2-FORMAT-TS:
  "2026-02-08-10.30.00.000000"
  (YYYY-MM-DD-HH.MM.SS.mmnnnn)
```

#### Test: End-of-job return code

```
GIVEN 100 transactions processed, 3 rejected
EXPECTED:
  - DISPLAY: "TRANSACTIONS PROCESSED :000000100"
  - DISPLAY: "TRANSACTIONS REJECTED  :000000003"
  - RETURN-CODE = 4 (because WS-REJECT-COUNT > 0)
```

#### Test: End-of-job return code - no rejects

```
GIVEN 50 transactions processed, 0 rejected
EXPECTED:
  - RETURN-CODE = 0 (default, MOVE 4 not executed)
```

---

### 2.2 Interest Calculator (CBACT04C)

**Source**: `app/cbl/CBACT04C.cbl`
**JCL Job**: INTCALC
**Input Files**: TCATBALF, XREFFILE, ACCTFILE, DISCGRP
**Output File**: TRANSACT
**Parameter**: PARM-DATE (10-character date string)

#### Test: Basic interest calculation

```
GIVEN transaction category balance record:
  TRANCAT-ACCT-ID  = 00000000011
  TRANCAT-TYPE-CD  = "01"
  TRANCAT-CD       = 5000
  TRAN-CAT-BAL     = +0000010000.00
AND disclosure group record:
  DIS-ACCT-GROUP-ID = "GROUP01"
  DIS-TRAN-TYPE-CD  = "01"
  DIS-TRAN-CAT-CD   = 5000
  DIS-INT-RATE      = +0018.00  (18.00% annual rate, PIC S9(04)V99)
AND account record:
  ACCT-GROUP-ID     = "GROUP01"
COMPUTATION (from 1300-COMPUTE-INTEREST):
  WS-MONTHLY-INT = (TRAN-CAT-BAL * DIS-INT-RATE) / 1200
                 = (10000.00 * 18.00) / 1200
                 = 180000.00 / 1200
                 = 150.00
EXPECTED:
  - WS-MONTHLY-INT = 150.00
  - WS-TOTAL-INT accumulated (added to running total for the account)
  - Interest transaction written to TRANSACT file:
    - TRAN-TYPE-CD = "01"
    - TRAN-CAT-CD  = "05" (hardcoded interest category)
    - TRAN-SOURCE  = "System"
    - TRAN-DESC    = "Int. for a/c 00000000011"
    - TRAN-AMT     = 150.00
    - TRAN-CARD-NUM = card number from XREF lookup
```

#### Test: Interest calculation precision - small balance

```
GIVEN:
  TRAN-CAT-BAL = +0000000001.00
  DIS-INT-RATE = +0001.00 (1.00% annual)
COMPUTATION:
  WS-MONTHLY-INT = (1.00 * 1.00) / 1200 = 0.000833...
  PIC S9(09)V99 truncates to 0.00
EXPECTED:
  - WS-MONTHLY-INT = 0.00 (truncated, not rounded -- COBOL COMPUTE truncates by default)
CRITICAL: Java BigDecimal must use RoundingMode.DOWN to match COBOL truncation behavior
```

#### Test: Interest calculation precision - large balance

```
GIVEN:
  TRAN-CAT-BAL = +0999999999.99  (max for PIC S9(09)V99)
  DIS-INT-RATE = +9999.99        (max for PIC S9(04)V99)
COMPUTATION:
  WS-MONTHLY-INT = (999999999.99 * 9999.99) / 1200
                 = 8333249999.16 (overflows PIC S9(09)V99 which maxes at 999999999.99)
EXPECTED:
  - COBOL behavior on overflow: truncation of high-order digits
  - Java must detect and handle this edge case (throw exception or log warning)
```

#### Test: Zero interest rate skips calculation

```
GIVEN:
  DIS-INT-RATE = +0000.00
EXPECTED:
  - 1300-COMPUTE-INTEREST NOT performed (IF DIS-INT-RATE NOT = 0 is false)
  - 1400-COMPUTE-FEES NOT performed
  - No interest transaction written
```

#### Test: Disclosure group not found - fall back to DEFAULT

```
GIVEN:
  ACCT-GROUP-ID = "BADGROUP"
AND no disclosure group record for key (BADGROUP, type, cat)
AND a DEFAULT disclosure group record exists:
  DIS-ACCT-GROUP-ID = "DEFAULT"
  DIS-INT-RATE      = +0012.00
EXPECTED:
  - First READ returns status '23' (record not found)
  - FD-DIS-ACCT-GROUP-ID set to "DEFAULT"
  - 1200-A-GET-DEFAULT-INT-RATE performed
  - Interest calculated using DEFAULT rate (12.00%)
```

#### Test: Account balance update after processing all categories

```
GIVEN account 00000000011 has three TCATBAL records:
  Category 1: interest = 150.00
  Category 2: interest = 75.50
  Category 3: interest = 0.00 (zero rate)
EXPECTED at 1050-UPDATE-ACCOUNT:
  - WS-TOTAL-INT = 150.00 + 75.50 = 225.50
  - ACCT-CURR-BAL = original balance + 225.50
  - ACCT-CURR-CYC-CREDIT reset to 0
  - ACCT-CURR-CYC-DEBIT reset to 0
  - REWRITE issued for account record
```

#### Test: Transaction ID generation

```
GIVEN PARM-DATE = "2026-02-08"
AND WS-TRANID-SUFFIX starts at 000000
EXPECTED for first interest transaction:
  WS-TRANID-SUFFIX = 000001
  TRAN-ID = STRING of PARM-DATE + WS-TRANID-SUFFIX = "2026-02-08000001"
EXPECTED for second:
  TRAN-ID = "2026-02-08000002"
```

#### Test: Fees computation (stub)

```
1400-COMPUTE-FEES currently contains only EXIT (stub).
EXPECTED:
  - No-op in converted code
  - Document that this is a placeholder for future implementation
```

---

### 2.3 Statement Generation (CBSTM03A)

**Source**: `app/cbl/CBSTM03A.CBL`
**JCL Job**: CREASTMT
**Input Files**: TRNXFILE (transactions), XREFFILE, CUSTFILE, ACCTFILE
**Output Files**: STMTFILE (plain text), HTMLFILE (HTML)

#### Test: Statement contains customer info from CUSTFILE

```
GIVEN customer record:
  CUST-FIRST-NAME  = "JOHN"
  CUST-LAST-NAME   = "DOE"
  CUST-ADDR-LINE-1 = "123 MAIN ST"
EXPECTED in plain text statement:
  - ST-NAME contains customer name
  - ST-ADD1 contains address line 1
```

#### Test: Statement contains account summary

```
GIVEN account record:
  ACCT-ID          = 00000000011
  ACCT-CURR-BAL    = 1500.75
  CUST-FICO-CREDIT-SCORE = 750
EXPECTED:
  - ST-ACCT-ID     = "00000000011"
  - ST-CURR-BAL    = formatted 1500.75 (PIC 9(9).99-)
  - ST-FICO-SCORE  = "750"
```

#### Test: Statement lists all transactions for each card

```
GIVEN 2 cards for account, card 1 has 3 transactions, card 2 has 2 transactions
EXPECTED:
  - WS-TRNX-TABLE populated (2D array: 51 cards x 10 transactions per card)
  - 5 transaction lines in statement
  - Total amount computed using COMP-3 WS-TOTAL-AMT (PIC S9(9)V99)
  - ST-TOTAL-TRAMT shows sum of all transaction amounts
```

#### Test: HTML output generated alongside plain text

```
EXPECTED:
  - HTML file opened and written in parallel with STMTFILE
  - Contains proper HTML structure (DOCTYPE, html, head, body, table)
  - Account number in H3 tag
  - Transaction rows in table format
```

#### Test: ALTER statement behavior preserved

```
The program uses ALTER and GO TO for dynamic dispatch:
  ALTER 8100-FILE-OPEN TO PROCEED TO 8100-TRNXFILE-OPEN (when WS-FL-DD = 'TRNXFILE')
  ALTER 8100-FILE-OPEN TO PROCEED TO 8200-XREFFILE-OPEN (when WS-FL-DD = 'XREFFILE')
  etc.
EXPECTED:
  - Converted Java code must preserve the same file-open sequencing logic
  - File operations must occur in the same order as the COBOL ALTER/GO TO chain
  - This is a complex control flow pattern -- verify carefully
```

#### Test: Mainframe control block addressing (PSA/TCB/TIOT)

```
The program reads z/OS control blocks:
  PSA -> TCB -> TIOT (Task I/O Table)
  Extracts: TIOTNJOB (job name), TIOTJSTP (step name), TIOCDDNM (DD names)
EXPECTED:
  - Converted code should log job/step identification info
  - DD name enumeration should be replaced with equivalent configuration listing
  - This is z/OS-specific code that has no direct Java equivalent
```

---

## 3. Data Migration Validation Tests

These tests validate that VSAM records are correctly converted to PostgreSQL rows.
Each test provides the COBOL copybook field, its PIC clause, and the expected PostgreSQL column type.

### 3.1 Account Record (CVACT01Y)

**VSAM Dataset**: ACCTDAT (RECLN 300)
**Target Table**: `accounts`

| COBOL Field | PIC | PostgreSQL Column | Type | Test Value (COBOL) | Expected (PostgreSQL) |
|:------------|:----|:------------------|:-----|:-------------------|:----------------------|
| ACCT-ID | `9(11)` | `acct_id` | `BIGINT` | `00000000011` | `11` |
| ACCT-ACTIVE-STATUS | `X(01)` | `active_status` | `CHAR(1)` | `Y` | `'Y'` |
| ACCT-CURR-BAL | `S9(10)V99` | `curr_bal` | `DECIMAL(12,2)` | `+0000001500.75` | `1500.75` |
| ACCT-CREDIT-LIMIT | `S9(10)V99` | `credit_limit` | `DECIMAL(12,2)` | `+0000005000.00` | `5000.00` |
| ACCT-CASH-CREDIT-LIMIT | `S9(10)V99` | `cash_credit_limit` | `DECIMAL(12,2)` | `+0000001000.00` | `1000.00` |
| ACCT-OPEN-DATE | `X(10)` | `open_date` | `DATE` | `2020-01-15` | `2020-01-15` |
| ACCT-EXPIRAION-DATE | `X(10)` | `expiration_date` | `DATE` | `2027-12-31` | `2027-12-31` |
| ACCT-REISSUE-DATE | `X(10)` | `reissue_date` | `DATE` | `2025-01-15` | `2025-01-15` |
| ACCT-CURR-CYC-CREDIT | `S9(10)V99` | `curr_cyc_credit` | `DECIMAL(12,2)` | `+0000000500.00` | `500.00` |
| ACCT-CURR-CYC-DEBIT | `S9(10)V99` | `curr_cyc_debit` | `DECIMAL(12,2)` | `-0000000200.00` | `-200.00` |
| ACCT-ADDR-ZIP | `X(10)` | `addr_zip` | `VARCHAR(10)` | `98101     ` | `'98101'` (trimmed) |
| ACCT-GROUP-ID | `X(10)` | `group_id` | `VARCHAR(10)` | `GROUP01   ` | `'GROUP01'` (trimmed) |
| FILLER | `X(178)` | N/A | N/A | (dropped) | (not migrated) |

**Signed zoned decimal test**:
```
COBOL S9(10)V99 stores sign in the zone nibble of the last byte.
Positive: zone = 0xC or 0xF
Negative: zone = 0xD

Test: ACCT-CURR-BAL = -0000001500.75
  EBCDIC bytes: ...F1F5F0F0F7D5 (last byte 0xD5 = negative 5)
  Expected PostgreSQL: -1500.75
```

### 3.2 Customer Record (CVCUS01Y)

**VSAM Dataset**: CUSTDAT (RECLN 500)
**Target Table**: `customers`

| COBOL Field | PIC | PostgreSQL Column | Type | Test Value | Expected |
|:------------|:----|:------------------|:-----|:-----------|:---------|
| CUST-ID | `9(09)` | `cust_id` | `BIGINT` | `000000001` | `1` |
| CUST-FIRST-NAME | `X(25)` | `first_name` | `VARCHAR(25)` | `JOHN                     ` | `'JOHN'` |
| CUST-MIDDLE-NAME | `X(25)` | `middle_name` | `VARCHAR(25)` | `Q                        ` | `'Q'` |
| CUST-LAST-NAME | `X(25)` | `last_name` | `VARCHAR(25)` | `DOE                      ` | `'DOE'` |
| CUST-ADDR-LINE-1 | `X(50)` | `addr_line_1` | `VARCHAR(50)` | EBCDIC string | UTF-8 converted |
| CUST-ADDR-STATE-CD | `X(02)` | `addr_state_cd` | `CHAR(2)` | `WA` | `'WA'` |
| CUST-ADDR-COUNTRY-CD | `X(03)` | `addr_country_cd` | `CHAR(3)` | `USA` | `'USA'` |
| CUST-ADDR-ZIP | `X(10)` | `addr_zip` | `VARCHAR(10)` | `98101-0001` | `'98101-0001'` |
| CUST-PHONE-NUM-1 | `X(15)` | `phone_num_1` | `VARCHAR(15)` | `(206)555-1234  ` | `'(206)555-1234'` |
| CUST-SSN | `9(09)` | `ssn` | `VARCHAR(9)` | `123456789` | `'123456789'` (encrypted in prod) |
| CUST-DOB-YYYY-MM-DD | `X(10)` | `dob` | `DATE` | `1985-03-15` | `1985-03-15` |
| CUST-FICO-CREDIT-SCORE | `9(03)` | `fico_score` | `SMALLINT` | `750` | `750` |
| CUST-PRI-CARD-HOLDER-IND | `X(01)` | `primary_cardholder` | `CHAR(1)` | `Y` | `'Y'` |
| FILLER | `X(168)` | N/A | N/A | (dropped) | (not migrated) |

**EBCDIC special character test**:
```
EBCDIC 0x5B = '$' but ASCII 0x5B = '['
Test: Customer name containing special characters must be correctly mapped.
Verify: All 256 EBCDIC code points map correctly to UTF-8 equivalents.
```

### 3.3 Transaction Record (CVTRA05Y)

**VSAM Dataset**: TRANSACT (RECLN 350)
**Target Table**: `transactions`

| COBOL Field | PIC | PostgreSQL Column | Type | Test Value | Expected |
|:------------|:----|:------------------|:-----|:-----------|:---------|
| TRAN-ID | `X(16)` | `tran_id` | `VARCHAR(16)` | `0000000000000042` | `'0000000000000042'` |
| TRAN-TYPE-CD | `X(02)` | `type_cd` | `CHAR(2)` | `01` | `'01'` |
| TRAN-CAT-CD | `9(04)` | `cat_cd` | `SMALLINT` | `5000` | `5000` |
| TRAN-SOURCE | `X(10)` | `source` | `VARCHAR(10)` | `POS       ` | `'POS'` |
| TRAN-DESC | `X(100)` | `description` | `VARCHAR(100)` | `GROCERY PURCHASE...` | trimmed |
| TRAN-AMT | `S9(09)V99` | `amount` | `DECIMAL(11,2)` | `+0000000125.50` | `125.50` |
| TRAN-MERCHANT-ID | `9(09)` | `merchant_id` | `BIGINT` | `000123456` | `123456` |
| TRAN-MERCHANT-NAME | `X(50)` | `merchant_name` | `VARCHAR(50)` | `WHOLE FOODS...` | trimmed |
| TRAN-MERCHANT-CITY | `X(50)` | `merchant_city` | `VARCHAR(50)` | `SEATTLE...` | trimmed |
| TRAN-MERCHANT-ZIP | `X(10)` | `merchant_zip` | `VARCHAR(10)` | `98101     ` | `'98101'` |
| TRAN-CARD-NUM | `X(16)` | `card_num` | `VARCHAR(16)` | `4111111111111111` | `'4111111111111111'` |
| TRAN-ORIG-TS | `X(26)` | `orig_ts` | `TIMESTAMP` | `2026-02-08-10.30.00.000000` | `2026-02-08 10:30:00.000000` |
| TRAN-PROC-TS | `X(26)` | `proc_ts` | `TIMESTAMP` | `2026-02-08-10.35.00.000000` | `2026-02-08 10:35:00.000000` |
| FILLER | `X(20)` | N/A | N/A | (dropped) | (not migrated) |

**Zoned decimal sign test for TRAN-AMT**:
```
TRAN-AMT uses PIC S9(09)V99 (zoned decimal, NOT COMP-3).
The implied decimal point (V99) means the last 2 digits are cents.
In EBCDIC zoned decimal:
  +125.50 stored as: F0F0F0F0F0F0F1F2F5F5C0
  -125.50 stored as: F0F0F0F0F0F0F1F2F5F5D0
  (C = positive sign, D = negative sign in low nibble of last byte)

PostgreSQL DECIMAL(11,2) stores as: 125.50 or -125.50
Verify the sign extraction and decimal point insertion are correct.
```

### 3.4 Card Cross-Reference (CVACT03Y)

**VSAM Dataset**: CARDXREF (RECLN 50)
**Target Table**: `card_xref`

| COBOL Field | PIC | PostgreSQL Column | Type | Test Value | Expected |
|:------------|:----|:------------------|:-----|:-----------|:---------|
| XREF-CARD-NUM | `X(16)` | `card_num` | `VARCHAR(16)` PRIMARY KEY | `4111111111111111` | `'4111111111111111'` |
| XREF-CUST-ID | `9(09)` | `cust_id` | `BIGINT` FK | `000000001` | `1` |
| XREF-ACCT-ID | `9(11)` | `acct_id` | `BIGINT` FK | `00000000011` | `11` |
| FILLER | `X(14)` | N/A | N/A | (dropped) | |

**Alternate Index test**:
```
VSAM CARDXREF has an AIX on XREF-ACCT-ID (used in CBACT04C with KEY IS FD-XREF-ACCT-ID).
PostgreSQL equivalent: CREATE INDEX idx_card_xref_acct_id ON card_xref(acct_id);
Test: Query by acct_id returns same records as VSAM AIX read.
```

### 3.5 Transaction Category Balance (CVTRA01Y)

**VSAM Dataset**: TCATBALF (RECLN 50)
**Target Table**: `tran_cat_balance`

| COBOL Field | PIC | PostgreSQL Column | Type | Test Value | Expected |
|:------------|:----|:------------------|:-----|:-----------|:---------|
| TRANCAT-ACCT-ID | `9(11)` | `acct_id` | `BIGINT` (composite PK) | `00000000011` | `11` |
| TRANCAT-TYPE-CD | `X(02)` | `type_cd` | `CHAR(2)` (composite PK) | `01` | `'01'` |
| TRANCAT-CD | `9(04)` | `cat_cd` | `SMALLINT` (composite PK) | `5000` | `5000` |
| TRAN-CAT-BAL | `S9(09)V99` | `balance` | `DECIMAL(11,2)` | `+0000010000.00` | `10000.00` |
| FILLER | `X(22)` | N/A | N/A | (dropped) | |

### 3.6 Disclosure Group (CVTRA02Y)

**VSAM Dataset**: DISCGRP (RECLN 50)
**Target Table**: `disclosure_groups`

| COBOL Field | PIC | PostgreSQL Column | Type | Test Value | Expected |
|:------------|:----|:------------------|:-----|:-----------|:---------|
| DIS-ACCT-GROUP-ID | `X(10)` | `acct_group_id` | `VARCHAR(10)` (composite PK) | `GROUP01   ` | `'GROUP01'` |
| DIS-TRAN-TYPE-CD | `X(02)` | `tran_type_cd` | `CHAR(2)` (composite PK) | `01` | `'01'` |
| DIS-TRAN-CAT-CD | `9(04)` | `tran_cat_cd` | `SMALLINT` (composite PK) | `5000` | `5000` |
| DIS-INT-RATE | `S9(04)V99` | `int_rate` | `DECIMAL(6,2)` | `+0018.00` | `18.00` |
| FILLER | `X(28)` | N/A | N/A | (dropped) | |

**DEFAULT group test**:
```
CBACT04C falls back to DIS-ACCT-GROUP-ID = "DEFAULT" when group not found.
Verify: DEFAULT disclosure group records exist in migrated data.
Verify: Application code handles the fallback the same way.
```

### 3.7 User Security (CSUSR01Y)

**VSAM Dataset**: USRSEC (RECLN 80)
**Target Table**: `user_security`

| COBOL Field | PIC | PostgreSQL Column | Type | Test Value | Expected |
|:------------|:----|:------------------|:-----|:-----------|:---------|
| SEC-USR-ID | `X(08)` | `user_id` | `VARCHAR(8)` PRIMARY KEY | `ADMIN001` | `'ADMIN001'` |
| SEC-USR-FNAME | `X(20)` | `first_name` | `VARCHAR(20)` | `ADMIN...` | `'ADMIN'` |
| SEC-USR-LNAME | `X(20)` | `last_name` | `VARCHAR(20)` | `USER...` | `'USER'` |
| SEC-USR-PWD | `X(08)` | `password_hash` | `VARCHAR(60)` | `PASSWORD` | bcrypt hash (DO NOT migrate plaintext) |
| SEC-USR-TYPE | `X(01)` | `user_type` | `CHAR(1)` | `A` | `'A'` |
| SEC-USR-FILLER | `X(23)` | N/A | N/A | (dropped) | |

**Security migration test**:
```
CRITICAL: COBOL stores passwords as plaintext PIC X(08).
Converted application MUST:
  1. Hash passwords with bcrypt (or similar) during migration
  2. Implement password comparison against hash, not plaintext
  3. Original COBOL: IF SEC-USR-PWD = WS-USER-PWD
     Converted Java:  passwordEncoder.matches(inputPassword, storedHash)
Verify: Plaintext passwords are NOT present in the PostgreSQL database.
```

---

## 4. Cross-Cutting Concern Tests

### 4.1 EBCDIC Sort Order

VSAM KSDS files are sorted in EBCDIC collation order, which differs from ASCII/UTF-8.

```
EBCDIC order: space < lowercase < uppercase < digits
ASCII order:  space < digits < uppercase < lowercase

Test: Transaction IDs in TRANSACT file
  COBOL STARTBR with key "0000000000000010" then READNEXT
  must return records in the same order as PostgreSQL ORDER BY tran_id ASC.

  Since TRAN-ID is PIC X(16) with numeric content only, EBCDIC and ASCII
  sort orders are identical for digits. This is SAFE.

Test: Customer names with mixed case
  COBOL: "DOE" sorts AFTER "doe" in EBCDIC
  ASCII: "DOE" sorts BEFORE "doe"
  If any BROWSE operations rely on mixed-case sort order, results will differ.
  Verify: All STARTBR/READNEXT sequences produce identical record ordering.
```

### 4.2 Numeric Precision

```
Test: COMPUTE with intermediate overflow
  COBOL COMPUTE truncates to the receiving field's PIC.
  Java BigDecimal preserves full precision unless explicitly scaled.

  Example from CBACT04C:
    COMPUTE WS-MONTHLY-INT = (TRAN-CAT-BAL * DIS-INT-RATE) / 1200
    WS-MONTHLY-INT is PIC S9(09)V99 (max 999999999.99, 2 decimal places)

  Java equivalent must:
    BigDecimal monthlyInt = catBal.multiply(intRate)
        .divide(new BigDecimal("1200"), 2, RoundingMode.DOWN);

  Test cases:
    10000.00 * 18.00 / 1200 = 150.00 (exact)
    10000.00 * 18.50 / 1200 = 154.166... -> COBOL truncates to 154.16
    1.00 * 1.00 / 1200 = 0.000833... -> COBOL truncates to 0.00

  Verify: All financial calculations use RoundingMode.DOWN, not HALF_UP.
```

### 4.3 Timestamp Conversion

```
COBOL Z-GET-DB2-FORMAT-TIMESTAMP generates: YYYY-MM-DD-HH.MM.SS.mm0000
Java equivalent: LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd-HH.mm.ss.SS0000"))

Test cases:
  COBOL: "2026-02-08-10.30.00.120000"
  Java:  "2026-02-08-10.30.00.120000"

  COBOL: "2026-12-31-23.59.59.990000"
  Java:  "2026-12-31-23.59.59.990000"

Note: COBOL uses COB-MIL (2-digit centiseconds) padded with "0000".
Java must truncate milliseconds to centiseconds to match.

When stored in PostgreSQL TIMESTAMP, the DB2 format string must be parsed:
  Input:  "2026-02-08-10.30.00.120000"
  Parsed: 2026-02-08T10:30:00.120000
  Verify: Microsecond precision preserved in PostgreSQL TIMESTAMP(6).
```

---

## 5. End-to-End Scenario Tests

### Scenario 1: Daily Batch Cycle

```
SETUP:
  - 10 account records in ACCTDAT
  - 5 card xref records in CARDXREF
  - 50 daily transaction records in DALYTRAN
    - 45 valid, 5 invalid (2 bad cards, 1 overlimit, 1 expired, 1 bad account)

EXECUTE: CBTRN02C (POSTTRAN equivalent)

VERIFY:
  1. 45 records written to TRANSACT
  2. 5 records written to DALYREJS with correct validation codes (100, 100, 101, 102, 103)
  3. Account balances updated:
     - ACCT-CURR-BAL reflects sum of posted transactions
     - ACCT-CURR-CYC-CREDIT reflects sum of positive transactions
     - ACCT-CURR-CYC-DEBIT reflects sum of negative transactions
  4. TCATBALF records created/updated per transaction category
  5. RETURN-CODE = 4 (rejects exist)
  6. DISPLAY output matches:
     "TRANSACTIONS PROCESSED :000000050"
     "TRANSACTIONS REJECTED  :000000005"
```

### Scenario 2: Monthly Interest Calculation

```
SETUP:
  - 3 accounts with TCATBAL records:
    - Account 1: 2 categories, rates 18% and 24%
    - Account 2: 1 category, rate 12%
    - Account 3: 1 category, rate 0% (no interest)
  - Disclosure group records for each category
  - PARM-DATE = "2026-02-08"

EXECUTE: CBACT04C (INTCALC equivalent)

VERIFY:
  1. Interest transactions written:
     - Account 1: 2 interest transactions
     - Account 2: 1 interest transaction
     - Account 3: 0 interest transactions (rate = 0)
  2. Account balances updated:
     - Account 1: ACCT-CURR-BAL += sum of 2 interest amounts
     - Account 2: ACCT-CURR-BAL += interest amount
     - Account 3: ACCT-CURR-BAL unchanged
  3. All accounts: ACCT-CURR-CYC-CREDIT = 0, ACCT-CURR-CYC-DEBIT = 0
  4. Transaction IDs follow pattern: "2026-02-08" + sequential suffix
```

### Scenario 3: Full Sign-On to Transaction View

```
STEP 1: Sign-on (COSGN00C equivalent)
  Input: USER0001 / PASSWORD
  Verify: Redirected to user menu (COMEN01C)

STEP 2: Navigate to transaction list (COTRN00C equivalent)
  Verify: First page of 10 transactions displayed
  Verify: Page number = 1

STEP 3: Page forward
  Verify: Next 10 transactions displayed
  Verify: Page number = 2

STEP 4: Select transaction for detail
  Input: Select row 3
  Verify: Transaction detail screen displayed (COTRN01C)
  Verify: All fields match the transaction record

STEP 5: Return to menu
  Input: PF3
  Verify: Returned to calling screen
```

### Scenario 4: Parallel Run Comparison

```
PURPOSE: Run both COBOL (on mainframe) and Java (on AWS) with identical inputs,
         compare outputs byte-for-byte.

INPUTS (identical for both systems):
  - DALYTRAN file with 1000 transactions
  - Same ACCTDAT, CARDXREF, CUSTDAT, DISCGRP, TCATBALF initial state

EXECUTE:
  - COBOL CBTRN02C on mainframe
  - Java PostTransactionService on AWS

COMPARE:
  - Transaction records: field-by-field comparison (excluding TRAN-PROC-TS which uses current time)
  - Reject records: same validation codes for same transactions
  - Account balances: exact match to 2 decimal places
  - Transaction category balances: exact match
  - Return code: same value

TOLERANCE:
  - TRAN-PROC-TS may differ (runtime timestamp)
  - All financial amounts must match exactly (0.00 tolerance)
```

---

## Appendix: Test Data Templates

### Minimal VSAM Dataset for Testing

```sql
-- Accounts
INSERT INTO accounts (acct_id, active_status, curr_bal, credit_limit, cash_credit_limit,
    open_date, expiration_date, reissue_date, curr_cyc_credit, curr_cyc_debit, addr_zip, group_id)
VALUES
    (11, 'Y', 1500.75, 5000.00, 1000.00, '2020-01-15', '2027-12-31', '2025-01-15', 500.00, -200.00, '98101', 'GROUP01'),
    (22, 'Y', 0.00, 10000.00, 2000.00, '2021-06-01', '2028-06-30', '2026-06-01', 0.00, 0.00, '10001', 'GROUP02'),
    (33, 'N', 25000.00, 25000.00, 5000.00, '2019-03-20', '2025-12-31', '2024-03-20', 1000.00, -500.00, '90210', 'DEFAULT');

-- Customers
INSERT INTO customers (cust_id, first_name, last_name, addr_line_1, addr_state_cd,
    addr_country_cd, addr_zip, phone_num_1, ssn, dob, fico_score, primary_cardholder)
VALUES
    (1, 'JOHN', 'DOE', '123 MAIN ST', 'WA', 'USA', '98101', '(206)555-1234', '123456789', '1985-03-15', 750, 'Y'),
    (2, 'JANE', 'SMITH', '456 OAK AVE', 'NY', 'USA', '10001', '(212)555-5678', '987654321', '1990-07-22', 800, 'Y');

-- Card Cross-References
INSERT INTO card_xref (card_num, cust_id, acct_id)
VALUES
    ('4111111111111111', 1, 11),
    ('4222222222222222', 1, 11),
    ('5333333333333333', 2, 22);

-- User Security
INSERT INTO user_security (user_id, first_name, last_name, password_hash, user_type)
VALUES
    ('ADMIN001', 'ADMIN', 'USER', '$2a$10$...hashed...', 'A'),
    ('USER0001', 'REGULAR', 'USER', '$2a$10$...hashed...', 'U');

-- Disclosure Groups
INSERT INTO disclosure_groups (acct_group_id, tran_type_cd, tran_cat_cd, int_rate)
VALUES
    ('GROUP01', '01', 5000, 18.00),
    ('GROUP01', '02', 5001, 24.00),
    ('GROUP02', '01', 5000, 12.00),
    ('DEFAULT', '01', 5000, 15.00);
```
