#!/bin/bash

# Batch PDF Processor Script
# This script provides an easy interface to process PDF files from folders

PDF_EXTRACTOR_DIR="/home/nikhil/pdf_extractor"

# Function to display usage information
show_usage() {
    echo "PDF Folder Processor - Batch process PDF files into database"
    echo ""
    echo "Usage: $0 <command> [folder_path]"
    echo ""
    echo "Commands:"
    echo "  process <folder_path>  - Process all PDF files in the specified folder"
    echo "  check <folder_path>    - Check processing status of files in folder"
    echo "  status                 - Show database statistics"
    echo "  help                   - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 process /home/user/documents/pdfs"
    echo "  $0 check /home/user/documents/pdfs"
    echo "  $0 status"
    echo ""
}

# Function to show database statistics
show_status() {
    echo "Database Statistics:"
    echo "==================="
    cd "$PDF_EXTRACTOR_DIR"
    rails runner "
    total = PdfDocument.count
    with_licensor = PdfDocument.where.not(licensor: [nil, '']).count
    with_licensee = PdfDocument.where.not(licensee: [nil, '']).count
    with_date = PdfDocument.where.not(agreement_date: nil).count
    
    puts \"Total PDF documents: #{total}\"
    puts \"Documents with licensor: #{with_licensor}\"
    puts \"Documents with licensee: #{with_licensee}\"
    puts \"Documents with agreement date: #{with_date}\"
    
    if total > 0
        puts \"\"
        puts \"Recent uploads:\"
        PdfDocument.order(created_at: :desc).limit(5).each do |doc|
            puts \"  - #{doc.filename} (#{doc.created_at.strftime('%Y-%m-%d %H:%M')})\"
        end
    end
    "
}

# Function to process folder using Rails rake task
process_folder() {
    local folder_path="$1"
    
    if [[ ! -d "$folder_path" ]]; then
        echo "Error: Folder '$folder_path' does not exist"
        exit 1
    fi
    
    echo "Processing PDF files from: $folder_path"
    echo "========================================"
    
    cd "$PDF_EXTRACTOR_DIR"
    rails pdf:process_folder["$folder_path"]
}

# Function to check folder status
check_folder() {
    local folder_path="$1"
    
    if [[ ! -d "$folder_path" ]]; then
        echo "Error: Folder '$folder_path' does not exist"
        exit 1
    fi
    
    echo "Checking folder status: $folder_path"
    echo "===================================="
    
    cd "$PDF_EXTRACTOR_DIR"
    rails pdf:check_folder["$folder_path"]
}

# Main script logic
case "$1" in
    "process")
        if [[ -z "$2" ]]; then
            echo "Error: Please specify a folder path"
            echo "Usage: $0 process <folder_path>"
            exit 1
        fi
        process_folder "$2"
        ;;
    
    "check")
        if [[ -z "$2" ]]; then
            echo "Error: Please specify a folder path"
            echo "Usage: $0 check <folder_path>"
            exit 1
        fi
        check_folder "$2"
        ;;
    
    "status")
        show_status
        ;;
    
    "help"|"--help"|"-h")
        show_usage
        ;;
    
    "")
        echo "Error: Please specify a command"
        show_usage
        exit 1
        ;;
    
    *)
        echo "Error: Unknown command '$1'"
        show_usage
        exit 1
        ;;
esac
