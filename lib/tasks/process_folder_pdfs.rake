namespace :pdf do
  desc "Process all PDF files from a specified folder"
  task :process_folder, [:folder_path] => :environment do |task, args|
    folder_path = args[:folder_path]
    
    if folder_path.blank?
      puts "Please provide a folder path. Usage: rails pdf:process_folder['/path/to/pdf/folder']"
      exit
    end
    
    unless Dir.exist?(folder_path)
      puts "Error: Folder '#{folder_path}' does not exist"
      exit
    end
    
    # Find all PDF files in the folder
    pdf_files = Dir.glob(File.join(folder_path, "*.pdf"))
    
    if pdf_files.empty?
      puts "No PDF files found in '#{folder_path}'"
      exit
    end
    
    puts "Found #{pdf_files.length} PDF file(s) to process..."
    puts "Starting batch processing...\n"
    
    processed_count = 0
    error_count = 0
    
    pdf_files.each_with_index do |file_path, index|
      begin
        filename = File.basename(file_path)
        puts "[#{index + 1}/#{pdf_files.length}] Processing: #{filename}"
        
        # Check if file already exists in database
        existing_doc = PdfDocument.find_by(filename: filename)
        if existing_doc
          puts "  ⚠️  Skipping - file already exists in database (ID: #{existing_doc.id})"
          next
        end
        
        # Process the PDF file
        result = PdfFolderProcessorService.new(file_path).process
        
        if result[:success]
          puts "  ✅ Successfully processed and saved (ID: #{result[:pdf_document].id})"
          processed_count += 1
        else
          puts "  ❌ Error: #{result[:error]}"
          error_count += 1
        end
        
      rescue => e
        puts "  ❌ Unexpected error: #{e.message}"
        error_count += 1
      end
      
      puts "" # Empty line for better readability
    end
    
    puts "="*50
    puts "Batch processing completed!"
    puts "Total files: #{pdf_files.length}"
    puts "Successfully processed: #{processed_count}"
    puts "Errors: #{error_count}"
    puts "Skipped (already exist): #{pdf_files.length - processed_count - error_count}"
    puts "="*50
  end
  
  desc "Show processing status for a folder"
  task :check_folder, [:folder_path] => :environment do |task, args|
    folder_path = args[:folder_path]
    
    if folder_path.blank?
      puts "Please provide a folder path. Usage: rails pdf:check_folder['/path/to/pdf/folder']"
      exit
    end
    
    unless Dir.exist?(folder_path)
      puts "Error: Folder '#{folder_path}' does not exist"
      exit
    end
    
    pdf_files = Dir.glob(File.join(folder_path, "*.pdf"))
    processed_files = []
    unprocessed_files = []
    
    pdf_files.each do |file_path|
      filename = File.basename(file_path)
      if PdfDocument.exists?(filename: filename)
        processed_files << filename
      else
        unprocessed_files << filename
      end
    end
    
    puts "Folder: #{folder_path}"
    puts "Total PDF files: #{pdf_files.length}"
    puts "Already processed: #{processed_files.length}"
    puts "Not yet processed: #{unprocessed_files.length}"
    
    if unprocessed_files.any?
      puts "\nUnprocessed files:"
      unprocessed_files.each { |file| puts "  - #{file}" }
    end
  end
end
