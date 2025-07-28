namespace :pdfs do
  desc "Process all PDF files from a given folder"
  task :process_folder, [:folder_path] => :environment do |task, args|
    folder_path = args[:folder_path]
    
    if folder_path.blank?
      puts "Usage: rails pdfs:process_folder[/path/to/folder]"
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
    
    puts "Found #{pdf_files.count} PDF files to process"
    
    processed = 0
    errors = 0
    
    pdf_files.each_with_index do |pdf_path, index|
      begin
        filename = File.basename(pdf_path)
        puts "[#{index + 1}/#{pdf_files.count}] Processing: #{filename}"
        
        # Check if this file has already been processed
        existing_doc = PdfDocument.find_by(title: filename)
        if existing_doc
          puts "  Skipping - already exists in database"
          next
        end
        
        # Create new PDF document record
        pdf_document = PdfDocument.new(
          title: filename,
          uploaded_at: Time.current
        )
        
        # Attach the PDF file
        pdf_document.file.attach(
          io: File.open(pdf_path),
          filename: filename,
          content_type: 'application/pdf'
        )
        
        if pdf_document.save
          # Process the PDF immediately (synchronously for batch processing)
          process_pdf_file(pdf_document, pdf_path)
          processed += 1
          puts "  ✓ Successfully processed and saved"
        else
          puts "  ✗ Failed to save: #{pdf_document.errors.full_messages.join(', ')}"
          errors += 1
        end
        
      rescue => e
        puts "  ✗ Error processing #{File.basename(pdf_path)}: #{e.message}"
        errors += 1
      end
    end
    
    puts "\nProcessing complete:"
    puts "  Successfully processed: #{processed}"
    puts "  Errors: #{errors}"
    puts "  Total files: #{pdf_files.count}"
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
  
  private
  
  def process_pdf_file(pdf_document, pdf_path)
    require 'pdf-reader'
    
    begin
      # Extract text from PDF
      reader = PDF::Reader.new(pdf_path)
      content = ""
      reader.pages.each do |page|
        content += page.text + "\n"
      end
      
      # Update the content
      pdf_document.update_column(:content, content)
      
      # Extract filtered data
      extractor_service = PdfDataExtractorService.new(content)
      filtered_data = extractor_service.extract_all_data
      
      # Update filtered data fields
      pdf_document.update_columns(
        licensor: filtered_data[:licensor],
        licensee: filtered_data[:licensee],
        address: filtered_data[:address],
        agreement_date: filtered_data[:agreement_date],
        agreement_period: filtered_data[:agreement_period],
        filtered_data: filtered_data[:filtered_data],
        processed_at: Time.current
      )
      
    rescue => e
      error_message = "Error processing PDF: #{e.message}"
      pdf_document.update_column(:content, error_message)
      raise e
    end
  end
end
