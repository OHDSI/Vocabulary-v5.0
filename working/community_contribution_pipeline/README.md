# OHDSI Vocabulary Validation Pipeline

A comprehensive Google Apps Script-based validation system for community-contributed ontology mappings using collaborative Google Sheets and database validation.

## Overview

This pipeline enables users to:
1. Download and fill in vocabulary template spreadsheets
2. Validate their contributions against OHDSI vocabulary standards
3. Receive automated feedback on data quality
4. Submit validated mappings to a centralized repository

## Features

- **7 Template Types** - Support for different vocabulary contribution scenarios
- **SQL Injection Protection** - Comprehensive data sanitization
- **Database Validation** - Validates against live OHDSI vocabulary database
- **Audit Trail** - Complete logging of all user actions
- **Iterative Workflow** - Users can validate and refine until perfect
- **Automated Submission** - Package and submit final versions to Google Drive
- **Email Notifications** - Automated confirmation emails
- **Export Options** - CSV, JSON, and spreadsheet export formats

## Architecture

The system consists of:

### Google Apps Script Files (7 modules):

1. **Code.gs** - Main controller and UI menu
2. **DataSanitization.gs** - SQL injection prevention and data cleaning
3. **DatabaseValidation.gs** - API connection and validation execution
4. **AuditLog.gs** - Comprehensive audit logging
5. **ResultsOutput.gs** - Results formatting and visualization
6. **Submission.gs** - Final submission workflow
7. **ValidationRules.gs** - Helper functions (deprecated - see below)

### Validation Rules:

- **ValidationRules.sql** - SQL validation queries for all template types
- Rules are loaded and executed by the Azure Proxy API server
- Shared queries across templates use comma-separated template IDs

## Setup Instructions

### 1. Create Google Sheets Template

1. Create a new Google Spreadsheet
2. Create the following sheets:
   - **Input** - Where users enter their data
   - **Output** - Where validation results are displayed
   - **Metadata** - Author and submission information
   - **Combined View** (optional) - Example/reference data
   - **Working Sheet** (optional) - Scratch space

### 2. Add Scripts to Spreadsheet

1. Open your Google Sheet
2. Go to **Extensions > Apps Script**
3. Delete any existing code
4. Create 7 script files with the names and contents from the `gs_scripts/` folder:
   - Code.gs
   - DataSanitization.gs
   - DatabaseValidation.gs
   - AuditLog.gs
   - ResultsOutput.gs
   - Submission.gs
   - ValidationRules.gs (contains helper functions only)

### 3. Configure API Connection

**One-time setup after deployment:**

1. Open the Apps Script editor (**Extensions > Apps Script**)
2. Open **DatabaseValidation.gs**
3. Find the `configureDatabaseConnection()` function
4. Replace the placeholder values with your actual credentials:
   ```javascript
   const PROXY_URL = 'https://your-actual-url.com';
   const API_KEY = 'your-actual-api-key';
   ```
5. Click **OHDSI Validation > Admin > Configure Database** to set the parameters and then Run to execute the function

**Security Note**:
- Credentials are stored in Script Properties (encrypted by Google)
- They are NOT visible in the code or copied when users duplicate the spreadsheet
- The Azure Proxy API URL and API Key are kept secure server-side

### 4. Setup Required Sheets

1. Go to **OHDSI Validation > Admin > Setup Sheets**
2. This will create any missing required sheets with proper headers

### 5. Configure Submission Folder (Optional)

1. Create a shared Google Drive folder for submissions
2. Copy the Folder ID from the URL (the part after `/folders/`)
3. Go to **OHDSI Validation > Admin > Configure Submission Folder**
4. Paste the Folder ID

### 6. Customize Validation Rules (Optional)

Edit `ValidationRules.sql` to customize validation queries for your specific needs:

1. Open **ValidationRules.sql** in the repository root
2. Add or modify queries following the metadata comment format:
   ```sql
   -- TEMPLATE: T1,T2  (comma-separated templates that use this query)
   -- RULE: MY_CUSTOM_RULE
   -- LEVEL: ERROR
   -- FIELD: field_name
   -- MESSAGE: Error message
   SELECT
     source_row_number,
     'Detailed error message' AS validation_message,
     'field_name' AS field_name
   FROM {TEMP_TABLE}
   WHERE some_condition;
   ```
3. Reload the rules (no redeployment needed):
   ```bash
   curl -X POST https://your-server-url.com/reload-rules \
     -H "Authorization: Bearer YOUR_API_KEY"
   ```
4. See the "Customization" section below for detailed examples

## Template Types

T1: Adding new concept to existing vocabulary
T2: Adding new synonyms
T3: Adding new mappings
T4: Adding new vocabulary
T5: Modifying concept attributes
T6: Modifying mappings
T7: Promoting concept to standard

## User Workflow

### Step 1: Fill in Template

1. Open the Google Sheet template
2. Fill in the **Metadata** sheet:
   - Author Name
   - Author Email
   - Template Type (T1-T7)
   - Organization
   - Description

3. Fill in the **Input** sheet with your vocabulary data

### Step 2: Validate Data

1. Go to **OHDSI Validation > Validate Template**
2. Wait for validation to complete (may take 30-60 seconds)
3. Review results in the **Output** sheet

### Step 3: Review and Fix Issues

The Output sheet will show:
- **Summary** - Total errors and warnings
- **Detailed Results** - Row-by-row validation issues
- **Color Coding**:
  - Red = Errors (must fix)
  - Yellow = Warnings (should review)
  - Green = Info (FYI)

### Step 4: Iterate Until Clean

1. Fix issues in the **Input** sheet
2. Run **Validate Template** again
3. Repeat until no errors remain

### Step 5: Submit Final Version

1. When validation passes with 0 errors, go to **OHDSI Validation > Submit Final Version**
2. Confirm your submission
3. A submission package will be created in Google Drive with:
   - Full spreadsheet copy
   - CSV exports
   - Metadata JSON
   - README file

## Menu Options

### Main Menu
- **Validate Template** - Run validation on current data
- **Clear Input Data** - Clear the Input sheet (with confirmation)
- **Submit Final Version** - Submit validated data
- **View Audit Log** - See all actions and timestamps
- **Export Results** - Export validation results to file

### Admin Menu
- **Setup Sheets** - Create required sheets if missing
- **Configure Database** - Set database connection details

## Security Features

### SQL Injection Prevention
- All user input is sanitized before database interaction
- Dangerous SQL keywords are filtered
- Quote characters are escaped
- String length limits enforced
- Parameterized queries used for all database operations

### Data Validation
- Type checking for all fields
- Required field validation
- Format validation (dates, IDs, etc.)
- Cross-reference validation against vocabulary database

### Audit Trail
- All actions logged with:
  - Timestamp
  - User email
  - Action type
  - Details
  - Status (success/failure)
- Audit log kept for 1000 most recent entries



