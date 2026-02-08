# CardDemo Mainframe Modernization Strategy

## Executive Summary

This document presents a comprehensive modernization strategy for the CardDemo mainframe credit card management application. CardDemo is built on traditional mainframe technologies (COBOL, CICS, VSAM, JCL, RACF) and serves as a representative example of enterprise mainframe workloads that organizations seek to modernize to reduce costs, improve agility, and address the declining mainframe talent pool.

The recommended approach is a **phased modernization** that begins with an AWS-powered **replatform** to quickly reduce mainframe dependency, followed by an **automated refactor** using AWS Transform to convert COBOL to Java, and concludes with a **reimagine** phase to adopt cloud-native architectures for strategic components.

---

## Table of Contents

- [1. Current State Assessment](#1-current-state-assessment)
  - [1.1 Application Architecture](#11-application-architecture)
  - [1.2 Component Inventory](#12-component-inventory)
  - [1.3 Data Architecture](#13-data-architecture)
  - [1.4 Batch Processing Landscape](#14-batch-processing-landscape)
  - [1.5 Key Modernization Drivers](#15-key-modernization-drivers)
- [2. Modernization Approaches Overview](#2-modernization-approaches-overview)
  - [2.1 The 8 Rs Framework](#21-the-8-rs-framework)
  - [2.2 Approach Comparison Matrix](#22-approach-comparison-matrix)
- [3. AWS Mainframe Modernization Services](#3-aws-mainframe-modernization-services)
  - [3.1 AWS Transform for Mainframe](#31-aws-transform-for-mainframe)
  - [3.2 AWS Mainframe Modernization Service](#32-aws-mainframe-modernization-service)
  - [3.3 Data Migration Tools](#33-data-migration-tools)
  - [3.4 Supporting AWS Services](#34-supporting-aws-services)
- [4. Migration Strategy Analysis for CardDemo](#4-migration-strategy-analysis-for-carddemo)
  - [4.1 Replatform Path](#41-replatform-path)
  - [4.2 Automated Refactor Path](#42-automated-refactor-path)
  - [4.3 Reimagine Path](#43-reimagine-path)
  - [4.4 Strategy Recommendation](#44-strategy-recommendation)
- [5. Recommended Phased Implementation Plan](#5-recommended-phased-implementation-plan)
  - [Phase 0: Discovery and Assessment](#phase-0-discovery-and-assessment-weeks-1-6)
  - [Phase 1: Replatform to AWS](#phase-1-replatform-to-aws-weeks-7-18)
  - [Phase 2: Automated Refactor (COBOL to Java)](#phase-2-automated-refactor-cobol-to-java-weeks-19-36)
  - [Phase 3: Cloud-Native Reimagine](#phase-3-cloud-native-reimagine-weeks-37-52)
  - [Phase 4: Optimization and Decommission](#phase-4-optimization-and-decommission-weeks-53-60)
- [6. Data Migration Strategy](#6-data-migration-strategy)
- [7. Risk Assessment and Mitigation](#7-risk-assessment-and-mitigation)
- [8. Success Metrics](#8-success-metrics)
- [9. References](#9-references)

---

## 1. Current State Assessment

### 1.1 Application Architecture

CardDemo is a credit card management system built on the IBM z/OS mainframe platform using the following technology stack:

| Layer | Technology | Version/Details |
|:------|:-----------|:----------------|
| **Programming Language** | COBOL | Enterprise COBOL V6.3 (`IGY.SIGYCOMP.V63`) |
| **Transaction Processing** | CICS | Version 5.6 (`CICSTS.V05R06M0`) |
| **Primary Data Store** | VSAM KSDS with AIX | Key-Sequenced Data Sets with Alternate Indexes |
| **Batch Processing** | JCL | Job Control Language with IDCAMS, IEBGENER, SORT utilities |
| **Security** | RACF | Resource Access Control Facility |
| **System Utilities** | Assembler | MVSWAIT (timer control), COBDATFT (date conversion) |
| **Optional: RDBMS** | Db2 | Transaction type management |
| **Optional: Hierarchical DB** | IMS DB | Customer hierarchy for authorization module |
| **Optional: Messaging** | IBM MQ | Asynchronous authorization processing |

### 1.2 Component Inventory

#### Online Components (CICS Transactions)

The application exposes **20+ CICS transactions** covering:

| Functional Area | Transactions | Programs | Description |
|:----------------|:-------------|:---------|:------------|
| Authentication | CC00 | COSGN00C | User signon/session initialization |
| Navigation | CM00, CA00 | COMEN01C, COADM01C | Main menu, admin menu |
| Account Management | CAVW, CAUP | COACTVWC, COACTUPC | View and update accounts |
| Card Management | CCLI, CCDL, CCUP | COCRDLIC, COCRDSLC, COCRDUPC | List, view, update cards |
| Transaction Processing | CT00, CT01, CT02 | COTRN00C, COTRN01C, COTRN02C | List, view, add transactions |
| Reporting | CR00 | CORPT00C | Transaction reports |
| Bill Payment | CB00 | COBIL00C | Bill payment processing |
| User Admin | CU00-CU03 | COUSR00C-COUSR03C | User CRUD operations |
| Authorization (optional) | CP00, CPVS, CPVD | COPAUA0C, COPAUS0C, COPAUS1C | MQ-based card authorization |

#### Batch Components

**31 COBOL source programs** and **38 JCL jobs** handle:

- **Data Loading**: ACCTFILE, CARDFILE, CUSTFILE, XREFFILE, TRANFILE
- **Transaction Processing**: POSTTRAN (CBTRN02C), COMBTRAN, TRANBKP
- **Financial Calculations**: INTCALC (CBACT04C)
- **Statement Generation**: CREASTMT (CBSTM03A/B) with multi-step SORT and VSAM operations
- **Data Export/Import**: CBEXPORT, CBIMPORT for branch migration
- **File Management**: CLOSEFIL, OPENFIL (CICS file coordination)
- **Scheduling Synchronization**: WAITSTEP (COBSWAIT)

#### Copybooks (Shared Data Structures)

**30 copybooks** define record layouts for all VSAM datasets, BMS maps, and inter-program communication areas.

### 1.3 Data Architecture

The primary data store uses **VSAM KSDS** (Key-Sequenced Data Sets) with the following entities:

| Dataset | Copybook | Key Field | Record Length | Description |
|:--------|:---------|:----------|:-------------|:------------|
| ACCTDATA.VSAM.KSDS | CVACT01Y | ACCT-ID (11 digits) | 300 bytes | Account master |
| CUSTDATA.VSAM.KSDS | CVCUS01Y | CUST-ID (9 digits) | 500 bytes | Customer master |
| CARDDATA.VSAM.KSDS | CVACT02Y | CARD-NUM (16 chars) | 150 bytes | Card master |
| CARDXREF.VSAM.KSDS | CVACT03Y | XREF-CARD-NUM (16 chars) | 50 bytes | Card-Account-Customer cross-reference |
| TRANSACT.VSAM.KSDS | CVTRA05Y | TRAN-ID (16 chars) | 350 bytes | Transaction history |
| USRSEC.VSAM.KSDS | CSUSR01Y | User ID | 80 bytes | User security credentials |
| TRANTYPE.VSAM.KSDS | CVTRA03Y | Type code | 60 bytes | Transaction types |
| TRANCATG.VSAM.KSDS | CVTRA04Y | Category code | 60 bytes | Transaction categories |
| DISCGRP.VSAM.KSDS | CVTRA02Y | Group code | 50 bytes | Disclosure groups |
| TCATBALF.VSAM.KSDS | CVTRA01Y | Category key | 50 bytes | Category balances |
| DALYTRAN.PS | CVTRA06Y | N/A (sequential) | 350 bytes | Daily transaction input |

Additional data features:
- **Alternate Indexes (AIX)**: CARDDATA has an AIX for alternate card number lookup
- **GDG (Generation Data Groups)**: Used for transaction backups (`TRANSACT.BKUP`) and rejected records (`DALYREJS`)
- **EBCDIC Encoding**: All data files use EBCDIC character encoding
- **Packed Decimal (COMP-3)**: Financial amounts use `S9(09)V99 COMP-3` format

### 1.4 Batch Processing Landscape

Batch jobs are orchestrated by **Control-M** and **CA7** schedulers with three processing cadences:

**Daily Cycle** (Control-M folder: `DAILY-TransactionBackup`):
```
CLOSEFIL -> TRANBKP -> WAITSTEP -> OPENFIL
```

**Weekly Cycle** (Control-M folders: `WEEKLY-TransactionTypesDBRefresh`, `WEEKLY-DisclosureGroupsRefresh`):
```
MNTTRDB2 -> CLOSEFIL -> DISCGRP -> WAITSTEP -> TRANEXTR -> OPENFIL
```

**Monthly Cycle** (Control-M folder: `MONTHLY-Statement`):
```
CLOSEFIL -> CREASTMT (SORT -> VSAM LOAD -> CBSTM03A) -> WAITSTEP -> OPENFIL
```

The full batch sequence involves **20+ jobs** that must execute in a specific dependency order, coordinated through CLOSEFIL/OPENFIL pairs to manage CICS file access during batch windows.

### 1.5 Key Modernization Drivers

| Driver | Impact | Urgency |
|:-------|:-------|:--------|
| **Mainframe talent shortage** | COBOL developers are retiring; hiring is increasingly difficult | High |
| **Licensing and infrastructure costs** | Mainframe MIPS-based pricing is expensive and rising | High |
| **Business agility** | Monolithic architecture limits speed of feature delivery | Medium |
| **Integration barriers** | EBCDIC data, 3270 terminals, and proprietary protocols limit API exposure | Medium |
| **Regulatory and compliance** | Modern audit and compliance tools have limited mainframe support | Medium |
| **Cloud-native capabilities** | Cannot leverage auto-scaling, managed services, or AI/ML | Low-Medium |

---

## 2. Modernization Approaches Overview

### 2.1 The 8 Rs Framework

AWS defines eight migration strategies (the "8 Rs") applicable to mainframe modernization:

| Strategy | Description | CardDemo Applicability |
|:---------|:------------|:-----------------------|
| **Retire** | Decommission applications no longer needed | Low - CardDemo is actively used |
| **Retain** | Keep on mainframe, possibly augment | Viable as interim step |
| **Relocate** | Move to cloud mainframe (e.g., IBM LinuxONE) | Limited AWS alignment |
| **Rehost (Lift-and-Shift)** | Move to mainframe emulator on cloud | Not recommended long-term |
| **Replatform** | Run COBOL on managed cloud runtime (Rocket/Micro Focus) | **Strong fit for Phase 1** |
| **Refactor** | Auto-convert COBOL to Java (AWS Blu Age / AWS Transform) | **Strong fit for Phase 2** |
| **Replace** | Swap with commercial off-the-shelf (COTS) package | Possible for some modules |
| **Reimagine** | Rearchitect as cloud-native microservices | **Strong fit for Phase 3** |

### 2.2 Approach Comparison Matrix

| Criteria | Replatform | Refactor | Reimagine | Replace |
|:---------|:-----------|:---------|:----------|:--------|
| **Time to migrate** | 3-6 months | 6-12 months | 12-24 months | 6-18 months |
| **Risk level** | Low | Medium | High | Medium-High |
| **Cost (initial)** | Low-Medium | Medium | High | Medium-High |
| **Cost (ongoing)** | Medium | Low | Low | Variable |
| **Business logic preservation** | Full | Full (automated) | Selective | Vendor-dependent |
| **Talent modernization** | None (still COBOL) | Full (Java) | Full (any language) | Vendor skills |
| **Cloud-native benefits** | Minimal | Moderate | Full | Variable |
| **Mainframe skill dependency** | Yes (runtime) | No | No | No |
| **VSAM/CICS support** | Native | Emulated in Java | Replaced | N/A |
| **Batch job support** | Native JCL | Converted to Java batch | Cloud-native scheduling | Vendor-specific |

---

## 3. AWS Mainframe Modernization Services

### 3.1 AWS Transform for Mainframe

**AWS Transform** (launched May 2025) is the **primary recommended tool** for CardDemo modernization. It is an agentic AI service that automates the full modernization lifecycle:

| Capability | Description | CardDemo Relevance |
|:-----------|:------------|:-------------------|
| **Analyze** | Automated code analysis, dependency mapping, complexity scoring | Maps all 31 COBOL programs and 30 copybooks |
| **Document** | AI-generated business logic documentation, data dictionaries | Extracts rules from CICS programs and batch logic |
| **Decompose** | Identifies bounded contexts and service boundaries | Splits card management, transactions, accounts into domains |
| **Plan & Test** | Migration plan generation, test case creation, test data collection | Generates functional tests for each CICS transaction |
| **Transform** | COBOL-to-Java automated refactoring with business logic preservation | Converts online and batch programs to Spring Boot Java |

**Supported source technologies for CardDemo:**
- COBOL (primary language)
- JCL (batch processing)
- CICS (transaction management)
- BMS (screen definitions)
- VSAM (data storage)
- Db2 (optional module)

**Target output:**
- Java (Spring Boot) applications
- Angular/web front-ends (replacing BMS/3270 screens)
- Groovy-based batch processing
- PostgreSQL/Amazon Aurora (replacing VSAM/Db2)

### 3.2 AWS Mainframe Modernization Service

The AWS Mainframe Modernization (M2) service provides two runtime options:

#### Replatform with Rocket Software (Micro Focus)

| Feature | Details |
|:--------|:--------|
| **Runtime** | Rocket Software (formerly Micro Focus) Enterprise Server |
| **Language** | Keeps COBOL source code as-is |
| **CICS support** | Full CICS emulation |
| **VSAM support** | VSAM file emulation on Linux |
| **JCL support** | JCL execution on cloud runtime |
| **Deployment** | Self-managed on Amazon EC2 |
| **Best for** | Quick migration with minimal code changes |

> **Note**: As of November 2025, the managed runtime environment experience is no longer available to new customers. The self-managed runtime version remains available for both Rocket Software (replatform) and AWS Blu Age (refactor).

#### Refactor with AWS Blu Age

| Feature | Details |
|:--------|:--------|
| **Runtime** | AWS Blu Age Java runtime |
| **Language** | Automated COBOL-to-Java conversion |
| **CICS support** | Converted to Java transaction framework |
| **VSAM support** | Converted to relational database (PostgreSQL/Aurora) |
| **JCL support** | Converted to Java batch framework |
| **Deployment** | Self-managed on Amazon EC2/ECS |
| **Best for** | Full language modernization with automated tooling |

### 3.3 Data Migration Tools

| Tool/Service | Source | Target | Use Case for CardDemo |
|:-------------|:-------|:-------|:----------------------|
| **Precisely Connect** | VSAM, Db2 | Amazon RDS, DynamoDB, MSK, S3 | Migrate VSAM KSDS files with CDC replication |
| **AWS Transfer Family** | Mainframe files (SFTP) | Amazon S3 | Transfer EBCDIC data files to S3 |
| **AWS DMS** | Db2 | Amazon RDS, Aurora | Migrate optional Db2 tables |
| **AWS SCT** | Db2 DDL | PostgreSQL/Aurora DDL | Convert Db2 schemas to cloud database |
| **Custom ETL (AWS Glue)** | EBCDIC flat files | Parquet/relational | Transform EBCDIC-encoded data to modern formats |

### 3.4 Supporting AWS Services

| AWS Service | Role in Modernization |
|:------------|:----------------------|
| **Amazon Aurora PostgreSQL** | Replace VSAM KSDS and Db2 for relational data |
| **Amazon DynamoDB** | Replace VSAM for key-value access patterns (e.g., CARDXREF) |
| **Amazon S3** | Replace GDG datasets for backup/archive storage |
| **Amazon MQ** | Replace IBM MQ for messaging (authorization module) |
| **AWS Step Functions** | Replace Control-M/CA7 for batch job orchestration |
| **Amazon EventBridge** | Event-driven scheduling (replace JCL timer-based jobs) |
| **AWS Lambda** | Serverless execution for lightweight batch operations |
| **Amazon ECS/EKS** | Container-based runtime for refactored Java applications |
| **Amazon API Gateway** | Expose modernized services as REST APIs |
| **Amazon Cognito** | Replace RACF for user authentication and authorization |
| **AWS CloudWatch** | Replace mainframe monitoring (SMF records, SYSLOG) |
| **AWS CodePipeline** | CI/CD pipeline for modernized application deployment |

---

## 4. Migration Strategy Analysis for CardDemo

### 4.1 Replatform Path

**Approach**: Run CardDemo COBOL code on Rocket Software (Micro Focus) Enterprise Server on Amazon EC2.

**Pros:**
- Fastest path off the mainframe (3-6 months)
- Minimal code changes required
- Preserves all existing business logic exactly as-is
- CICS, VSAM, JCL, and BMS all supported natively
- Low risk of functional regression
- Existing mainframe staff can continue maintaining the code

**Cons:**
- Still requires COBOL skills for ongoing maintenance
- Does not address the talent shortage problem long-term
- Limited cloud-native benefits (no auto-scaling, no serverless)
- Rocket Software licensing costs apply
- VSAM file emulation may have performance characteristics different from mainframe
- 3270 terminal interface remains unchanged

**CardDemo-Specific Considerations:**
- The `CLOSEFIL` / `OPENFIL` pattern for batch-online coordination will work natively
- All 20+ batch jobs can run via JCL on the replatform runtime
- The optional Db2 and IMS modules require additional Rocket Software configuration
- Control-M/CA7 scheduler definitions can be migrated to cloud-based Control-M

### 4.2 Automated Refactor Path

**Approach**: Use AWS Transform / AWS Blu Age to automatically convert COBOL to Java.

**Pros:**
- Eliminates COBOL dependency completely
- Java developers are abundant and affordable
- Modernized code can leverage standard Java tooling (IDEs, CI/CD, testing frameworks)
- VSAM converted to relational database (Aurora PostgreSQL)
- BMS screens converted to web-based UI (Angular)
- JCL converted to Java batch framework
- Enables integration with modern APIs and microservices

**Cons:**
- Medium risk: automated conversion may produce non-idiomatic Java code
- Converted code may still reflect mainframe patterns (paragraph-based flow, WORKING-STORAGE)
- Testing effort is significant: every CICS transaction and batch job must be validated
- COMP-3 / packed decimal arithmetic must be validated for precision
- The `CLOSEFIL`/`OPENFIL` batch coordination pattern must be redesigned
- 6-12 months timeline

**CardDemo-Specific Considerations:**
- AWS Transform has been demonstrated specifically with the CardDemo application (see [AWS Prescriptive Guidance](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/modernize-mainframe-app-transform-terraform.html))
- The 31 COBOL programs are well-structured with clear paragraph naming (`1000-INITIALIZE`, `2000-PROCESS-SCREEN`, `3000-FINALIZE`)
- Copybook-based record layouts (CVACT01Y, CVCUS01Y, CVTRA05Y) map cleanly to Java POJOs / JPA entities
- The CICS pseudo-conversational pattern in online programs translates well to stateless REST APIs
- Statement generation (CBSTM03A/B) with SORT + VSAM operations needs careful conversion testing

### 4.3 Reimagine Path

**Approach**: Rearchitect CardDemo as cloud-native microservices using modern languages and patterns.

**Pros:**
- Full cloud-native architecture with auto-scaling, serverless, and event-driven patterns
- Opportunity to improve business processes (e.g., real-time transaction processing instead of batch)
- Complete technology freedom (Java, Python, Node.js, Go)
- Modern database choices optimized per domain (DynamoDB for cards, Aurora for accounts)
- API-first design enables mobile and partner integrations
- DevOps and CI/CD from the ground up

**Cons:**
- Highest risk and cost
- Longest timeline (12-24 months)
- Requires deep understanding of existing business logic
- Risk of introducing functional differences
- Requires modern application architects and developers
- Complete rewrite of all batch processing logic

**CardDemo-Specific Considerations:**
- CardDemo's functional domains (Accounts, Cards, Transactions, Users, Billing) map naturally to microservice boundaries
- The batch POSTTRAN/INTCALC/CREASTMT cycle could be reimagined as event-driven, real-time processing
- The authorization module (MQ-based) could become an event-driven Lambda function
- Statement generation could use serverless PDF generation instead of SORT/VSAM

### 4.4 Strategy Recommendation

**Recommended: Phased Multi-Pattern Approach**

Based on CardDemo's architecture characteristics, we recommend a **disposition strategy** that applies different patterns to different workload components:

| Component | Recommended Pattern | Rationale |
|:----------|:-------------------|:----------|
| Online CICS programs (core) | **Refactor** (AWS Transform) | Well-structured COBOL with clear UI, converts cleanly to Java + Angular |
| Batch processing (POSTTRAN, INTCALC) | **Refactor** then **Reimagine** | Initial auto-conversion, then optimize to event-driven |
| Statement generation (CREASTMT) | **Reimagine** | Complex SORT + multi-file I/O benefits from cloud-native redesign |
| Data export/import (CBEXPORT/CBIMPORT) | **Reimagine** | Replace with modern ETL (AWS Glue) or API-based data exchange |
| VSAM data stores | **Refactor** | Convert to Aurora PostgreSQL via Blu Age data migration |
| Optional Db2 module | **Replatform** data to Aurora | Direct Db2-to-Aurora migration via AWS DMS |
| Optional MQ module | **Replace** with Amazon MQ/SNS | Drop-in replacement for messaging |
| Job scheduling (Control-M/CA7) | **Replace** with AWS Step Functions | Native cloud orchestration |
| Security (RACF) | **Replace** with Amazon Cognito | Modern identity and access management |

---

## 5. Recommended Phased Implementation Plan

### Phase 0: Discovery and Assessment (Weeks 1-6)

**Objective**: Build a complete understanding of the application and validate the modernization strategy.

**Activities:**

1. **Code Analysis with AWS Transform**
   - Upload all 31 COBOL source files and 30 copybooks to Amazon S3
   - Run AWS Transform analysis to generate:
     - Program dependency graphs
     - Data flow diagrams
     - Complexity scores per program
     - Business logic extraction documentation
   - Validate auto-generated documentation against existing README.md

2. **Data Inventory and Mapping**
   - Catalog all 11 VSAM datasets using `LISTCAT.txt` as baseline
   - Map COBOL copybook field definitions to target relational schema
   - Identify EBCDIC-to-UTF-8 conversion requirements
   - Document COMP-3 packed decimal fields requiring precision validation

3. **Batch Job Dependency Mapping**
   - Parse Control-M XML (`CardDemo.controlm`) and CA7 definitions (`CardDemo.ca7`)
   - Map all INCOND/OUTCOND dependencies
   - Document the CLOSEFIL/OPENFIL coordination pattern
   - Identify batch window timing requirements

4. **Test Baseline Creation**
   - Use AWS Transform automated test generation to create:
     - Functional test cases for each of the 20+ CICS transactions
     - Batch job input/output validation scripts
     - Data integrity checks for all VSAM datasets
   - Collect test data from sample EBCDIC files in `app/data/EBCDIC/`

**Deliverables:**
- Application complexity report
- Target architecture design document
- Data migration mapping spreadsheet
- Test plan and baseline test data
- Refined effort estimates for Phases 1-4

### Phase 1: Replatform to AWS (Weeks 7-18)

**Objective**: Move CardDemo off the physical mainframe to AWS, running on Rocket Software (Micro Focus) runtime, to stop mainframe costs immediately.

**Activities:**

1. **Infrastructure Setup**
   - Provision Amazon EC2 instances for Rocket Software Enterprise Server
   - Configure VPC, security groups, and IAM roles
   - Set up Amazon EFS for shared VSAM file storage
   - Install and configure Rocket Software runtime

2. **Application Deployment**
   - Deploy COBOL load modules to Rocket Software runtime
   - Configure CICS region definitions (from `app/csd/` files)
   - Deploy BMS maps for all 20+ screens
   - Configure VSAM file definitions matching `app/catlg/LISTCAT.txt`

3. **Data Migration**
   - Transfer EBCDIC data files from `app/data/EBCDIC/` to Amazon S3
   - Load VSAM datasets using IDCAMS REPRO (emulated)
   - Execute initialization JCL sequence: DUSRSECJ -> CLOSEFIL -> ACCTFILE -> ... -> OPENFIL
   - Validate record counts and data integrity

4. **Batch Job Configuration**
   - Deploy all 38 JCL jobs to the Rocket Software JCL runner
   - Configure AWS Step Functions to replace Control-M/CA7 scheduling
   - Validate the full daily/weekly/monthly batch cycle
   - Test CLOSEFIL/OPENFIL file coordination

5. **Connectivity and Access**
   - Set up 3270 terminal emulator access (e.g., TN3270 via AWS)
   - Configure network connectivity for users
   - Validate CC00 signon with ADMIN001/USER0001 credentials

6. **Validation**
   - Execute all baseline functional tests
   - Run full batch cycle and compare outputs
   - Performance benchmark against mainframe baseline
   - User acceptance testing with 3270 terminal access

**Deliverables:**
- CardDemo running on AWS (Rocket Software runtime)
- Mainframe can be decommissioned or used for fallback
- Batch scheduling operational on AWS Step Functions
- Performance benchmark report

### Phase 2: Automated Refactor (COBOL to Java) (Weeks 19-36)

**Objective**: Convert CardDemo from COBOL to Java using AWS Transform, eliminating the COBOL dependency.

**Activities:**

1. **AWS Transform Refactoring**
   - Configure AWS Transform workspace with CardDemo source code
   - Execute automated COBOL-to-Java transformation:
     - Online COBOL programs -> Spring Boot REST APIs
     - BMS maps -> Angular web components
     - VSAM file operations -> JPA/Hibernate data access
     - JCL batch jobs -> Spring Batch jobs
     - Copybooks -> Java POJOs / JPA entities
   - Review and refine generated Java code

2. **Database Migration**
   - Create Aurora PostgreSQL schema from VSAM copybook definitions:

     | VSAM Dataset | PostgreSQL Table | Key |
     |:-------------|:-----------------|:----|
     | ACCTDATA.VSAM.KSDS | `accounts` | `acct_id` (BIGINT) |
     | CUSTDATA.VSAM.KSDS | `customers` | `cust_id` (BIGINT) |
     | CARDDATA.VSAM.KSDS | `cards` | `card_num` (VARCHAR(16)) |
     | CARDXREF.VSAM.KSDS | `card_xref` | `xref_card_num` (VARCHAR(16)) |
     | TRANSACT.VSAM.KSDS | `transactions` | `tran_id` (VARCHAR(16)) |
     | USRSEC.VSAM.KSDS | `users` | `user_id` (VARCHAR) |
     | DALYTRAN.PS | `daily_transactions` | Auto-generated |

   - Migrate data using Precisely Connect or custom ETL:
     - Convert EBCDIC to UTF-8
     - Unpack COMP-3 fields to DECIMAL
     - Validate record counts and data integrity

3. **UI Modernization**
   - Replace 3270 BMS screens with Angular web application
   - Map each BMS map to a web page:
     - COSGN00 (Signon) -> Login page
     - COMEN01 (Main Menu) -> Dashboard
     - COACTVW/COACTUP (Account) -> Account management pages
     - COCRDLI/COCRDUP (Cards) -> Card management pages
     - COTRN00/01/02 (Transactions) -> Transaction pages
     - COUSR00-03 (Users) -> Admin user management pages

4. **Batch Modernization**
   - Convert JCL jobs to Spring Batch:
     - POSTTRAN -> `PostTransactionJob`
     - INTCALC -> `InterestCalculationJob`
     - CREASTMT -> `StatementGenerationJob`
     - TRANBKP -> `TransactionBackupJob`
   - Replace SORT utility calls with Java stream operations or SQL queries
   - Replace IDCAMS operations with standard database operations
   - Update AWS Step Functions to orchestrate Spring Batch jobs

5. **Security Modernization**
   - Replace RACF with Amazon Cognito:
     - Migrate USRSEC data to Cognito user pool
     - Implement role-based access (Regular User, Admin)
     - Add modern authentication (MFA, SSO)
   - Implement Spring Security for API authorization

6. **Testing**
   - Execute AWS Transform automated test suites
   - Compare COBOL and Java outputs for all CICS transactions
   - Validate batch processing results (POSTTRAN, INTCALC, CREASTMT)
   - Validate COMP-3 decimal precision in financial calculations
   - Performance and load testing
   - User acceptance testing with new web UI

**Deliverables:**
- Java Spring Boot application with Angular front-end
- Aurora PostgreSQL database with migrated data
- Spring Batch jobs replacing all JCL batch processing
- Cognito-based authentication
- CI/CD pipeline (AWS CodePipeline)

### Phase 3: Cloud-Native Reimagine (Weeks 37-52)

**Objective**: Optimize strategic components for cloud-native architecture, unlocking full cloud benefits.

**Activities:**

1. **Microservices Decomposition**
   - Split the monolithic Java application into domain services:

     | Microservice | Source Programs | Target Runtime |
     |:-------------|:----------------|:---------------|
     | Account Service | COACTVWC, COACTUPC, CBACT01-04C | ECS Fargate |
     | Card Service | COCRDLIC, COCRDSLC, COCRDUPC | ECS Fargate |
     | Transaction Service | COTRN00C-02C, CBTRN01-03C | ECS Fargate |
     | Billing Service | COBIL00C | Lambda |
     | User Service | COUSR00C-03C, COSGN00C | Lambda + Cognito |
     | Statement Service | CBSTM03A/B | Lambda + S3 |
     | Authorization Service | COPAUA0C, COPAUS0C/1C | Lambda + EventBridge |

2. **Event-Driven Batch Replacement**
   - Replace daily batch POSTTRAN with real-time transaction processing:
     - Transaction submitted -> EventBridge event -> Lambda processes immediately
     - Eliminates the daily batch window and CLOSEFIL/OPENFIL cycle
   - Replace INTCALC with scheduled Lambda (daily interest accrual)
   - Replace CREASTMT with on-demand statement generation:
     - S3-triggered Lambda generates PDF statements
     - Available via API for customers in real-time

3. **Data Store Optimization**
   - Evaluate per-service database needs:

     | Service | Recommended Store | Rationale |
     |:--------|:------------------|:----------|
     | Account Service | Aurora PostgreSQL | Relational queries, joins with customers |
     | Card Service | DynamoDB | Key-value lookup by card number |
     | Transaction Service | Aurora PostgreSQL + DynamoDB Streams | Relational + event streaming |
     | Statement Service | S3 + Athena | Document storage with ad-hoc queries |
     | Authorization Service | DynamoDB | Low-latency key-value for auth decisions |

4. **API Gateway and Integration**
   - Expose all services via Amazon API Gateway
   - Implement OpenAPI specifications
   - Enable partner/third-party integrations via API keys
   - Add rate limiting, caching, and throttling

5. **Observability**
   - AWS CloudWatch metrics and alarms for all services
   - AWS X-Ray distributed tracing
   - Centralized logging with CloudWatch Logs Insights
   - Custom dashboards replacing mainframe SMF monitoring

**Deliverables:**
- Microservices architecture on ECS/Lambda
- Event-driven transaction processing (no batch windows)
- API Gateway with documented endpoints
- Full observability stack

### Phase 4: Optimization and Decommission (Weeks 53-60)

**Objective**: Optimize costs, decommission legacy components, and establish long-term operations.

**Activities:**

1. **Decommission Replatform Runtime**
   - Shut down Rocket Software EC2 instances
   - Archive VSAM data files to S3 Glacier
   - Terminate Rocket Software licenses

2. **Cost Optimization**
   - Right-size ECS tasks and Lambda concurrency
   - Implement auto-scaling policies
   - Evaluate Reserved Instances / Savings Plans for Aurora
   - Enable S3 lifecycle policies for statement archives

3. **Operational Readiness**
   - Finalize runbooks and incident response procedures
   - Train operations team on AWS-native monitoring
   - Establish SLAs for each microservice
   - Complete disaster recovery testing

4. **Knowledge Transfer**
   - Train development team on Java/Spring Boot codebase
   - Document architectural decisions and patterns
   - Archive all COBOL source code and mainframe artifacts in S3

**Deliverables:**
- Mainframe fully decommissioned
- Optimized cloud cost baseline
- Operational documentation and runbooks
- Trained development and operations teams

---

## 6. Data Migration Strategy

### VSAM to Relational Database Mapping

The core data migration converts VSAM KSDS datasets to Aurora PostgreSQL tables. The COBOL copybook definitions provide the source schema:

```
COBOL Copybook (CVACT01Y.cpy)          ->  PostgreSQL Table
------------------------------------       ----------------------------------
01  ACCOUNT-RECORD.                         CREATE TABLE accounts (
  05  ACCT-ID            PIC 9(11)            acct_id         BIGINT PRIMARY KEY,
  05  ACCT-ACTIVE-STATUS PIC X(01)            active_status   CHAR(1),
  05  ACCT-CURR-BAL      PIC S9(10)V99        current_balance DECIMAL(12,2),
  05  ACCT-CREDIT-LIMIT  PIC S9(10)V99        credit_limit    DECIMAL(12,2),
  05  ACCT-CASH-CREDIT-LIMIT PIC S9(10)V99    cash_credit_limit DECIMAL(12,2),
  05  ACCT-OPEN-DATE     PIC X(10)            open_date       DATE,
  05  ACCT-EXPIRAION-DATE PIC X(10)           expiration_date DATE,
  05  ACCT-REISSUE-DATE  PIC X(10)            reissue_date    DATE,
  ...                                         ...
                                            );
```

### Key Data Conversion Considerations

| COBOL Type | PostgreSQL Type | Conversion Notes |
|:-----------|:----------------|:-----------------|
| `PIC 9(n)` | `BIGINT` or `DECIMAL` | Direct numeric conversion |
| `PIC X(n)` | `VARCHAR(n)` or `CHAR(n)` | EBCDIC-to-UTF-8 conversion required |
| `PIC S9(n)V99 COMP-3` | `DECIMAL(n+2, 2)` | Unpack from packed decimal format |
| `PIC S9(n)V99` | `DECIMAL(n+2, 2)` | Handle sign in zone digit |
| `FILLER` | N/A | Dropped during migration |

### Migration Approach

1. **Extract**: Use Precisely Connect or AWS Transfer Family to move VSAM files to S3
2. **Transform**: AWS Glue job to convert EBCDIC to UTF-8, unpack COMP-3, and normalize
3. **Load**: AWS Glue or DMS to load into Aurora PostgreSQL
4. **Validate**: Row count verification, checksum comparison, financial total reconciliation

### GDG Migration

Generation Data Groups (transaction backups, rejected records) migrate to S3 with versioning:

| GDG Dataset | S3 Location | Lifecycle |
|:------------|:------------|:----------|
| `TRANSACT.BKUP.G####V00` | `s3://carddemo-data/backups/transactions/YYYY-MM-DD/` | S3 Glacier after 90 days |
| `DALYREJS.G####V00` | `s3://carddemo-data/rejects/YYYY-MM-DD/` | Delete after 1 year |
| `SYSTRAN.G####V00` | `s3://carddemo-data/system-transactions/YYYY-MM-DD/` | S3 Glacier after 90 days |

---

## 7. Risk Assessment and Mitigation

| Risk | Likelihood | Impact | Mitigation |
|:-----|:-----------|:-------|:-----------|
| **Financial calculation precision loss** during COMP-3 conversion | Medium | Critical | Validate every COMP-3 field with bit-level comparison; use Java BigDecimal |
| **EBCDIC sort order differences** in converted application | Medium | High | Compare sort outputs between mainframe and cloud for all SORT jobs |
| **Batch window elimination** breaks downstream dependencies | Medium | High | Phase 3 only after thorough integration testing; maintain batch option as fallback |
| **AWS Transform produces non-idiomatic Java code** | High | Medium | Plan for manual code review and refactoring sprints post-conversion |
| **CICS pseudo-conversational state management** lost in conversion | Low | High | AWS Blu Age handles COMMAREA conversion; validate all multi-screen flows |
| **3270 screen field validation logic** missing in web UI | Medium | Medium | Test every field validation rule in BMS maps against Angular implementation |
| **Control-M/CA7 dependency chains** not fully captured | Low | High | Parse XML/CA7 definitions programmatically; validate with mainframe operations team |
| **Performance degradation** in replatform environment | Medium | Medium | Conduct load testing early in Phase 1; benchmark against mainframe MIPS |
| **Optional modules (Db2, IMS, MQ)** require separate migration paths | Medium | Medium | Address in Phase 2; use AWS DMS for Db2, Amazon MQ for IBM MQ replacement |
| **Team lacks AWS skills** for cloud-native Phase 3 | Medium | Medium | AWS training and certification in Phases 0-1; engage AWS Professional Services |

---

## 8. Success Metrics

### Phase 0 (Assessment)
- 100% of COBOL programs analyzed and documented by AWS Transform
- Baseline test suite covers all 20+ CICS transactions
- Data migration mapping validated for all 11 VSAM datasets

### Phase 1 (Replatform)
- CardDemo fully operational on AWS (Rocket Software runtime)
- All batch jobs executing successfully on schedule
- Response time within 20% of mainframe baseline
- Zero data loss during migration

### Phase 2 (Refactor)
- 100% COBOL programs converted to Java
- All CICS transactions functional as REST APIs with web UI
- Financial calculations match mainframe outputs to the cent
- Batch processing completes within acceptable time windows
- COBOL maintenance staff reduced to zero

### Phase 3 (Reimagine)
- Real-time transaction processing (sub-second latency)
- API response time < 200ms (p99)
- Auto-scaling handles 10x peak load
- Batch window eliminated (continuous processing)
- Infrastructure cost reduced 40-60% vs. mainframe

### Phase 4 (Decommission)
- Mainframe fully decommissioned
- All data archived and accessible
- Operations team fully trained on cloud-native stack
- Total cost of ownership reduced by 50%+ annually

---

## 9. References

- [AWS Transform for Mainframe](https://aws.amazon.com/transform/mainframe/) - Agentic AI-powered mainframe modernization service
- [AWS Mainframe Modernization Service](https://aws.amazon.com/mainframe-modernization/) - Managed runtime for replatform and refactor
- [Mainframe Modernization with AWS: A Complete Guide for 2026](https://repost.aws/articles/ARue7jnmK4RUSaQH0NkZ4wng/mainframe-modernization-with-aws-a-complete-guide-for-2026) - Comprehensive AWS toolset overview
- [Accelerate Mainframe Modernization with AWS Transform](https://aws.amazon.com/blogs/migration-and-modernization/accelerate-mainframe-modernization-with-aws-transform-a-comprehensive-refactor-approach/) - COBOL-to-Java refactoring guide
- [Reimagine Your Mainframe Applications with Agentic AI](https://aws.amazon.com/blogs/migration-and-modernization/reimagine-your-mainframe-applications-with-agentic-ai-and-aws-transform/) - Cloud-native reimagine patterns
- [Modernize and Deploy Mainframe Applications Using AWS Transform and Terraform](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/modernize-mainframe-app-transform-terraform.html) - CardDemo-specific AWS Transform guide
- [From Mainframe to AWS Cloud: Databases](https://aws.amazon.com/blogs/migration-and-modernization/from-mainframe-to-aws-cloud-a-comprehensive-mapping-guide-part-2-databases/) - VSAM/Db2/IMS migration patterns
- [Migrate VSAM Files to Amazon RDS Using Precisely Connect](https://docs.aws.amazon.com/prescriptive-guidance/latest/patterns/migrate-and-replicate-vsam-files-to-amazon-rds-or-amazon-msk-using-connect-from-precisely.html) - VSAM data migration pattern
- [Taking a Comprehensive Perspective to Mainframe Application Modernization](https://aws.amazon.com/blogs/migration-and-modernization/taking-a-comprehensive-perspective-to-mainframe-application-modernization-with-a-disposition-strategy/) - Disposition strategy framework
- [CardDemo Source Repository (aws-samples)](https://github.com/aws-samples/aws-mainframe-modernization-carddemo) - Original CardDemo application

---

*Document generated: February 2026*
*Based on analysis of the CardDemo application repository and current AWS Mainframe Modernization service offerings.*
