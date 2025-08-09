# File Organization and Error Handling Guide

This guide explains how to use the enhanced file organization features for managing processed PDF files.

## Overview

The PDF processing system now includes automatic file organization capabilities to help you manage files based on their processing status:

- **Successfully processed files** → Move to `processed/` subfolder
- **Files with processing errors** → Move to `errors/` subfolder  
- **Unprocessed files** → Remain in main folder for future processing

## Usage Scenarios

### 1. Process Files with Automatic Organization

```bash
# Process files and automatically organize them
rails pdfs:process_folder["/path/to/pdfs",true,true]

# Parameters:
# - folder_path: Path to PDF folder
# - move_processed: true/false (move successful files)
# - move_errors: true/false (move error files)
```

**Examples:**
```bash
# Move all files after processing
rails pdfs:process_folder["/home/docs/pdfs",true,true]

# Only move successfully processed files
rails pdfs:process_folder["/home/docs/pdfs",true,false]

# Only move files with errors
rails pdfs:process_folder["/home/docs/pdfs",false,true]

# Don't move any files (original behavior)
rails pdfs:process_folder["/home/docs/pdfs",false,false]
# or simply:
rails pdfs:process_folder["/home/docs/pdfs"]
```

### 2. Organize Already Processed Files

```bash
# Organize existing files based on database status
rails pdfs:organize_files["/path/to/pdf/folder"]
```

This command will:
- Check each PDF file against the database
- Move successfully processed files to `processed/` subfolder
- Move files with errors to `errors/` subfolder
- Leave unprocessed files in the main folder

## Folder Structure Examples

### Before Processing
```
documents/
├── contract1.pdf
├── agreement2.pdf
├── license3.pdf
├── corrupted.pdf
└── password_protected.pdf
```

### After Processing with Organization
```
documents/
├── unprocessed_file.pdf          # Not yet processed
├── processed/
│   ├── contract1.pdf              # Successfully processed
│   ├── agreement2.pdf             # Successfully processed
│   └── license3.pdf               # Successfully processed
└── errors/
    ├── corrupted.pdf              # Processing failed
    └── password_protected.pdf     # Processing failed
```

## Error Types and Organization

Files are moved to the `errors/` folder when they encounter:

1. **PDF Reading Errors**
   - Corrupted PDF files
   - Password-protected PDFs
   - Invalid PDF format

2. **Processing Errors**
   - Memory issues with very large files
   - Text extraction failures
   - Database save errors

3. **File System Errors**
   - Permission issues
   - Disk space problems
   - File locking issues

## Benefits

### 1. **Easy Error Review**
- All problematic files are in one `errors/` folder
- Can manually review and fix issues
- Can reprocess after fixing problems

### 2. **Clean Workflow**
- Successfully processed files don't clutter the main folder
- Easy to see what still needs processing
- Clear separation of file states

### 3. **Batch Operations**
- Process large folders efficiently
- Automatic cleanup and organization
- Resume processing on remaining files

## Advanced Usage

### Reprocessing Error Files

```bash
# After fixing issues, reprocess error files
rails pdfs:process_folder["documents/errors",true,false]
```

### Checking Processing Status

```bash
# View processing statistics
rails export:stats
```

### Moving Files Between Folders

```bash
# Use the file flattening tools to reorganize
./move_files_to_main_folder.rb documents/errors documents/
./move_files_to_main_folder.rb documents/processed documents/
```

## Troubleshooting

### Files Not Moving
- Check folder permissions
- Ensure destination folders are writable
- Verify file paths are correct

### Duplicate Filenames
- System automatically renames conflicts (file_1.pdf, file_2.pdf)
- Check for existing files in destination folders

### Database Sync Issues
- Run `rails pdfs:organize_files` to sync folder organization with database status
- Check that filenames match between files and database records

## Demo Script

Run the demonstration script to see how file organization works:

```bash
ruby file_organization_demo.rb /path/to/pdf/folder
```

This script shows what would happen without actually moving files.

## Integration with Export Features

The organization features work seamlessly with the export functionality:

```bash
# Export only successfully processed files
rails export:csv
rails export:excel

# The exported data will include the filename field to help locate files
```

Files in the `processed/` folder represent successfully extracted and exported data, while files in `errors/` may need manual review before inclusion in exports.

## Duplicate Detection and Prevention

The system now includes intelligent duplicate detection to prevent storing files with identical license information:

### Automatic Duplicate Detection

During processing, the system will skip files that have exact matches for:
- **Licensor** (license grantor)
- **Licensee** (license recipient) 
- **Start Date** and **End Date** (license period)

If any of these combinations already exist in the database, the new file will be skipped and optionally moved to the processed folder.

### Example Output
```
[3/10] Processing: duplicate_license.pdf
  Skipping - duplicate record found (licensor: ABC Corp, licensee: XYZ Inc, dates: 2024-01-01 to 2024-12-31)
    → Matches existing record ID: 15 (original_license.pdf)
  → Moved to processed folder
```

### Remove Existing Duplicates

To clean up duplicates that may already exist in your database:

```bash
# Find and remove duplicate records
rails pdfs:remove_duplicates
```

This interactive task will:
- Scan the database for duplicate combinations
- Show you what duplicates were found
- Ask for confirmation before removing duplicates
- Keep the oldest record from each duplicate group
- Remove the newer duplicate records
