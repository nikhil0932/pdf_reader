# PDF Folder Processing Scripts

This document explains how to use the batch processing scripts to load PDF files from folders and process them into the database.

## Overview

The system provides multiple ways to process PDF files from folders:

1. **Rails Rake Tasks** - Using Rails built-in task system
2. **Standalone Ruby Script** - Direct Ruby execution
3. **Bash Script Wrapper** - Easy-to-use shell interface

## Features

- **Batch Processing**: Process all PDF files in a folder at once
- **Duplicate Prevention**: Automatically skips files already in database
- **Data Extraction**: Extracts licensor, licensee, dates, and other license information
- **File Tracking**: Stores original filename in database
- **Progress Reporting**: Shows processing status and results
- **Error Handling**: Continues processing even if individual files fail

## Database Fields

Each processed PDF stores the following information:

- `filename` - Original PDF filename
- `title` - Document title (derived from filename)
- `content` - Full extracted text
- `licensor` - Extracted licensor information
- `licensee` - Extracted licensee information  
- `address` - Extracted address information
- `agreement_date` - Parsed agreement date
- `agreement_period` - Agreement duration period
- `filtered_data` - Additional structured data
- `page_count` - Number of pages in PDF
- `uploaded_at` - Processing timestamp

## Usage Methods

### 1. Using Rails Rake Tasks

```bash
# Process all PDFs in a folder
rails pdf:process_folder["/path/to/pdf/folder"]

# Check which files are already processed
rails pdf:check_folder["/path/to/pdf/folder"]
```

### 2. Using Standalone Ruby Script

```bash
# Process all PDFs in a folder
ruby pdf_folder_processor.rb /path/to/pdf/folder

# Or explicitly specify the action
ruby pdf_folder_processor.rb /path/to/pdf/folder process

# Check processing status
ruby pdf_folder_processor.rb /path/to/pdf/folder check
```

### 3. Using Bash Script (Recommended)

```bash
# Process all PDFs in a folder
./process_pdfs.sh process /path/to/pdf/folder

# Check processing status
./process_pdfs.sh check /path/to/pdf/folder

# Show database statistics
./process_pdfs.sh status

# Show help
./process_pdfs.sh help
```

## Example Usage

```bash
# Example: Process PDFs from a documents folder
./process_pdfs.sh process /home/user/documents/license_agreements

# Example: Check what's already been processed
./process_pdfs.sh check /home/user/documents/license_agreements

# Example: View current database stats
./process_pdfs.sh status
```

## Sample Output

```
Processing PDF files from: /home/user/documents/pdfs
========================================
Found 5 PDF file(s) to process...
Starting batch processing...

[1/5] Processing: license_agreement_001.pdf
  ✅ Successfully processed and saved (ID: 123)
    📄 Title: license_agreement_001
    👥 Licensor: John Doe Property Management
    🏠 Licensee: Jane Smith
    📅 Agreement Date: 2025-04-01
    ⏰ Period: 11 Months

[2/5] Processing: license_agreement_002.pdf
  ⚠️  Skipping - file already exists in database (ID: 98)

[3/5] Processing: damaged_file.pdf
  ❌ Error: PDF reading error: Invalid PDF format

==================================================
Batch processing completed!
Total files: 5
Successfully processed: 3
Errors: 1
Skipped (already exist): 1
==================================================
```

## File Requirements

- Files must have `.pdf` extension
- Files must be valid PDF documents
- Folder must be accessible and readable

## Error Handling

The scripts handle various error conditions:

- **Missing folder**: Script exits with error message
- **No PDF files**: Informs user and exits gracefully
- **Corrupted PDFs**: Logs error and continues with next file
- **Duplicate files**: Skips processing and continues
- **Permission issues**: Reports error and continues

## Database Uniqueness

Files are identified by their filename. If a file with the same name already exists in the database, it will be skipped. This prevents duplicate processing of the same document.

## Performance Considerations

- Large folders: Processing time increases with number of files
- File size: Larger PDFs take longer to process
- Text complexity: Complex layouts may take longer to parse
- Database: Ensure adequate database connection limits

## Monitoring Progress

All scripts provide real-time progress updates:

- File-by-file processing status
- Success/error indicators
- Extracted data preview
- Final summary statistics

## Integration with Existing System

These scripts integrate seamlessly with the existing PDF processing system:

- Uses existing `PdfDocument` model
- Leverages existing `PdfDataExtractorService`
- Maintains compatibility with web upload functionality
- Preserves all existing database relationships

## Troubleshooting

### Common Issues

1. **Permission denied**: Ensure scripts are executable (`chmod +x`)
2. **Folder not found**: Verify the folder path is correct and accessible
3. **Database connection**: Ensure Rails application can connect to database
4. **PDF reader errors**: Some PDFs may be corrupted or use unsupported formats

### Checking Logs

- Rails logs: `log/development.log`
- Script output: All scripts provide detailed console output
- Database queries: Enable SQL logging if needed

## Advanced Usage

### Custom Filtering

You can modify the `PdfDataExtractorService` to extract additional fields or improve pattern matching for your specific document types.

### Batch Scheduling

Set up cron jobs to automatically process folders:

```bash
# Process new files every hour
0 * * * * /path/to/pdf_extractor/process_pdfs.sh process /path/to/watch/folder
```

### Integration with File Watchers

Combine with file system watchers for real-time processing:

```bash
# Using inotifywait to watch for new files
inotifywait -m /path/to/folder -e create --format '%f' | while read file; do
    if [[ $file == *.pdf ]]; then
        ./process_pdfs.sh process /path/to/folder
    fi
done
```

## File Organization Features

The system now supports organizing processed files into subfolders based on their processing status:

### Automatic File Moving During Processing

```bash
# Process files and move them to subfolders based on results
rails pdfs:process_folder["/path/to/pdfs",true,true]

# Arguments:
# - folder_path: Path to folder containing PDF files
# - move_processed: true/false - Move successfully processed files to 'processed' subfolder  
# - move_errors: true/false - Move files with errors to 'errors' subfolder

# Examples:
rails pdfs:process_folder["/path/to/pdfs",true,false]   # Only move successful files
rails pdfs:process_folder["/path/to/pdfs",false,true]   # Only move error files
rails pdfs:process_folder["/path/to/pdfs",true,true]    # Move both types
```

### Organize Existing Files

```bash
# Organize already processed files into subfolders
rails pdfs:organize_files["/path/to/pdf/folder"]
```

This will:
- Move successfully processed files to `processed/` subfolder
- Move files with processing errors to `errors/` subfolder  
- Leave unprocessed files in the main folder

### Folder Structure After Organization

```
pdf_folder/
├── unprocessed_file1.pdf
├── unprocessed_file2.pdf
├── processed/
│   ├── successfully_processed1.pdf
│   ├── successfully_processed2.pdf
│   └── successfully_processed3.pdf
└── errors/
    ├── corrupted_file.pdf
    ├── password_protected.pdf
    └── invalid_format.pdf
```
