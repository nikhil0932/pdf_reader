#!/bin/bash

# Simple bash script to move files from subfolders to main folder
# Usage: ./move_files_simple.sh [source_directory] [target_directory]

set -e

# Default values
SOURCE_DIR=""
TARGET_DIR=""
DRY_RUN=false

# Function to show usage
show_usage() {
    echo "Usage: $0 [SOURCE_DIR] [TARGET_DIR] [--dry-run]"
    echo ""
    echo "Move all files from subdirectories to main folder"
    echo ""
    echo "Arguments:"
    echo "  SOURCE_DIR    Source directory (default: current directory)"
    echo "  TARGET_DIR    Target directory (default: same as source)"
    echo "  --dry-run     Show what would be moved without actually moving"
    echo ""
    echo "Examples:"
    echo "  $0                           # Move files in current directory"
    echo "  $0 /path/to/source           # Move files from source to source"
    echo "  $0 /path/to/source /path/to/target  # Move files to different directory"
    echo "  $0 /path/to/source --dry-run # Preview what would be moved"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        -*)
            echo "Unknown option $1"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$SOURCE_DIR" ]; then
                SOURCE_DIR="$1"
            elif [ -z "$TARGET_DIR" ]; then
                TARGET_DIR="$1"
            fi
            shift
            ;;
    esac
done

# Set defaults if not set
if [ -z "$SOURCE_DIR" ]; then
    SOURCE_DIR="."
fi
if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR="$SOURCE_DIR"
fi

# Validate directories
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# Create target directory if it doesn't exist
if [ "$DRY_RUN" = false ] && [ ! -d "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
fi

echo "$([ "$DRY_RUN" = true ] && echo "[DRY RUN] ")Moving files from subfolders to main folder"
echo "Source directory: $(realpath "$SOURCE_DIR")"
echo "Target directory: $(realpath "$TARGET_DIR")"
echo "----------------------------------------"

moved_count=0
skipped_count=0
total_count=0

# Find and move files
while IFS= read -r -d '' file; do
    # Skip if file is already in target directory
    file_dir=$(dirname "$file")
    if [ "$file_dir" = "$TARGET_DIR" ]; then
        continue
    fi
    
    filename=$(basename "$file")
    target_path="$TARGET_DIR/$filename"
    relative_path=$(realpath --relative-to="$SOURCE_DIR" "$file")
    
    total_count=$((total_count + 1))
    
    echo "Processing: $relative_path"
    
    # Handle filename conflicts
    if [ -f "$target_path" ] && [ "$file" != "$target_path" ]; then
        # Generate unique filename
        base_name="${filename%.*}"
        extension="${filename##*.}"
        counter=1
        
        while [ -f "${TARGET_DIR}/${base_name}_${counter}.${extension}" ]; do
            counter=$((counter + 1))
        done
        
        if [ "$base_name" = "$extension" ]; then
            # No extension case
            target_path="${TARGET_DIR}/${base_name}_${counter}"
            new_filename="${base_name}_${counter}"
        else
            target_path="${TARGET_DIR}/${base_name}_${counter}.${extension}"
            new_filename="${base_name}_${counter}.${extension}"
        fi
        
        echo "  → RENAMED TO: $new_filename"
    else
        echo "  → MOVED TO: $filename"
    fi
    
    # Move the file
    if [ "$DRY_RUN" = false ]; then
        if mv "$file" "$target_path"; then
            moved_count=$((moved_count + 1))
        else
            echo "  → ERROR: Failed to move file"
            skipped_count=$((skipped_count + 1))
        fi
    else
        moved_count=$((moved_count + 1))
    fi
    
done < <(find "$SOURCE_DIR" -type f -not -path "$TARGET_DIR/*" -print0)

echo ""
echo "========================================"
echo "Summary:"
echo "  Files $([ "$DRY_RUN" = true ] && echo "would be ")moved: $moved_count"
echo "  Files skipped/errors: $skipped_count"
echo "  Total processed: $total_count"

# Clean up empty directories (only if not dry run)
if [ "$DRY_RUN" = false ] && [ $moved_count -gt 0 ]; then
    echo ""
    echo "Cleaning up empty directories..."
    
    # Find and remove empty directories, excluding target directory
    while IFS= read -r -d '' dir; do
        if [ "$dir" != "$TARGET_DIR" ] && [ "$dir" != "$SOURCE_DIR" ]; then
            relative_dir=$(realpath --relative-to="$SOURCE_DIR" "$dir")
            echo "  Removing empty directory: $relative_dir"
            rmdir "$dir" 2>/dev/null || echo "  Could not remove directory: $relative_dir"
        fi
    done < <(find "$SOURCE_DIR" -type d -empty -print0)
fi

echo ""
echo "Done!"
