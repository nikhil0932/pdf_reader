# 📊 PDF Data Export - Quick Reference

## 🚀 Quick Export Methods

### 1. Web Interface (Recommended for most users)
```
Visit: http://localhost:3000/data_exports
- Click "📊 Export to Excel (XLSX)" for Excel format
- Click "📄 Export to CSV" for CSV format
- Use filters for specific data subsets
```

### 2. Command Line - Rails Tasks
```bash
# Export all data to CSV
rails export:csv

# Export all data to Excel
rails export:excel

# Export to specific file
rails export:csv[my_data.csv]
rails export:excel[my_data.xlsx]

# Show database statistics
rails export:stats

# Export filtered data (format, output_file, date_from, date_to, licensor, licensee)
rails export:filtered[csv,filtered.csv,2025-01-01,2025-12-31,John,Jane]
```

### 3. Standalone Ruby Script
```bash
# Export to CSV (default)
ruby export_data.rb

# Export to Excel
ruby export_data.rb excel

# Export to specific file
ruby export_data.rb csv my_export.csv
ruby export_data.rb excel my_export.xlsx

# Show help
ruby export_data.rb help
```

## 📁 Export Formats

| Format | Extension | Best For |
|--------|-----------|----------|
| **CSV** | `.csv` | Large datasets, data analysis, simple viewing |
| **Excel** | `.xlsx` | Professional reports, charts, multiple sheets |

## 📋 Sample Data Structure

```csv
ID,Filename,Title,Licensor,Licensee,Address,Agreement Date,Agreement Period,Page Count,Uploaded At,Created At,Updated At,Content Preview,Filtered Data Preview
1,license_001.pdf,License Agreement 001,John Doe Property Management,Jane Smith,123 Main St...,2025-04-01,11 Months,3,2025-07-31 10:30:00,2025-07-31 10:30:00,2025-07-31 10:30:00,Sample License Agreement...,Licensor: John Doe...
```

## 🔧 Automation Examples

### Daily Export (Cron Job)
```bash
# Add to crontab: crontab -e
0 2 * * * cd /home/nikhil/pdf_extractor && rails export:excel > /dev/null 2>&1
```

### Weekly Backup Script
```bash
#!/bin/bash
DATE=$(date +%Y%m%d)
cd /home/nikhil/pdf_extractor
rails export:excel["/backups/pdf_export_${DATE}.xlsx"]
```

## 🎯 Use Cases

- **📈 Data Analysis**: Export to CSV for analysis in R, Python, or Excel
- **📋 Reports**: Export to Excel for professional formatted reports  
- **💾 Backups**: Regular automated exports for data backup
- **🔄 Migration**: Export data for migration to other systems
- **📊 Dashboards**: Import into BI tools like Tableau, Power BI

## 🚨 Current Database Status

Run this to check your current data:
```bash
rails export:stats
```

## 💡 Pro Tips

1. **Large datasets**: Use CSV format for faster processing
2. **Regular backups**: Set up automated daily/weekly exports
3. **Filtered exports**: Use date ranges to export specific time periods
4. **Excel features**: Excel exports include summary statistics
5. **File naming**: Default files include date (YYYYMMDD) for easy organization

## 🆘 Need Help?

- **Web Interface**: Visit `/data_exports` for user-friendly export
- **Documentation**: Read `EXPORT_DOCUMENTATION.md` for detailed info
- **Command Help**: Run `ruby export_data.rb help`
- **Stats**: Run `rails export:stats` to see current data overview
