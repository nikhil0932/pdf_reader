git #!/usr/bin/env ruby

# Test script to demonstrate file organization features
# This script simulates the file organization functionality

require 'fileutils'

def organize_files_demo(folder_path)
  puts "File Organization Demo"
  puts "====================="
  puts "Folder: #{folder_path}"
  puts ""
  
  unless Dir.exist?(folder_path)
    puts "Error: Folder does not exist"
    return
  end
  
  # Find PDF files
  pdf_files = Dir.glob(File.join(folder_path, "*.pdf"))
  
  if pdf_files.empty?
    puts "No PDF files found in folder"
    return
  end
  
  # Create organization folders
  processed_folder = File.join(folder_path, 'processed')
  errors_folder = File.join(folder_path, 'errors')
  
  puts "Creating organization folders..."
  FileUtils.mkdir_p(processed_folder) unless Dir.exist?(processed_folder)
  FileUtils.mkdir_p(errors_folder) unless Dir.exist?(errors_folder)
  puts "  ✓ Created: #{processed_folder}"
  puts "  ✓ Created: #{errors_folder}"
  puts ""
  
  puts "Found #{pdf_files.count} PDF files:"
  pdf_files.each_with_index do |file, index|
    filename = File.basename(file)
    puts "  #{index + 1}. #{filename}"
  end
  puts ""
  
  puts "File organization simulation (dry run):"
  pdf_files.each_with_index do |file, index|
    filename = File.basename(file)
    
    # Simulate processing status check
    # In real implementation, this would check the database
    case index % 3
    when 0
      puts "  #{filename} → Would move to 'processed' folder (successfully processed)"
    when 1  
      puts "  #{filename} → Would move to 'errors' folder (processing errors)"
    when 2
      puts "  #{filename} → Would stay in main folder (not processed yet)"
    end
  end
  
  puts ""
  puts "Demo completed! In actual usage:"
  puts "  - Files would be moved based on their processing status in the database"
  puts "  - Use: rails pdfs:organize_files[#{folder_path}]"
  puts "  - Use: rails pdfs:process_folder[#{folder_path},true,true] for automatic organization"
end

# Command line usage
if ARGV.empty?
  puts "Usage: ruby #{$0} FOLDER_PATH"
  puts "Example: ruby #{$0} /path/to/pdf/folder"
  exit 1
end

organize_files_demo(ARGV[0])
