# Deployment Guide

Step-by-step instructions for deploying the OHDSI Vocabulary Validation Pipeline to Google Sheets.

## Prerequisites

- Google Account with access to Google Sheets
- Access to OHDSI vocabulary database (PostgreSQL, MySQL, or Oracle)
- Database credentials with SELECT permissions
- Basic understanding of Google Apps Script

## Deployment Steps

### 1. Create Master Template Spreadsheet

1. Go to [Google Sheets](https://sheets.google.com)
2. Click **Blank** to create a new spreadsheet
3. Rename it to match your template type (e.g., "OHDSI Template T1 - Non-Standard Concepts")

### 2. Create Required Sheets

Create these sheets in your spreadsheet:

#### Metadata Sheet
1. Click the **+** button at the bottom to add a new sheet
2. Rename it to **Metadata**
3. Add these headers and fields:

| Metadata Field | Value |
|---|---|
| Author Name | |
| Author Email | |
| Template Type | T1 |
| Submission Date | |
| Organization | |
| Description | |

#### Input Sheet
1. Create a new sheet named **Input**
2. Add column headers based on your template type

**Example for T1 (Adding non-standard concepts):**
```
concept_name | concept_code | vocabulary_id | domain_id | concept_class_id | valid_start_date | valid_end_date
```

#### Output Sheet
1. Create a new sheet named **Output**
2. Leave it blank (will be populated by the script)

#### Combined View (Optional)
1. Create a new sheet named **Combined View**
2. Add example data or instructions for users

### 3. Add Google Apps Script

1. In your spreadsheet, go to **Extensions > Apps Script**
2. You'll see a default `Code.gs` file

#### Add All Script Files

For each of the 7 script files, follow these steps:

1. Click the **+** button next to **Files**
2. Select **Script**
3. Name the file (e.g., `DataSanitization`)
4. Copy and paste the corresponding code from this repository
5. Save with **Ctrl+S** (Cmd+S on Mac)

**Files to add:**
- Code.gs (already exists, replace content)
- DataSanitization.gs
- DatabaseValidation.gs
- AuditLog.gs
- ResultsOutput.gs
- Submission.gs
- ValidationRules.gs

### 4. Set Up Script Permissions

1. In the Apps Script editor, click **Run** (play button) on the `onOpen` function
2. You'll see a dialog: "Authorization required"
3. Click **Review Permissions**
4. Select your Google account
5. Click **Advanced** if you see a warning
6. Click **Go to [Your Project Name] (unsafe)**
7. Click **Allow**

**Permissions needed:**
- View and manage spreadsheets
- Connect to external service (JDBC)
- Send emails on your behalf (for notifications)
- Create/modify files in Google Drive

### 5. Configure API Connection

1. Go back to your spreadsheet
2. Refresh the page (F5)
3. You should now see a new menu: **OHDSI Validation**
4. Click **OHDSI Validation > Admin > Configure Database**
5. Fill in your API details:

```
URI: someaddress.com
API Key: supersecretke
```

6. Click **Save Configuration**

**Test the connection:**
1. Fill in a test row in the Input sheet
2. Click **OHDSI Validation > Validate Template**
3. If successful, you'll see results in the Output sheet

### 6. Initialize Required Sheets

1. Click **OHDSI Validation > Admin > Setup Sheets**
2. This will create any missing sheets and add headers
3. Verify the **AuditLog** sheet was created

### 7. Configure Submission Folder

1. Create a Google Drive folder for submissions:
   - Go to [Google Drive](https://drive.google.com)
   - Click **New > Folder**
   - Name it "OHDSI_Submissions"
   - Share it with your team (if needed)

2. Get the Folder ID:
   - Open the folder
   - Copy the ID from the URL: `https://drive.google.com/drive/folders/FOLDER_ID_HERE`

3. Configure in the spreadsheet:
   - Click **OHDSI Validation > Admin > Configure Submission Folder**
   - Paste the Folder ID
   - Click **OK**

### 8. Customize Validation Rules

Edit `ValidationRules.gs` to match your database schema:

1. In Apps Script editor, open **ValidationRules.gs**
2. Find your template type (e.g., `'T1'`)
3. Review/modify SQL queries:
   - Table names must match your schema
   - Column names must match your schema
   - Adjust validation logic as needed

Example customization:
```javascript
// If your vocabulary table has a different name
sql: `
  SELECT t.source_row_number, ...
  FROM {TEMP_TABLE} t
  LEFT JOIN my_vocabulary_table v ON v.vocab_id = t.vocabulary_id
  -- Change 'vocabulary' to 'my_vocabulary_table'
`
```

### 9. Test the Complete Workflow

1. **Fill in Metadata**:
   - Switch to Metadata sheet
   - Fill in Author Name and Email

2. **Add test data to Input**:
   - Add a valid row
   - Add an invalid row (e.g., wrong vocabulary_id)

3. **Validate**:
   - Click **OHDSI Validation > Validate Template**
   - Check Output sheet for results

4. **Fix and revalidate**:
   - Fix the invalid row
   - Run validation again

5. **Submit**:
   - Click **OHDSI Validation > Submit Final Version**
   - Check your submission folder in Drive

6. **Verify audit log**:
   - Click **OHDSI Validation > View Audit Log**
   - Confirm all actions are logged

### 10. Create Template Copies for Users

Once everything is working:

1. **Make a copy of your master template**:
   - File > Make a copy
   - Name it appropriately
   - Share with users

2. **Protect certain sheets** (optional):
   - Right-click sheet tab > Protect sheet
   - Set permissions (e.g., only you can edit Metadata headers)

3. **Create templates for all 7 types**:
   - Repeat for T1-T7
   - Adjust Input sheet headers for each type
   - Update Metadata sheet default Template Type

### 11. Share with Users

**Option A: Direct Sharing**
1. Click **Share** button
2. Add user emails
3. Set permissions: **Editor**

**Option B: Link Sharing**
1. Click **Share** button
2. Click **Get link**
3. Set to "Anyone with the link can edit"
4. Copy link and distribute

**Option C: Template Gallery**
1. File > Publish to web
2. Create a landing page with links to all templates

### 12. Monitor and Maintain

**Weekly:**
- Review Audit Logs
- Check submission folder
- Monitor for errors

**Monthly:**
- Clear old audit entries (older than 90 days)
- Review and update validation rules
- Check database connection is still valid

**As needed:**
- Update validation queries when schema changes
- Add new template types
- Customize error messages


**Deployment Complete!** 🎉

Your OHDSI Vocabulary Validation Pipeline is now ready for use.
