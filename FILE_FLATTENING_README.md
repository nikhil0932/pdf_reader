# File Flattening Tools

This directory contains two scripts to move files from subfolders into a main folder.

## Scripts Available

### 1. Ruby Script (`move_files_to_main_folder.rb`)

A comprehensive Ruby script with advanced options for moving files from subdirectories to a main folder.

#### Features:
- **Dry run mode**: Preview changes before executing
- **Conflict resolution**: Handle duplicate filenames (rename, skip, or overwrite)
- **File extension filtering**: Only move specific file types
- **Structure preservation**: Include folder names in filenames
- **Empty directory cleanup**: Remove empty folders after moving files
- **Progress tracking**: Shows detailed progress and summary

#### Usage:

```bash
# Basic usage - move all files in current directory
./move_files_to_main_folder.rb .

# Move files from source to target directory
./move_files_to_main_folder.rb /path/to/source /path/to/target

# Dry run to see what would be moved
./move_files_to_main_folder.rb /path/to/source --dry-run

# Only move PDF files
./move_files_to_main_folder.rb /path/to/source --extensions pdf

# Only move specific file types
./move_files_to_main_folder.rb /path/to/source --extensions pdf,txt,docx

# Preserve folder structure in filename
./move_files_to_main_folder.rb /path/to/source --preserve-structure

# Handle conflicts by skipping existing files
./move_files_to_main_folder.rb /path/to/source --conflict skip

# Handle conflicts by overwriting existing files
./move_files_to_main_folder.rb /path/to/source --conflict overwrite
```

#### Options:
- `-d, --dry-run`: Show what would be moved without actually moving files
- `-p, --preserve-structure`: Include folder names in filename (e.g., `subfolder_file.pdf`)
- `-e, --extensions EXTENSIONS`: Only move files with specified extensions (comma-separated)
- `-c, --conflict STRATEGY`: How to handle filename conflicts: `rename`, `skip`, `overwrite` (default: rename)
- `-h, --help`: Show help message

### 2. Bash Script (`move_files_simple.sh`)

A simpler bash script for basic file moving operations.

#### Features:
- **Simple and fast**: Minimal dependencies (just bash and common Unix tools)
- **Dry run mode**: Preview changes before executing
- **Conflict resolution**: Automatically renames duplicate files
- **Empty directory cleanup**: Removes empty folders after moving

#### Usage:

```bash
# Move files in current directory
./move_files_simple.sh

# Move files from source directory
./move_files_simple.sh /path/to/source

# Move files from source to target directory
./move_files_simple.sh /path/to/source /path/to/target

# Dry run to preview changes
./move_files_simple.sh /path/to/source --dry-run
```

## Examples

### Example 1: Flatten PDF files with dry run

```bash
# See what PDF files would be moved
./move_files_to_main_folder.rb ./documents --extensions pdf --dry-run
```

### Example 2: Move all files preserving structure

```bash
# Move files and include folder names in filenames
./move_files_to_main_folder.rb ./documents --preserve-structure
```

### Example 3: Simple move with bash script

```bash
# Quick and simple file flattening
./move_files_simple.sh ./my_files
```

## File Structure Example

**Before:**
```
documents/
├── 2024/
│   ├── january/
│   │   ├── report1.pdf
│   │   └── notes.txt
│   └── february/
│       └── report2.pdf
├── 2023/
│   └── archive/
│       └── old_report.pdf
└── misc/
    └── readme.md
```

**After (normal mode):**
```
documents/
├── report1.pdf
├── notes.txt
├── report2.pdf
├── old_report.pdf
└── readme.md
```

**After (preserve structure mode):**
```
documents/
├── 2024_january_report1.pdf
├── 2024_january_notes.txt
├── 2024_february_report2.pdf
├── 2023_archive_old_report.pdf
└── misc_readme.md
```

## Safety Features

- **Dry run mode**: Always test with `--dry-run` first
- **Conflict resolution**: Duplicate files are renamed by default (e.g., `file_1.pdf`, `file_2.pdf`)
- **Error handling**: Scripts continue processing even if individual file moves fail
- **Summary reporting**: Shows detailed results of the operation

## Requirements

- **Ruby script**: Ruby 2.5+ (uses standard libraries only)
- **Bash script**: Bash 4+ and common Unix tools (`find`, `mv`, `realpath`)

## Use Cases

- **Document organization**: Flatten complex folder structures
- **File consolidation**: Merge files from multiple subdirectories
- **Archive processing**: Extract files from nested archive structures
- **Project cleanup**: Reorganize scattered project files
- **Media organization**: Consolidate photos, videos, or audio files

Choose the Ruby script for advanced features and filtering, or the bash script for simple, fast operations.
