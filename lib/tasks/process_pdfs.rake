namespace :pdfs do
  desc "Process all PDF files from a given folder"
  task :process_folder, [:folder_path, :move_processed, :move_errors] => :environment do |task, args|
    folder_path = args[:folder_path]
    move_processed = args[:move_processed] == 'true'
    move_errors = args[:move_errors] == 'true'
    
    if folder_path.blank?
      puts "Usage: rails pdfs:process_folder[/path/to/folder,move_processed,move_errors]"
      puts "  folder_path: Path to folder containing PDF files"
      puts "  move_processed: true/false - Move successfully processed files to 'processed' subfolder"
      puts "  move_errors: true/false - Move files with errors to 'errors' subfolder"
      puts "Example: rails pdfs:process_folder[/path/to/pdfs,true,true]"
      exit 1
    end
    
    unless Dir.exist?(folder_path)
      puts "Error: Folder '#{folder_path}' does not exist"
      exit 1
    end
    
    # Create subfolders if moving files is enabled
    processed_folder = File.join(folder_path, 'processed')
    errors_folder = File.join(folder_path, 'errors')
    
    if move_processed
      FileUtils.mkdir_p(processed_folder) unless Dir.exist?(processed_folder)
      puts "Will move successfully processed files to: #{processed_folder}"
    end
    
    if move_errors
      FileUtils.mkdir_p(errors_folder) unless Dir.exist?(errors_folder)
      puts "Will move files with errors to: #{errors_folder}"
    end
    
    pdf_files = Dir.glob(File.join(folder_path, "*.pdf"))
    
    if pdf_files.empty?
      puts "No PDF files found in '#{folder_path}'"
      exit 0
    end
    
    puts "Found #{pdf_files.count} PDF files to process"
    puts ""
    
    processed = 0
    errors = 0
    moved_processed = 0
    moved_errors = 0
    
    pdf_files.each_with_index do |pdf_path, index|
      filename = File.basename(pdf_path)
      file_moved = false
      
      begin
        puts "[#{index + 1}/#{pdf_files.count}] Processing: #{filename}"
        
        # Check if this file has already been processed by filename
        existing_doc = PdfDocument.find_by(filename: filename)
        if existing_doc
          puts "  Skipping - already exists in database"
          
          # Move to processed folder if requested
          if move_processed && !file_moved
            move_file(pdf_path, processed_folder, filename)
            moved_processed += 1
            file_moved = true
            puts "  → Moved to processed folder"
          end
          next
        end
        
        # Create new PDF document record
        pdf_document = PdfDocument.new(
          title: filename,
          filename: filename,
          uploaded_at: Time.current
        )
        
        # Process the PDF file
        success = process_pdf_file(pdf_document, pdf_path)
        
        if success && pdf_document.save
          processed += 1
          puts "  ✓ Successfully processed and saved"
          
          # Move to processed folder if requested
          if move_processed && !file_moved
            move_file(pdf_path, processed_folder, filename)
            moved_processed += 1
            file_moved = true
            puts "  → Moved to processed folder"
          end
        else
          error_msg = pdf_document.errors.any? ? pdf_document.errors.full_messages.join(', ') : "Processing failed"
          puts "  ✗ Failed to save: #{error_msg}"
          errors += 1
          
          # Move to errors folder if requested
          if move_errors && !file_moved
            move_file(pdf_path, errors_folder, filename)
            moved_errors += 1
            file_moved = true
            puts "  → Moved to errors folder"
          end
        end
        
      rescue => e
        puts "  ✗ Error processing #{filename}: #{e.message}"
        errors += 1
        
        # Move to errors folder if requested
        if move_errors && !file_moved
          move_file(pdf_path, errors_folder, filename)
          moved_errors += 1
          file_moved = true
          puts "  → Moved to errors folder"
        end
      end
    end
    
    puts "\nProcessing complete:"
    puts "  Successfully processed: #{processed}"
    puts "  Errors: #{errors}"
    puts "  Total files: #{pdf_files.count}"
    
    if move_processed || move_errors
      puts "\nFile movements:"
      puts "  Moved to processed folder: #{moved_processed}" if move_processed
      puts "  Moved to errors folder: #{moved_errors}" if move_errors
    end
  end
  
  desc "Reprocess all existing PDF documents"
  task :reprocess_all => :environment do
    pdf_documents = PdfDocument.all
    
    if pdf_documents.empty?
      puts "No PDF documents found in database"
      exit 0
    end
    
    puts "Found #{pdf_documents.count} PDF documents to reprocess"
    
    processed = 0
    errors = 0
    
    pdf_documents.each_with_index do |pdf_document, index|
      begin
        puts "[#{index + 1}/#{pdf_documents.count}] Reprocessing: #{pdf_document.title}"
        
        if pdf_document.file.attached?
          pdf_path = ActiveStorage::Blob.service.path_for(pdf_document.file.key)
          process_pdf_file(pdf_document, pdf_path)
          processed += 1
          puts "  ✓ Successfully reprocessed"
        else
          puts "  ✗ No file attached"
          errors += 1
        end
        
      rescue => e
        puts "  ✗ Error reprocessing #{pdf_document.title}: #{e.message}"
        errors += 1
      end
    end
    
    puts "\nReprocessing complete:"
    puts "  Successfully processed: #{processed}"
    puts "  Errors: #{errors}"
    puts "  Total documents: #{pdf_documents.count}"
  end
  
  desc "Organize existing PDF files based on processing status"
  task :organize_files, [:folder_path] => :environment do |task, args|
    folder_path = args[:folder_path]
    
    if folder_path.blank?
      puts "Usage: rails pdfs:organize_files[/path/to/folder]"
      puts "This will organize files in the folder based on their processing status:"
      puts "  - Successfully processed files → processed/ subfolder"
      puts "  - Files with errors → errors/ subfolder"
      puts "  - Unprocessed files → remain in main folder"
      exit 1
    end
    
    unless Dir.exist?(folder_path)
      puts "Error: Folder '#{folder_path}' does not exist"
      exit 1
    end
    
    pdf_files = Dir.glob(File.join(folder_path, "*.pdf"))
    
    if pdf_files.empty?
      puts "No PDF files found in '#{folder_path}'"
      exit 0
    end
    
    # Create subfolders
    processed_folder = File.join(folder_path, 'processed')
    errors_folder = File.join(folder_path, 'errors')
    
    FileUtils.mkdir_p(processed_folder) unless Dir.exist?(processed_folder)
    FileUtils.mkdir_p(errors_folder) unless Dir.exist?(errors_folder)
    
    puts "Organizing #{pdf_files.count} PDF files..."
    puts "Processed files will be moved to: #{processed_folder}"
    puts "Files with errors will be moved to: #{errors_folder}"
    puts ""
    
    moved_processed = 0
    moved_errors = 0
    unprocessed = 0
    
    pdf_files.each_with_index do |pdf_path, index|
      filename = File.basename(pdf_path)
      puts "[#{index + 1}/#{pdf_files.count}] Checking: #{filename}"
      
      # Find document in database
      pdf_document = PdfDocument.find_by(filename: filename)
      
      if pdf_document.nil?
        puts "  → Not processed yet - keeping in main folder"
        unprocessed += 1
      elsif pdf_document.content.present? && !pdf_document.content.include?("Error processing")
        puts "  → Successfully processed - moving to processed folder"
        move_file(pdf_path, processed_folder, filename)
        moved_processed += 1
      else
        puts "  → Has processing errors - moving to errors folder"
        move_file(pdf_path, errors_folder, filename)
        moved_errors += 1
      end
    end
    
    puts "\nOrganization complete:"
    puts "  Moved to processed folder: #{moved_processed}"
    puts "  Moved to errors folder: #{moved_errors}"
    puts "  Left unprocessed: #{unprocessed}"
    puts "  Total files: #{pdf_files.count}"
  end
  
  private
  
  def process_pdf_file(pdf_document, pdf_path)
    require 'pdf-reader'
    
    begin
      # Extract text from PDF
      reader = PDF::Reader.new(pdf_path)
      content = ""
      page_count = 0
      
      reader.pages.each do |page|
        content += page.text + "\n"
        page_count += 1
      end
      
      # Update the content and page count
      pdf_document.content = content
      pdf_document.page_count = page_count
      
      # Extract filtered data using the service
      extractor_service = PdfDataExtractorService.new(content)
      filtered_data = extractor_service.extract_all_data
      
      # Update filtered data fields
      pdf_document.licensor = filtered_data[:licensor]
      pdf_document.licensee = filtered_data[:licensee]
      pdf_document.address = filtered_data[:address]
      pdf_document.agreement_date = filtered_data[:agreement_date]
      pdf_document.agreement_period = filtered_data[:agreement_period]
      pdf_document.start_date = filtered_data[:start_date]
      pdf_document.end_date = filtered_data[:end_date]
      pdf_document.filtered_data = filtered_data[:filtered_data]
      pdf_document.processed_at = Time.current
      
      return true
      
    rescue => e
      error_message = "Error processing PDF: #{e.message}"
      pdf_document.content = error_message
      puts "    Error details: #{e.message}"
      return false
    end
  end
  
  def move_file(source_path, destination_folder, filename)
    destination_path = File.join(destination_folder, filename)
    
    # Handle filename conflicts
    if File.exist?(destination_path)
      base_name = File.basename(filename, File.extname(filename))
      extension = File.extname(filename)
      counter = 1
      
      while File.exist?(destination_path)
        new_filename = "#{base_name}_#{counter}#{extension}"
        destination_path = File.join(destination_folder, new_filename)
        counter += 1
      end
    end
    
    FileUtils.mv(source_path, destination_path)
  rescue => e
    puts "    Warning: Could not move file to #{destination_folder}: #{e.message}"
  end
end
