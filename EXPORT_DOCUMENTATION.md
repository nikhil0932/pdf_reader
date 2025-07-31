# PDF Data Export Documentation

This document explains how to export your PDF document data to Excel (XLSX) and CSV formats.

## 🎯 Overview

The system provides multiple ways to export your PDF data:

1. **Web Interface** - User-friendly browser interface
2. **Command Line (Rails Tasks)** - Using Rails rake tasks  
3. **Standalone Script** - Direct Ruby script execution
4. **API Endpoints** - For programmatic access

## 📊 Data Exported

Each export includes the following fields:

| Field | Description |
|-------|-------------|
| `ID` | Unique document identifier |
| `Filename` | Original PDF filename |
| `Title` | Document title |
| `Licensor` | Extracted licensor information |
| `Licensee` | Extracted licensee information |
| `Address` | Extracted address details |
| `Agreement Date` | Parsed agreement date |
| `Agreement Period` | Agreement duration (e.g., "11 Months") |
| `Page Count` | Number of pages in PDF |
| `Uploaded At` | When the document was uploaded |
| `Created At` | Database record creation time |
| `Updated At` | Last modification time |
| `Content Preview` | First 100-500 characters of extracted text |
| `Filtered Data Preview` | Preview of structured data |

## 🌐 Web Interface

### Access the Export Page

1. Navigate to your PDF documents list
2. Click the **"📊 Export Data"** button in the top navigation
3. Choose your export option

### Quick Export (All Data)

- **Excel Export**: Downloads all data as `.xlsx` file with multiple sheets
- **CSV Export**: Downloads all data as `.csv` file

### Filtered Export

Use the filter form to export specific data:

- **Date Range**: Filter by agreement date
- **Licensor**: Search for specific licensor names
- **Licensee**: Search for specific licensee names  
- **Agreement Period**: Filter by period (e.g., "11 Months")

### Excel Features

Excel exports include:
- **Data Sheet**: All document data with proper formatting
- **Summary Sheet**: Statistics and overview
- **Styled Headers**: Professional formatting
- **Auto-sized Columns**: Optimized column widths
- **Date Formatting**: Proper date/time formats

## 💻 Command Line Usage

### Rails Rake Tasks

```bash
# Export all data to CSV
rails export:csv

# Export all data to Excel  
rails export:excel

# Export to specific file
rails export:csv["/path/to/my_export.csv"]
rails export:excel["/path/to/my_export.xlsx"]

# Export filtered data
rails export:filtered[csv,output.csv,2025-01-01,2025-12-31,John,Jane]

# Show export statistics
rails export:stats
```

### Standalone Export Script

```bash
# Export to CSV (default)
ruby export_data.rb

# Export to Excel
ruby export_data.rb excel

# Export to specific file
ruby export_data.rb csv my_data.csv
ruby export_data.rb excel my_data.xlsx

# Show help
ruby export_data.rb help
```

## 📋 Export Examples

### Example 1: Export All Data to Excel

```bash
# Using rake task
rails export:excel

# Using standalone script  
ruby export_data.rb excel

# Result: pdf_documents_20250731.xlsx
```

### Example 2: Export Filtered Data

```bash
# Export documents from 2025 with "John" as licensor
rails export:filtered[csv,john_2025.csv,2025-01-01,2025-12-31,John,]

# Using web interface: Use the filter form
```

### Example 3: Monthly Export Automation

```bash
#!/bin/bash
# Monthly export script
DATE=$(date +%Y%m)
rails export:excel["/backups/pdf_export_${DATE}.xlsx"]
rails export:csv["/backups/pdf_export_${DATE}.csv"]
```

## 📁 File Formats

### CSV Format

- **Encoding**: UTF-8
- **Delimiter**: Comma (,)
- **Headers**: First row contains column names
- **Date Format**: YYYY-MM-DD
- **DateTime Format**: YYYY-MM-DD HH:MM:SS

### Excel Format  

- **Format**: XLSX (Excel 2007+)
- **Sheets**: 
  - "PDF Documents" - Main data
  - "Summary" - Statistics and overview
- **Styling**: Professional formatting with colors and fonts
- **Data Types**: Proper date, number, and text formatting

## 🔧 Advanced Usage

### Filtering Options

When using filtered exports, you can combine multiple filters:

- **Date Range**: Specify start and/or end dates
- **Text Search**: Partial matching in licensor/licensee fields
- **Period Matching**: Find specific agreement periods

### Automation

Set up automated exports using cron jobs:

```bash
# Daily export at 2 AM
0 2 * * * cd /path/to/pdf_extractor && rails export:excel > /dev/null 2>&1

# Weekly summary export
0 0 * * 0 cd /path/to/pdf_extractor && rails export:stats >> /var/log/pdf_stats.log
```

### Large Dataset Handling

For large datasets (1000+ documents):

- Use CSV format for faster processing
- Consider filtered exports to reduce file size
- Use command line tools for better performance

## 🛠️ Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   chmod +x export_data.rb
   ```

2. **Missing Gems**
   ```bash
   bundle install
   ```

3. **Database Connection**
   ```bash
   rails db:migrate
   ```

4. **Large File Issues**
   - Use CSV for very large datasets
   - Export in smaller chunks using filters

### Error Messages

- **"No documents found"**: Database is empty
- **"Permission denied"**: Check file permissions
- **"Invalid format"**: Use 'csv' or 'excel'

## 📈 Performance Tips

- **CSV vs Excel**: CSV is faster for large datasets
- **Filtered Exports**: Reduce data size with filters  
- **Command Line**: Better performance than web interface
- **Batch Processing**: Use rake tasks for automation

## 🔒 Security Considerations

- Exported files contain sensitive data
- Store exports in secure locations
- Use appropriate file permissions
- Consider encrypting sensitive exports

## 📞 Integration Examples

### Python Integration

```python
import pandas as pd

# Read CSV export
df = pd.read_csv('pdf_documents_20250731.csv')
print(df.head())

# Read Excel export
df = pd.read_excel('pdf_documents_20250731.xlsx', sheet_name='PDF Documents')
print(df.info())
```

### Backup Script

```bash
#!/bin/bash
# Automated backup with export
DATE=$(date +%Y%m%d)
BACKUP_DIR="/backups/pdf_data"

mkdir -p "$BACKUP_DIR"
cd /path/to/pdf_extractor

# Export data
rails export:excel["$BACKUP_DIR/pdf_export_$DATE.xlsx"]
rails export:csv["$BACKUP_DIR/pdf_export_$DATE.csv"]

# Create archive
tar -czf "$BACKUP_DIR/pdf_backup_$DATE.tar.gz" -C "$BACKUP_DIR" \
    "pdf_export_$DATE.xlsx" "pdf_export_$DATE.csv"

echo "Backup completed: $BACKUP_DIR/pdf_backup_$DATE.tar.gz"
```

## 🎉 Quick Start

1. **Web Export**: Visit `/data_exports` and click export buttons
2. **Command Line**: Run `ruby export_data.rb excel`  
3. **Filtered Data**: Use the web form or rake task with parameters
4. **Automation**: Set up cron jobs for regular exports

The exported data can be opened in:
- Microsoft Excel
- Google Sheets
- LibreOffice Calc  
- Any CSV-compatible application
