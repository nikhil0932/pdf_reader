namespace :pdfs do
  desc "Process all PDF files from a given folder"
  task :process_folder, [:folder_path, :move_processed, :move_errors, :skip_similar_dates] => :environment do |task, args|
    folder_path = args[:folder_path]
    move_processed = args[:move_processed] == 'true'
    move_errors = args[:move_errors] == 'true'
    skip_similar_dates = args[:skip_similar_dates] != 'false' # Default to true unless explicitly set to false
    
    if folder_path.blank?
      puts "Usage: rails pdfs:process_folder[/path/to/folder,move_processed,move_errors,skip_similar_dates]"
      puts "  folder_path: Path to folder containing PDF files"
      puts "  move_processed: true/false - Move successfully processed files to 'processed' subfolder"
      puts "  move_errors: true/false - Move files with errors to 'errors' subfolder"
      puts "  skip_similar_dates: true/false - Skip files with similar agreement dates (default: true)"
      puts "Example: rails pdfs:process_folder[/path/to/pdfs,true,true,true]"
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
    
    puts "Skip similar dates: #{skip_similar_dates ? 'Yes' : 'No'}"
    
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
          puts "  Skipping - already exists in database (filename match)"
          
          # Move to processed folder if requested
          if move_processed && !file_moved
            move_file(pdf_path, processed_folder, filename)
            moved_processed += 1
            file_moved = true
            puts "  → Moved to processed folder"
          end
          next
        end
        
        # Create new PDF document record for processing
        pdf_document = PdfDocument.new(
          title: filename,
          filename: filename,
          uploaded_at: Time.current
        )
        
        # Process the PDF file to extract data
        success = process_pdf_file(pdf_document, pdf_path)
        
        # Check for duplicate records based on extracted data (licensor, licensee, start_date, end_date)
        if success && pdf_document.licensor.present? && pdf_document.licensee.present? && 
           (pdf_document.start_date.present? || pdf_document.end_date.present?)
          
          duplicate = find_duplicate_record(pdf_document)
          if duplicate
            puts "  Skipping - duplicate record found (licensor: #{pdf_document.licensor}, licensee: #{pdf_document.licensee}, dates: #{pdf_document.start_date} to #{pdf_document.end_date})"
            puts "    → Matches existing record ID: #{duplicate.id} (#{duplicate.filename})"
            
            # Move to processed folder if requested (since it's a known duplicate)
            if move_processed && !file_moved
              move_file(pdf_path, processed_folder, filename)
              moved_processed += 1
              file_moved = true
              puts "  → Moved to processed folder"
            end
            next
          end
        end
        
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
  
  desc "Find and remove duplicate PDF documents based on licensor, licensee, and dates"
  task :remove_duplicates => :environment do
    puts "Finding duplicate PDF documents..."
    puts "Checking for duplicates based on: licensor, licensee, start_date, end_date"
    puts ""
    
    total_documents = PdfDocument.count
    puts "Total documents in database: #{total_documents}"
    
    if total_documents == 0
      puts "No documents found in database"
      exit 0
    end
    
    duplicates_found = []
    kept_documents = []
    
    # Group documents by licensor, licensee, start_date, end_date
    PdfDocument.all.group_by do |doc|
      [
        doc.licensor&.strip&.downcase,
        doc.licensee&.strip&.downcase,
        doc.start_date,
        doc.end_date
      ]
    end.each do |key, documents|
      # Skip groups with only one document
      next if documents.length == 1
      
      # Skip groups where key fields are missing
      licensor, licensee, start_date, end_date = key
      next if licensor.blank? || licensee.blank? || (start_date.blank? && end_date.blank?)
      
      puts "Found duplicate group:"
      puts "  Licensor: #{documents.first.licensor}"
      puts "  Licensee: #{documents.first.licensee}"
      puts "  Start Date: #{start_date || 'N/A'}"
      puts "  End Date: #{end_date || 'N/A'}"
      puts "  Documents (#{documents.length}):"
      
      # Sort by created_at to keep the oldest one
      sorted_docs = documents.sort_by(&:created_at)
      keep_doc = sorted_docs.first
      duplicate_docs = sorted_docs[1..-1]
      
      puts "    KEEPING: #{keep_doc.filename} (ID: #{keep_doc.id}, Created: #{keep_doc.created_at.strftime('%Y-%m-%d %H:%M')})"
      kept_documents << keep_doc
      
      duplicate_docs.each do |doc|
        puts "    REMOVING: #{doc.filename} (ID: #{doc.id}, Created: #{doc.created_at.strftime('%Y-%m-%d %H:%M')})"
        duplicates_found << doc
      end
      puts ""
    end
    
    if duplicates_found.empty?
      puts "✅ No duplicates found!"
    else
      puts "Summary:"
      puts "  Duplicate documents found: #{duplicates_found.length}"
      puts "  Documents to keep: #{kept_documents.length}"
      puts ""
      
      print "Do you want to remove these #{duplicates_found.length} duplicate documents? (y/N): "
      response = STDIN.gets.chomp.downcase
      
      if response == 'y' || response == 'yes'
        removed_count = 0
        duplicates_found.each do |doc|
          begin
            doc.destroy
            removed_count += 1
            puts "  ✓ Removed: #{doc.filename}"
          rescue => e
            puts "  ✗ Failed to remove #{doc.filename}: #{e.message}"
          end
        end
        
        puts ""
        puts "✅ Cleanup complete!"
        puts "  Documents removed: #{removed_count}"
        puts "  Documents remaining: #{PdfDocument.count}"
      else
        puts "Cleanup cancelled. No documents were removed."
      end
    end
  end
  
  desc "Delete PDF documents with empty key fields (licensor, licensee, start_date, end_date)"
  task :delete_empty_records => :environment do
    puts "Finding PDF documents with empty key fields..."
    puts "Checking for records where licensor, licensee, start_date, and end_date are all empty"
    puts ""
    
    # Find records where all key fields are empty
    empty_records = PdfDocument.where(
      "(licensor IS NULL OR licensor = '') AND " \
      "(licensee IS NULL OR licensee = '') AND " \
      "start_date IS NULL AND " \
      "end_date IS NULL"
    )
    
    total_count = PdfDocument.count
    empty_count = empty_records.count
    
    puts "Total documents in database: #{total_count}"
    puts "Documents with empty key fields: #{empty_count}"
    
    if empty_count == 0
      puts "✅ No records found with empty key fields!"
      exit 0
    end
    
    puts ""
    puts "Records to be deleted:"
    puts "-" * 60
    
    empty_records.limit(10).each do |record|
      puts "ID: #{record.id} | Filename: #{record.filename || 'N/A'} | Created: #{record.created_at.strftime('%Y-%m-%d %H:%M')}"
    end
    
    if empty_count > 10
      puts "... and #{empty_count - 10} more records"
    end
    
    puts ""
    print "Do you want to delete these #{empty_count} records with empty key fields? (y/N): "
    response = STDIN.gets.chomp.downcase
    
    if response == 'y' || response == 'yes'
      deleted_count = 0
      
      empty_records.find_each do |record|
        begin
          filename = record.filename || "ID #{record.id}"
          record.destroy
          deleted_count += 1
          puts "  ✓ Deleted: #{filename}"
        rescue => e
          puts "  ✗ Failed to delete #{filename}: #{e.message}"
        end
      end
      
      puts ""
      puts "✅ Cleanup complete!"
      puts "  Records deleted: #{deleted_count}"
      puts "  Records remaining: #{PdfDocument.count}"
    else
      puts "Deletion cancelled. No records were removed."
    end
  end
  
  desc "Clean and re-extract data from existing PDF documents with parsing issues"
  task :cleanup_data => :environment do
    puts "PDF Data Cleanup and Re-extraction"
    puts "=" * 40
    puts "Finding records with problematic data..."
    
    # Find records where licensor contains the problematic schedule text
    problematic_records = PdfDocument.where("licensor LIKE ?", "%equally . SCHEDULE I%")
                                    .or(PdfDocument.where("licensor LIKE ?", "%SCHEDULE I (Being the correct description%"))
    
    total_records = PdfDocument.count
    problematic_count = problematic_records.count
    
    puts "Total records in database: #{total_records}"
    puts "Records with parsing issues: #{problematic_count}"
    
    if problematic_count == 0
      puts "✅ No problematic records found!"
      exit 0
    end
    
    puts ""
    puts "Sample problematic records:"
    problematic_records.limit(3).each do |record|
      puts "  ID: #{record.id} | File: #{record.filename}"
      puts "  Licensor: #{record.licensor&.truncate(80)}"
      puts ""
    end
    
    print "Proceed with cleanup? This will re-extract data from content. (y/N): "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'y' || response == 'yes'
      puts "Cleanup cancelled."
      exit 0
    end
    
    puts ""
    puts "Processing records..."
    
    updated_count = 0
    error_count = 0
    skipped_count = 0
    
    problematic_records.find_each.with_index do |record, index|
      puts "[#{index + 1}/#{problematic_count}] #{record.filename}"
      
      begin
        if record.content.blank?
          puts "  ⚠️  No content - skipping"
          skipped_count += 1
          next
        end
        
        # Store old values for comparison
        old_licensor = record.licensor
        old_licensee = record.licensee
        old_address = record.address
        
        # Re-extract data from content
        extracted_data = clean_extract_data(record.content)
        
        # Update record with cleaned data
        record.update!(
          licensor: extracted_data[:licensor],
          licensee: extracted_data[:licensee], 
          address: extracted_data[:address],
          start_date: extracted_data[:start_date],
          end_date: extracted_data[:end_date],
          agreement_period: extracted_data[:agreement_period],
          document_type: extracted_data[:document_type]
        )
        
        puts "  ✅ Updated"
        puts "    Licensor: #{extracted_data[:licensor]&.truncate(50)}"
        puts "    Licensee: #{extracted_data[:licensee]&.truncate(50)}"
        
        updated_count += 1
        
      rescue => e
        puts "  ❌ Error: #{e.message}"
        error_count += 1
      end
    end
    
    puts ""
    puts "Cleanup Results:"
    puts "  Updated: #{updated_count}"
    puts "  Skipped: #{skipped_count}"
    puts "  Errors: #{error_count}"
    puts "  Total: #{problematic_count}"
  end
  
  desc "Count records with blank licensor/licensee fields"
  task :count_blank_records => :environment do
    puts "Counting records with blank licensor/licensee fields..."
    puts "=" * 50
    
    # Count total records
    total_count = PdfDocument.count
    puts "Total records in database: #{total_count}"
    
    # Count records with blank licensor
    blank_licensor_count = PdfDocument.where("licensor IS NULL OR licensor = ''").count
    puts "Records with blank licensor: #{blank_licensor_count}"
    
    # Count records with blank licensee
    blank_licensee_count = PdfDocument.where("licensee IS NULL OR licensee = ''").count
    puts "Records with blank licensee: #{blank_licensee_count}"
    
    # Count records with both blank
    both_blank_count = PdfDocument.where("(licensor IS NULL OR licensor = '') AND (licensee IS NULL OR licensee = '')").count
    puts "Records with both licensor and licensee blank: #{both_blank_count}"
    
    puts ""
    puts "Sample records with blank licensor:"
    puts "-" * 40
    PdfDocument.where("licensor IS NULL OR licensor = ''").limit(5).each do |record|
      puts "ID: #{record.id} | File: #{record.filename || 'N/A'}"
      puts "  Licensor: '#{record.licensor}' | Licensee: '#{record.licensee}'"
      puts "  Content preview: #{record.content&.truncate(100)}"
      puts ""
    end
    
    puts "Sample records with blank licensee:"
    puts "-" * 40
    PdfDocument.where("licensee IS NULL OR licensee = ''").limit(5).each do |record|
      puts "ID: #{record.id} | File: #{record.filename || 'N/A'}"
      puts "  Licensor: '#{record.licensor}' | Licensee: '#{record.licensee}'"
      puts "  Content preview: #{record.content&.truncate(100)}"
      puts ""
    end
  end

  desc "Update records with blank licensor/licensee using enhanced extraction"
  task :update_blank_records => :environment do
    puts "PDF Data Update for Blank Records"
    puts "=" * 40
    puts "Finding records with blank licensor and/or licensee..."
    
    # Find records where licensor or licensee are blank but content exists
    blank_records = PdfDocument.where(
      "(licensor IS NULL OR licensor = '') OR (licensee IS NULL OR licensee = '')"
    ).where.not(content: [nil, ''])
    
    total_records = PdfDocument.count
    blank_count = blank_records.count
    
    puts "Total records in database: #{total_records}"
    puts "Records with blank licensor/licensee: #{blank_count}"
    
    if blank_count == 0
      puts "✅ No records with blank licensor/licensee found!"
      exit 0
    end
    
    puts ""
    puts "Sample records to be updated:"
    blank_records.limit(5).each do |record|
      puts "  ID: #{record.id} | File: #{record.filename}"
      puts "  Current - Licensor: '#{record.licensor}' | Licensee: '#{record.licensee}'"
    end
    
    puts ""
    print "Proceed with updating #{blank_count} records? (y/N): "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'y' || response == 'yes'
      puts "Update cancelled."
      exit 0
    end
    
    puts ""
    puts "Processing records..."
    
    updated_count = 0
    error_count = 0
    skipped_count = 0
    improved_count = 0
    
    blank_records.find_each.with_index do |record, index|
      puts "[#{index + 1}/#{blank_count}] #{record.filename}"
      
      begin
        if record.content.blank?
          puts "  ⚠️  No content - skipping"
          skipped_count += 1
          next
        end
        
        # Store old values for comparison
        old_licensor = record.licensor
        old_licensee = record.licensee
        
        # Apply enhanced extraction using the clean_extract_data method
        extracted_data = clean_extract_data(record.content)
        
        # Check if we found any new data
        new_licensor = extracted_data[:licensor]
        new_licensee = extracted_data[:licensee]
        
        has_improvements = false
        
        # Update only if we found better data
        if old_licensor.blank? && new_licensor.present?
          record.licensor = new_licensor
          has_improvements = true
        end
        
        if old_licensee.blank? && new_licensee.present?
          record.licensee = new_licensee
          has_improvements = true
        end
        
        if has_improvements
          record.save!
          puts "  ✅ Updated"
          puts "    New Licensor: #{new_licensor&.truncate(50)}" if old_licensor.blank? && new_licensor.present?
          puts "    New Licensee: #{new_licensee&.truncate(50)}" if old_licensee.blank? && new_licensee.present?
          improved_count += 1
        else
          puts "  ➡️  No improvement found"
        end
        
        updated_count += 1
        
      rescue => e
        puts "  ❌ Error: #{e.message}"
        error_count += 1
      end
    end
    
    puts ""
    puts "Update Results:"
    puts "  Processed: #{updated_count}"
    puts "  Improved: #{improved_count}"
    puts "  Skipped: #{skipped_count}"
    puts "  Errors: #{error_count}"
    puts "  Total: #{blank_count}"
    
    # Show summary after update
    final_blank_count = PdfDocument.where(
      "(licensor IS NULL OR licensor = '') AND (licensee IS NULL OR licensee = '')"
    ).count
    
    puts ""
    puts "Final Summary:"
    puts "  Records with both licensor and licensee still blank: #{final_blank_count}"
    puts "  Improvement: #{blank_records.where("(licensor IS NULL OR licensor = '') AND (licensee IS NULL OR licensee = '')").count - final_blank_count} records now have data"
  end

  desc "Clean up records with 'Photo Thumb Image Digitally' in address field"
  task :clean_photo_thumb_addresses => :environment do
    puts "Finding records with 'Photo Thumb Image Digitally' in address field..."
    puts "=" * 60
    
    # Find records where address contains the problematic text
    problematic_records = PdfDocument.where("address LIKE ?", "%Photo Thumb Image Digitally%")
    
    total_records = PdfDocument.count
    problematic_count = problematic_records.count
    
    puts "Total records in database: #{total_records}"
    puts "Records with 'Photo Thumb Image Digitally' in address: #{problematic_count}"
    
    if problematic_count == 0
      puts "✅ No records found with 'Photo Thumb Image Digitally' in address!"
      exit 0
    end
    
    puts ""
    puts "Sample problematic records:"
    problematic_records.limit(5).each do |record|
      puts "ID: #{record.id} | File: #{record.filename}"
      puts "  Address: #{record.address&.truncate(100)}"
      puts ""
    end
    
    if problematic_count > 5
      puts "... and #{problematic_count - 5} more records"
    end
    
    puts ""
    puts "This will SET THE ADDRESS FIELD TO BLANK for these records."
    print "Proceed with cleaning #{problematic_count} records? (y/N): "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'y' || response == 'yes'
      puts "Cleanup cancelled."
      exit 0
    end
    
    puts ""
    puts "Processing records..."
    
    updated_count = 0
    error_count = 0
    
    problematic_records.find_each.with_index do |record, index|
      puts "[#{index + 1}/#{problematic_count}] #{record.filename}"
      
      begin
        # Store old address for logging
        old_address = record.address
        
        # Clear the address field
        record.update!(address: nil)
        
        puts "  ✅ Address cleared"
        puts "    Old Address: #{old_address&.truncate(80)}"
        
        updated_count += 1
        
      rescue => e
        puts "  ❌ Error: #{e.message}"
        error_count += 1
      end
    end
    
    puts ""
    puts "Cleanup Results:"
    puts "  Successfully updated: #{updated_count}"
    puts "  Errors: #{error_count}"
    puts "  Total processed: #{problematic_count}"
    
    # Verify cleanup
    remaining_count = PdfDocument.where("address LIKE ?", "%Photo Thumb Image Digitally%").count
    puts ""
    puts "Verification:"
    puts "  Records still containing 'Photo Thumb Image Digitally': #{remaining_count}"
    puts "  ✅ Cleanup #{remaining_count == 0 ? 'completed successfully' : 'partially completed'}!"
  end

  desc "Update addresses from SCHEDULE I section for records with empty addresses"
  task :extract_schedule_addresses => :environment do
    puts "Extracting addresses from SCHEDULE I sections..."
    puts "=" * 50
    
    # Find records where address is empty or contains problematic text, but content has SCHEDULE I
    target_records = PdfDocument.where("content LIKE ?", "%SCHEDULE I%")
                               .where("address IS NULL OR address = '' OR address LIKE ?", "%Photo Thumb Image Digitally%")
    
    total_records = PdfDocument.count
    target_count = target_records.count
    
    puts "Total records in database: #{total_records}"
    puts "Records with SCHEDULE I and empty/problematic addresses: #{target_count}"
    
    if target_count == 0
      puts "✅ No records found that need SCHEDULE I address extraction!"
      exit 0
    end
    
    puts ""
    puts "Sample records to be updated:"
    target_records.limit(5).each do |record|
      puts "  ID: #{record.id} | File: #{record.filename}"
      puts "  Current Address: #{record.address&.truncate(80) || 'EMPTY'}"
    end
    
    puts ""
    print "Proceed with extracting addresses from SCHEDULE I sections? (y/N): "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'y' || response == 'yes'
      puts "Extraction cancelled."
      exit 0
    end
    
    puts ""
    puts "Processing records..."
    
    updated_count = 0
    error_count = 0
    skipped_count = 0
    
    target_records.find_each.with_index do |record, index|
      puts "[#{index + 1}/#{target_count}] #{record.filename}"
      
      begin
        if record.content.blank?
          puts "  ⚠️  No content - skipping"
          skipped_count += 1
          next
        end
        
        # Extract address from SCHEDULE I section
        schedule_pattern = /SCHEDULE\s+I.*?All\s+that\s+constructed\s+portion\s+being.*?(?=IN\s+WITNESS\s+WHEREOF|$)/im
        schedule_match = record.content.match(schedule_pattern)
        
        if schedule_match
          schedule_text = schedule_match[0]
          # Extract the detailed property description
          property_desc_pattern = /All\s+that\s+constructed\s+portion\s+being\s+(.+?)(?=IN\s+WITNESS\s+WHEREOF|$)/im
          desc_match = schedule_text.match(property_desc_pattern)
          
          if desc_match
            new_address = desc_match[1].strip.gsub(/\s+/, ' ')
            
            if new_address.present?
              old_address = record.address
              record.update!(address: new_address)
              
              puts "  ✅ Address extracted from SCHEDULE I"
              puts "    Old: #{old_address&.truncate(50) || 'EMPTY'}"
              puts "    New: #{new_address.truncate(80)}"
              updated_count += 1
            else
              puts "  ➡️  SCHEDULE I found but no valid address extracted"
              skipped_count += 1
            end
          else
            puts "  ➡️  SCHEDULE I found but property description pattern not matched"
            skipped_count += 1
          end
        else
          puts "  ➡️  No SCHEDULE I section found"
          skipped_count += 1
        end
        
      rescue => e
        puts "  ❌ Error: #{e.message}"
        error_count += 1
      end
    end
    
    puts ""
    puts "Extraction Results:"
    puts "  Successfully updated: #{updated_count}"
    puts "  Skipped: #{skipped_count}"
    puts "  Errors: #{error_count}"
    puts "  Total processed: #{target_count}"
  end

  desc "Blank out licensor and licensee fields longer than 200 characters"
  task :blank_long_fields => :environment do
    puts "Starting cleanup of licensor and licensee fields longer than 200 characters..."
    
    # Count records that will be affected
    long_licensor_count = PdfDocument.where('LENGTH(licensor) > 150').count
    long_licensee_count = PdfDocument.where('LENGTH(licensee) > 150').count
    total_affected = PdfDocument.where('LENGTH(licensor) > 150 OR LENGTH(licensee) > 150').count
    
    puts "Records with licensor > 200 chars: #{long_licensor_count}"
    puts "Records with licensee > 200 chars: #{long_licensee_count}"
    puts "Total records that will be modified: #{total_affected}"
    
    if total_affected == 0
      puts "No records found with licensor or licensee fields longer than 200 characters."
      next
    end
    
    print "Do you want to proceed? (y/N): "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'y' || response == 'yes'
      puts "Operation cancelled."
      next
    end
    
    updated_count = 0
    
    # Update records with long licensor fields
    PdfDocument.where('LENGTH(licensor) > 150').find_each do |doc|
      old_licensor = doc.licensor
      doc.update(licensor: '')
      updated_count += 1
      puts "Updated record ID #{doc.id}: Blanked licensor (was #{old_licensor.length} chars)"
    end
    
    # Update records with long licensee fields
    PdfDocument.where('LENGTH(licensee) > 150').find_each do |doc|
      old_licensee = doc.licensee
      doc.update(licensee: '')
      updated_count += 1
      puts "Updated record ID #{doc.id}: Blanked licensee (was #{old_licensee.length} chars)" if doc.licensee != doc.licensor
    end
    
    puts "\nCleanup completed!"
    puts "Total fields blanked: #{updated_count}"
    
    # Verify the cleanup
    remaining_long = PdfDocument.where('LENGTH(licensor) > 150 OR LENGTH(licensee) > 150').count
    puts "Remaining records with long fields: #{remaining_long}"
  end
  
  desc "Blank out licensor and licensee fields that contain only 'Details'"
  task :blank_details_fields => :environment do
    puts "Starting cleanup of licensor and licensee fields containing only 'Details'..."
    
    # Count records that will be affected - looking for exact match or variations
    details_patterns = ['Details', 'details', 'DETAILS', 'Detail', 'detail', 'DETAIL']
    
    licensor_count = 0
    licensee_count = 0
    
    details_patterns.each do |pattern|
      licensor_count += PdfDocument.where(licensor: pattern).count
      licensee_count += PdfDocument.where(licensee: pattern).count
    end
    
    # Also check for fields that are just whitespace + Details + whitespace
    whitespace_details_licensor = PdfDocument.where("TRIM(licensor) IN (?)", details_patterns).count
    whitespace_details_licensee = PdfDocument.where("TRIM(licensee) IN (?)", details_patterns).count
    
    total_affected = PdfDocument.where("TRIM(licensor) IN (?) OR TRIM(licensee) IN (?)", details_patterns, details_patterns).count
    
    puts "Records with licensor = 'Details' (or variations): #{whitespace_details_licensor}"
    puts "Records with licensee = 'Details' (or variations): #{whitespace_details_licensee}"
    puts "Total records that will be modified: #{total_affected}"
    
    if total_affected == 0
      puts "No records found with licensor or licensee fields containing only 'Details'."
      next
    end
    
    # Show some examples
    puts "\nSample records to be updated:"
    sample_records = PdfDocument.where("TRIM(licensor) IN (?) OR TRIM(licensee) IN (?)", details_patterns, details_patterns).limit(5)
    sample_records.each do |record|
      puts "  ID: #{record.id} | File: #{record.filename}"
      puts "    Licensor: '#{record.licensor}' | Licensee: '#{record.licensee}'"
    end
    
    print "\nDo you want to proceed? (y/N): "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'y' || response == 'yes'
      puts "Operation cancelled."
      next
    end
    
    updated_count = 0
    
    # Update records with licensor containing only 'Details'
    PdfDocument.where("TRIM(licensor) IN (?)", details_patterns).find_each do |doc|
      old_licensor = doc.licensor
      doc.update(licensor: '')
      updated_count += 1
      puts "Updated record ID #{doc.id}: Blanked licensor (was '#{old_licensor}')"
    end
    
    # Update records with licensee containing only 'Details'
    PdfDocument.where("TRIM(licensee) IN (?)", details_patterns).find_each do |doc|
      old_licensee = doc.licensee
      # Only update if we haven't already processed this record for licensor
      unless doc.licensor.blank?
        doc.update(licensee: '')
        updated_count += 1
      else
        doc.update(licensee: '')
      end
      puts "Updated record ID #{doc.id}: Blanked licensee (was '#{old_licensee}')"
    end
    
    puts "\nCleanup completed!"
    puts "Total fields blanked: #{updated_count}"
    
    # Verify the cleanup
    remaining_details = PdfDocument.where("TRIM(licensor) IN (?) OR TRIM(licensee) IN (?)", details_patterns, details_patterns).count
    puts "Remaining records with 'Details' fields: #{remaining_details}"
  end
  
  desc "Update records with notarized document format using enhanced extraction"
  task :update_notarized_records => :environment do
    puts "PDF Data Update for Notarized Documents"
    puts "=" * 40
    puts "Finding records with notarized document format..."
    
    # Find records that contain notarization text
    notarized_records = PdfDocument.where(
      "content LIKE ? OR content LIKE ?", 
      "%Department of Registration and Stamps%",
      "%department of registration & stamps%"
    ).where.not(content: [nil, ''])
    
    total_records = PdfDocument.count
    notarized_count = notarized_records.count
    
    puts "Total records in database: #{total_records}"
    puts "Records with notarized format: #{notarized_count}"
    
    if notarized_count == 0
      puts "✅ No notarized records found!"
      exit 0
    end
    
    puts ""
    puts "Sample notarized records to be updated:"
    notarized_records.limit(5).each do |record|
      puts "  ID: #{record.id} | File: #{record.filename}"
      puts "  Current - Licensor: '#{record.licensor}' | Licensee: '#{record.licensee}'"
      puts "  Current Document Type: '#{record.document_type || 'NULL'}'"
    end
    
    puts ""
    print "Proceed with updating #{notarized_count} notarized records? (y/N): "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'y' || response == 'yes'
      puts "Update cancelled."
      exit 0
    end
    
    puts ""
    puts "Processing notarized records..."
    
    updated_count = 0
    error_count = 0
    skipped_count = 0
    improved_count = 0
    
    notarized_records.find_each.with_index do |record, index|
      puts "[#{index + 1}/#{notarized_count}] #{record.filename}"
      
      begin
        if record.content.blank?
          puts "  ⚠️  No content - skipping"
          skipped_count += 1
          next
        end
        
        # Store old values for comparison
        old_licensor = record.licensor
        old_licensee = record.licensee
        old_document_type = record.document_type
        
        # Apply notarized document extraction
        extracted_data = extract_notarized_document_data(record.content)
        
        # Check if we found any new data
        new_licensor = extracted_data[:licensor]
        new_licensee = extracted_data[:licensee]
        new_document_type = extracted_data[:document_type]
        
        has_improvements = false
        
        # Update fields with new data
        if old_licensor != new_licensor && new_licensor.present?
          record.licensor = new_licensor
          has_improvements = true
        end
        
        if old_licensee != new_licensee && new_licensee.present?
          record.licensee = new_licensee
          has_improvements = true
        end
        
        if old_document_type != new_document_type
          record.document_type = new_document_type
          has_improvements = true
        end
        
        # Always update other fields from extraction
        record.start_date = extracted_data[:start_date] if extracted_data[:start_date].present?
        record.end_date = extracted_data[:end_date] if extracted_data[:end_date].present?
        record.agreement_period = extracted_data[:agreement_period] if extracted_data[:agreement_period].present?
        
        if has_improvements || record.changed?
          record.save!
          puts "  ✅ Updated"
          puts "    Licensor: #{new_licensor&.truncate(50)}" if old_licensor != new_licensor && new_licensor.present?
          puts "    Licensee: #{new_licensee&.truncate(50)}" if old_licensee != new_licensee && new_licensee.present?
          puts "    Document Type: #{new_document_type}" if old_document_type != new_document_type
          puts "    Start Date: #{extracted_data[:start_date]}" if extracted_data[:start_date].present?
          puts "    End Date: #{extracted_data[:end_date]}" if extracted_data[:end_date].present?
          improved_count += 1
        else
          puts "  ➡️  No changes needed"
        end
        
        updated_count += 1
        
      rescue => e
        puts "  ❌ Error: #{e.message}"
        error_count += 1
      end
    end
    
    puts ""
    puts "Update Results:"
    puts "  Processed: #{updated_count}"
    puts "  Improved: #{improved_count}"
    puts "  Skipped: #{skipped_count}"
    puts "  Errors: #{error_count}"
    puts "  Total: #{notarized_count}"
    
    # Show summary after update
    final_notarized_count = PdfDocument.where(document_type: "NOTARIZED AGREEMENT").count
    
    puts ""
    puts "Final Summary:"
    puts "  Records marked as 'NOTARIZED AGREEMENT': #{final_notarized_count}"
  end
  
  desc "Blank out licensor and licensee fields containing '(which expression shall mean and include the'"
  task :blank_expression_fields => :environment do
    puts "Starting cleanup of licensor and licensee fields containing '(which expression shall mean and include the'..."
    
    search_text = "(which expression shall mean and include the"
    
    # Count records that will be affected
    licensor_count = PdfDocument.where("licensor LIKE ?", "%#{search_text}%").count
    licensee_count = PdfDocument.where("licensee LIKE ?", "%#{search_text}%").count
    total_affected = PdfDocument.where("licensor LIKE ? OR licensee LIKE ?", "%#{search_text}%", "%#{search_text}%").count
    
    puts "Records with licensor containing '#{search_text}': #{licensor_count}"
    puts "Records with licensee containing '#{search_text}': #{licensee_count}"
    puts "Total records that will be modified: #{total_affected}"
    
    if total_affected == 0
      puts "No records found with licensor or licensee fields containing '#{search_text}'."
      next
    end
    
    # Show some examples
    puts "\nSample records to be updated:"
    sample_records = PdfDocument.where("licensor LIKE ? OR licensee LIKE ?", "%#{search_text}%", "%#{search_text}%").limit(5)
    sample_records.each do |record|
      puts "  ID: #{record.id} | File: #{record.filename}"
      if record.licensor&.include?(search_text)
        puts "    Licensor: #{record.licensor.truncate(100)}"
      end
      if record.licensee&.include?(search_text)
        puts "    Licensee: #{record.licensee.truncate(100)}"
      end
      puts ""
    end
    
    print "Do you want to proceed? (y/N): "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'y' || response == 'yes'
      puts "Operation cancelled."
      next
    end
    
    updated_count = 0
    
    # Update records with licensor containing the expression
    PdfDocument.where("licensor LIKE ?", "%#{search_text}%").find_each do |doc|
      old_licensor = doc.licensor
      doc.update(licensor: '')
      updated_count += 1
      puts "Updated record ID #{doc.id}: Blanked licensor (contained '#{search_text}')"
    end
    
    # Update records with licensee containing the expression
    PdfDocument.where("licensee LIKE ?", "%#{search_text}%").find_each do |doc|
      old_licensee = doc.licensee
      doc.update(licensee: '')
      updated_count += 1
      puts "Updated record ID #{doc.id}: Blanked licensee (contained '#{search_text}')"
    end
    
    puts "\nCleanup completed!"
    puts "Total fields blanked: #{updated_count}"
    
    # Verify the cleanup
    remaining_expression = PdfDocument.where("licensor LIKE ? OR licensee LIKE ?", "%#{search_text}%", "%#{search_text}%").count
    puts "Remaining records with '#{search_text}': #{remaining_expression}"
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
      pdf_document.document_type = filtered_data[:document_type]
      pdf_document.filtered_data = filtered_data[:filtered_data]
      
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
  
  def find_duplicate_record(pdf_document)
    # Look for exact matches on licensor, licensee, and date fields
    query = PdfDocument.where(
      licensor: pdf_document.licensor,
      licensee: pdf_document.licensee
    )
    
    # Add date conditions if available
    if pdf_document.start_date.present? && pdf_document.end_date.present?
      # Check for exact start and end date match
      query = query.where(
        start_date: pdf_document.start_date,
        end_date: pdf_document.end_date
      )
    elsif pdf_document.start_date.present?
      # Check for exact start date match
      query = query.where(start_date: pdf_document.start_date)
    elsif pdf_document.end_date.present?
      # Check for exact end date match
      query = query.where(end_date: pdf_document.end_date)
    elsif pdf_document.agreement_date.present?
      # Fallback to agreement date if start/end dates not available
      query = query.where(agreement_date: pdf_document.agreement_date)
    end
    
    # Return the first matching record
    query.first
  end
  
  def clean_extract_data(content)
    extracted = { licensor: nil, licensee: nil, address: nil, start_date: nil, end_date: nil, agreement_period: nil, document_type: nil }
    
    # Extract document type first
    notarization_patterns = [
      /Department\s+of\s+Registration\s+and\s+Stamps\s+Government\s+of\s+Maharashtra/i,
      /department\s+of\s+registration\s+&\s+stamps/i,
      /registrar\s+of\s+documents/i,
      /notarized/i,
      /notary\s+public/i,
      /stamp\s+duty/i
    ]
    
    # Check for notarization indicators
    is_notarized = notarization_patterns.any? { |pattern| content.match(pattern) }
    extracted[:document_type] = is_notarized ? "NOTARIZED AGREEMENT" : "LEAVE AND LICENSE AGREEMENT"
    
    # Extract Licensor name (before "Address:")
    licensor_pattern = /Licensor\s*\n?\s*([^A-Z]*?)(?:Address:|Licensee)/mi
    if match = content.match(licensor_pattern)
      name = match[1].strip.gsub(/\s+/, ' ')
      # Clean up common prefixes and get just the name
      name = name.gsub(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s*/i, '\1 ').strip
      extracted[:licensor] = name unless name.empty?
    end
    
    # Extract Licensee name (before "Address:")  
    licensee_pattern = /Licensee\s*\n?\s*([^A-Z]*?)(?:Address:|All that)/mi
    if match = content.match(licensee_pattern)
      name = match[1].strip.gsub(/\s+/, ' ')
      # Clean up common prefixes and get just the name
      name = name.gsub(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s*/i, '\1 ').strip
      extracted[:licensee] = name unless name.empty?
    end
    
    # Enhanced fallback extraction if licensor or licensee are empty
    if extracted[:licensor].blank? || extracted[:licensee].blank?
      # Fallback patterns for licensor
      if extracted[:licensor].blank?
        # Pattern 1: Most specific pattern for "called 'the Licensor'"
        pattern1 = /(Mr\.|Mrs\.|Ms\.|Dr\.)\s*([A-Z][A-Z\s]+?)(?=\s*\([^)]*called\s*"[^"]*Licensor)/i
        
        # Pattern 2: Extract from "Name:" field in structured format (first occurrence before "HEREINAFTER called 'the Licensor'")
        pattern2 = /Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.|Mrs\.\/Shrimati\/Miss\.)\s*[A-Z][a-zA-Z\s\.]+?)(?:\s*,|\s*Age|\s*HEREINAFTER.*?called.*?Licensor)/im
        
        # Pattern 3: Enhanced pattern for the new format - extract name after "Name:" and before comma/Age
        pattern3 = /1\)\s*Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.|Mrs\.\/Shrimati\/Miss\.)\s*[A-Z][a-zA-Z\s\.]+?)\s*,\s*Age/im
        
        [pattern1, pattern2, pattern3].each do |pattern|
          if match = content.match(pattern)
            name = if match.captures.length >= 2
              (match[1].to_s + ' ' + match[2].to_s).strip.gsub(/\s+/, ' ')
            else
              match[1].to_s.strip.gsub(/\s+/, ' ')
            end
            
            # Clean up the name - remove extra prefixes and normalize
            name = name.gsub(/Mrs\.\/Shrimati\/Miss\.\s*/, 'Mrs. ')
                      .gsub(/\s+/, ' ')
                      .strip
            
            # Validation for the extracted name
            if name.present? && 
               name.length >= 5 && 
               name.match?(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z]/i) &&
               !name.include?('HEREINAFTER')
              extracted[:licensor] = name
              break
            end
          end
        end
      end
      
      # Fallback patterns for licensee  
      if extracted[:licensee].blank?
        # Pattern 1: Most specific pattern for "called 'the Licensee'"
        pattern1 = /(Mr\.|Mrs\.|Ms\.|Dr\.)\s*([A-Z][a-zA-Z\s]+?)(?=\s*\([^)]*called\s*"[^"]*Licensee)/i
        
        # Pattern 2: Extract second "Name:" field (for licensee in structured format)
        # Look for Name: after finding first licensor section
        pattern2 = /HEREINAFTER.*?called.*?Licensor.*?AND.*?Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.|Mrs\.\/Shrimati\/Miss\.)\s*[A-Z][a-zA-Z\s\.]+?)(?:\s*,|\s*Age|\s*HEREINAFTER.*?called.*?Licensee)/im
        
        # Pattern 3: Enhanced pattern for the new format - find second "1) Name:" after "AND"
        pattern3 = /AND\s+1\)\s*Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.|Mrs\.\/Shrimati\/Miss\.)\s*[A-Z][a-zA-Z\s\.]+?)\s*,\s*Age/im
        
        # Pattern 4: Handle multiple licensees format - extract all names after "AND" section
        pattern4 = /HEREINAFTER.*?called.*?Licensor.*?AND(.*?)HEREINAFTER.*?called.*?Licensees/im
        
        [pattern1, pattern2, pattern3].each do |pattern|
          if match = content.match(pattern)
            name = if match.captures.length >= 2
              (match[1].to_s + ' ' + match[2].to_s).strip.gsub(/\s+/, ' ')
            else
              match[1].to_s.strip.gsub(/\s+/, ' ')
            end
            
            # Clean up the name - remove extra prefixes and normalize
            name = name.gsub(/Mrs\.\/Shrimati\/Miss\.\s*/, 'Mrs. ')
                      .gsub(/\s+/, ' ')
                      .strip
            
            # Validation for the extracted name
            if name.present? && 
               name.length >= 5 && 
               name.match?(/^(Mr\.|Mrs\.|Ms\.|Dr\.)\s*[A-Z]/i) &&
               !name.include?('HEREINAFTER')
              extracted[:licensee] = name
              break
            end
          end
        end
        
        # If still no licensee found, try to extract multiple licensees
        if extracted[:licensee].blank?
          if match = content.match(pattern4)
            licensee_section = match[1]
            # Extract all "Name:" entries from the licensee section
            name_matches = licensee_section.scan(/\d+\)\s*Name:\s*((?:Mr\.|Mrs\.|Ms\.|Dr\.|Miss)\s*[A-Z][a-zA-Z\s\.]+?)\s*,\s*Age/im)
            
            if name_matches.any?
              licensee_names = name_matches.map do |name_match|
                name = name_match[0].to_s.strip.gsub(/\s+/, ' ')
                # Clean up the name
                name = name.gsub(/Mrs\.\/Shrimati\/Miss\.\s*/, 'Mrs. ')
                          .gsub(/\s+/, ' ')
                          .strip
                
                # Validate the name
                if name.present? && 
                   name.length >= 5 && 
                   name.match?(/^(Mr\.|Mrs\.|Ms\.|Dr\.|Miss)\s*[A-Z]/i)
                  name
                else
                  nil
                end
              end.compact
              
              if licensee_names.any?
                # Join multiple licensees with commas
                extracted[:licensee] = licensee_names.join(', ')
              end
            end
          end
        end
      end
    end
    
    # Extract property address from "SCHEDULE I" section first (highest priority)
    schedule_pattern = /SCHEDULE\s+I.*?All\s+that\s+constructed\s+portion\s+being.*?(?=IN\s+WITNESS\s+WHEREOF|$)/im
    schedule_match = content.match(schedule_pattern)
    
    if schedule_match
      schedule_text = schedule_match[0]
      # Extract the detailed property description
      property_desc_pattern = /All\s+that\s+constructed\s+portion\s+being\s+(.+?)(?=IN\s+WITNESS\s+WHEREOF|$)/im
      desc_match = schedule_text.match(property_desc_pattern)
      
      if desc_match
        extracted[:address] = desc_match[1].strip.gsub(/\s+/, ' ')
      end
    end
    
    # Fallback: Extract property address from "All that constructed portion" section if not found above
    # Fallback: Extract property address from "All that constructed portion" section if not found above
    if extracted[:address].blank?
      address_patterns = [
        /bearing Apartment\/Flat No\.([^,]*),.*?Built-up\s*:([^,]*),.*?situated on.*?Floor.*?Building.*?known as\s*['"]*([^'"]*?)['"]*.*?Survey Number\s*:([^,]*),?Road:\s*([^,]*),?\s*Location:\s*([^,]*)/mi,
        /Apartment\/Flat No\.([^,]*),.*?Building.*?known as\s*['"]*([^'"]*?)['"]*.*?Survey Number\s*:([^,]*)/mi
      ]
      
      address_patterns.each do |pattern|
        if match = content.match(pattern)
          parts = match.captures.compact.map(&:strip).reject(&:empty?)
          if parts.length >= 3
            extracted[:address] = "Apartment/Flat No. #{parts[0]}, Building: #{parts[2] || parts[1]}, Survey No: #{parts[3] || parts[2]}"
            break
          end
        end
      end
    end
    
    # Use existing service for date extraction
    extractor_service = PdfDataExtractorService.new(content)
    date_data = extractor_service.extract_all_data
    
    extracted[:start_date] = date_data[:start_date]
    extracted[:end_date] = date_data[:end_date] 
    extracted[:agreement_period] = date_data[:agreement_period]
    
    extracted
  end
  
  # Specialized extraction for notarized documents
  def extract_notarized_document_data(content)
    extracted = { 
      licensor: nil, 
      licensee: nil, 
      address: nil, 
      start_date: nil, 
      end_date: nil, 
      agreement_period: nil, 
      document_type: "NOTARIZED AGREEMENT" 
    }
    
    # Extract Licensor from notarized format
    # Pattern: "1)Name, PAN: XXXX, Age: XX Years..."
    licensor_patterns = [
      /1\)\s*([^,]+),\s*PAN:\s*[^,]+,\s*Age:\s*\d+\s*Years[^)]*?(?=HEREINAFTER\s+called\s+the\s+Licensor)/im,
      /1\)\s*([A-Z][a-zA-Z\s]+?),\s*PAN:/im,
      /1\)\s*([^,]+)(?=,\s*PAN:)/im
    ]
    
    licensor_patterns.each do |pattern|
      match = content.match(pattern)
      if match && match[1]
        name = match[1].strip.gsub(/\s+/, ' ')
        if name.present? && name.length >= 3 && name.match?(/^[A-Z][a-zA-Z\s]+$/)
          extracted[:licensor] = name
          break
        end
      end
    end
    
    # Extract Licensee from notarized format
    # Pattern: After "AND" section
    licensee_patterns = [
      /AND\s+1\)\s*([^,]+),\s*PAN:\s*[^,]+,\s*Age:\s*\d+\s*Years[^)]*?(?=HEREINAFTER\s+called\s+the\s+Licensee)/im,
      /AND\s+1\)\s*([A-Z][a-zA-Z\s]+?),\s*PAN:/im,
      /AND\s+1\)\s*([^,]+)(?=,\s*PAN:)/im
    ]
    
    licensee_patterns.each do |pattern|
      match = content.match(pattern)
      if match && match[1]
        name = match[1].strip.gsub(/\s+/, ' ')
        if name.present? && name.length >= 3 && name.match?(/^[A-Z][a-zA-Z\s]+$/)
          extracted[:licensee] = name
          break
        end
      end
    end
    
    # Extract dates using existing service method
    extractor_service = PdfDataExtractorService.new(content)
    date_data = extractor_service.extract_all_data
    
    extracted[:start_date] = date_data[:start_date]
    extracted[:end_date] = date_data[:end_date] 
    extracted[:agreement_period] = date_data[:agreement_period]
    
    # Extract address (reuse existing logic)
    schedule_pattern = /SCHEDULE\s+I.*?All\s+that\s+constructed\s+portion\s+being.*?(?=IN\s+WITNESS\s+WHEREOF|$)/im
    schedule_match = content.match(schedule_pattern)
    
    if schedule_match
      schedule_text = schedule_match[0]
      property_desc_pattern = /All\s+that\s+constructed\s+portion\s+being\s+(.+?)(?=IN\s+WITNESS\s+WHEREOF|$)/im
      desc_match = schedule_text.match(property_desc_pattern)
      
      if desc_match
        extracted[:address] = desc_match[1].strip.gsub(/\s+/, ' ')
      end
    end
    
    extracted
  end

  desc "Generate month-wise Excel files based on end_date"
  task :generate_monthly_exports, [:output_folder] => :environment do |task, args|
    require 'axlsx'
    
    output_folder = args[:output_folder] || Rails.root.join('tmp', 'monthly_exports')
    
    puts "📊 Generating Month-wise Excel Exports"
    puts "=" * 50
    
    # Create output folder if it doesn't exist
    FileUtils.mkdir_p(output_folder) unless Dir.exist?(output_folder)
    puts "Output folder: #{output_folder}"
    
    # Get all documents with end_date
    documents_with_end_date = PdfDocument.where.not(end_date: nil)
    total_documents = documents_with_end_date.count
    
    puts "Total documents with end_date: #{total_documents}"
    
    if total_documents == 0
      puts "❌ No documents found with end_date. Nothing to export."
      exit 0
    end
    
    # Group documents by month-year of end_date
    grouped_documents = documents_with_end_date.group_by do |doc|
      doc.end_date.strftime("%Y-%m")
    end
    
    puts "Found #{grouped_documents.keys.length} different months:"
    grouped_documents.each do |month_year, docs|
      date = Date.parse("#{month_year}-01")
      month_name = date.strftime("%B %Y")
      puts "  #{month_name}: #{docs.count} documents"
    end
    
    puts ""
    print "Proceed with generating Excel files for each month? (y/N): "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'y' || response == 'yes'
      puts "Export cancelled."
      exit 0
    end
    
    puts ""
    puts "Generating Excel files..."
    
    generated_files = []
    total_exported = 0
    
    grouped_documents.each do |month_year, documents|
      begin
        date = Date.parse("#{month_year}-01")
        month_name = date.strftime("%B_%Y")
        filename = "pdf_documents_#{month_name.downcase}.xlsx"
        filepath = File.join(output_folder, filename)
        
        puts "📝 Creating #{filename} (#{documents.count} documents)..."
        
        # Create Excel file using Axlsx
        package = Axlsx::Package.new
        workbook = package.workbook
        
        # Main data sheet
        workbook.add_worksheet(name: "#{date.strftime('%B %Y')} Documents") do |sheet|
          # Define styles
          header_style = sheet.styles.add_style(
            bg_color: "366092",
            fg_color: "FFFFFF", 
            b: true,
            alignment: { horizontal: :center }
          )
          
          date_style = sheet.styles.add_style(
            format_code: "yyyy-mm-dd"
          )
          
          wrap_style = sheet.styles.add_style(
            alignment: { wrap_text: true, vertical: :top }
          )
          
          # Header row
          headers = [
            'ID', 'Filename', 'Title', 'Licensor', 'Licensee', 'Address',
            'Agreement Date', 'Start Date', 'End Date', 'Agreement Period', 'Filtered Data Preview'
          ]
          
          sheet.add_row headers, style: header_style
          
          # Data rows - sort by end_date
          documents.sort_by(&:end_date).each do |doc|
            sheet.add_row [
              doc.id,
              doc.filename,
              doc.title,
              
              doc.licensor,
              doc.licensee,
              doc.address,
              doc.agreement_date,
              doc.start_date,
              doc.end_date,
              doc.agreement_period,
              doc.filtered_data&.truncate(500)
            ], style: [
              nil, nil, nil, wrap_style, wrap_style, wrap_style,
              date_style, date_style, date_style, nil, wrap_style
            ]
          end
          
          # Auto-fit columns
          sheet.column_widths 5, 25, 25, 30, 30, 40, 15, 15, 15, 20, 50
        end
        
        # Summary sheet
        workbook.add_worksheet(name: "Summary") do |sheet|
          title_style = sheet.styles.add_style(
            b: true, 
            sz: 16,
            fg_color: "366092"
          )
          
          header_style = sheet.styles.add_style(
            b: true,
            bg_color: "E1E8F0"
          )
          
          # Title
          sheet.add_row ["#{date.strftime('%B %Y')} - PDF Documents Summary"], style: title_style
          sheet.add_row []
          
          # Month info
          sheet.add_row ["Month", date.strftime('%B %Y')], style: header_style
          sheet.add_row ["Total Documents", documents.count]
          sheet.add_row ["Date Range", "#{documents.map(&:end_date).min} to #{documents.map(&:end_date).max}"]
          sheet.add_row []
          
          # Statistics
          with_licensor = documents.count { |doc| doc.licensor.present? }
          with_licensee = documents.count { |doc| doc.licensee.present? }
          with_address = documents.count { |doc| doc.address.present? }
          notarized_count = documents.count { |doc| doc.document_type == "NOTARIZED AGREEMENT" }
          
          sheet.add_row ["Statistic", "Count", "Percentage"], style: header_style
          sheet.add_row ["Documents with Licensor", with_licensor, "#{(with_licensor.to_f / documents.count * 100).round(1)}%"]
          sheet.add_row ["Documents with Licensee", with_licensee, "#{(with_licensee.to_f / documents.count * 100).round(1)}%"]
          sheet.add_row ["Documents with Address", with_address, "#{(with_address.to_f / documents.count * 100).round(1)}%"]
          sheet.add_row ["Notarized Agreements", notarized_count, "#{(notarized_count.to_f / documents.count * 100).round(1)}%"]
          
          sheet.add_row []
          sheet.add_row ["Export Date", Date.current.strftime("%Y-%m-%d")]
          sheet.add_row ["Export Time", Time.current.strftime("%H:%M:%S")]
          
          # Auto-fit columns
          sheet.column_widths 30, 15, 15
        end
        
        # Save the file
        package.serialize(filepath)
        
        generated_files << {
          file: filename,
          path: filepath,
          month: date.strftime('%B %Y'),
          count: documents.count
        }
        
        total_exported += documents.count
        puts "  ✅ #{filename} created successfully"
        
      rescue => e
        puts "  ❌ Error creating file for #{month_year}: #{e.message}"
      end
    end
    
    puts ""
    puts "📋 Export Summary:"
    puts "  Files generated: #{generated_files.count}"
    puts "  Total documents exported: #{total_exported}"
    puts ""
    puts "📁 Generated files:"
    generated_files.each do |file_info|
      puts "  📄 #{file_info[:file]} (#{file_info[:month]}: #{file_info[:count]} documents)"
      puts "     Location: #{file_info[:path]}"
    end
    
    puts ""
    puts "✅ Month-wise export completed!"
    puts "📂 All files saved to: #{output_folder}"
  end

  desc "Generate month-wise Excel files for a specific date range"
  task :generate_monthly_exports_range, [:start_date, :end_date, :output_folder] => :environment do |task, args|
    require 'axlsx'
    
    start_date = args[:start_date] ? Date.parse(args[:start_date]) : nil
    end_date = args[:end_date] ? Date.parse(args[:end_date]) : nil
    output_folder = args[:output_folder] || Rails.root.join('tmp', 'monthly_exports')
    
    puts "📊 Generating Month-wise Excel Exports (Date Range)"
    puts "=" * 50
    
    if start_date.nil? || end_date.nil?
      puts "Usage: rails pdfs:generate_monthly_exports_range[start_date,end_date,output_folder]"
      puts "Example: rails pdfs:generate_monthly_exports_range[2025-01-01,2025-12-31,/path/to/output]"
      puts "Date format: YYYY-MM-DD"
      exit 1
    end
    
    if start_date > end_date
      puts "❌ Start date cannot be after end date"
      exit 1
    end
    
    # Create output folder if it doesn't exist
    FileUtils.mkdir_p(output_folder) unless Dir.exist?(output_folder)
    puts "Output folder: #{output_folder}"
    puts "Date range: #{start_date} to #{end_date}"
    
    # Get documents within the date range
    documents_in_range = PdfDocument.where(end_date: start_date..end_date)
    total_documents = documents_in_range.count
    
    puts "Documents with end_date in range: #{total_documents}"
    
    if total_documents == 0
      puts "❌ No documents found with end_date in the specified range."
      exit 0
    end
    
    # Group documents by month-year of end_date
    grouped_documents = documents_in_range.group_by do |doc|
      doc.end_date.strftime("%Y-%m")
    end
    
    puts "Found #{grouped_documents.keys.length} months in range:"
    grouped_documents.keys.sort.each do |month_year|
      docs = grouped_documents[month_year]
      date = Date.parse("#{month_year}-01")
      month_name = date.strftime("%B %Y")
      puts "  #{month_name}: #{docs.count} documents"
    end
    
    puts ""
    print "Proceed with generating Excel files for these months? (y/N): "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'y' || response == 'yes'
      puts "Export cancelled."
      exit 0
    end
    
    puts ""
    puts "Generating Excel files..."
    
    generated_files = []
    total_exported = 0
    
    grouped_documents.keys.sort.each do |month_year|
      documents = grouped_documents[month_year]
      
      begin
        date = Date.parse("#{month_year}-01")
        month_name = date.strftime("%B_%Y")
        filename = "pdf_documents_#{month_name.downcase}_#{start_date.strftime('%Y%m%d')}_to_#{end_date.strftime('%Y%m%d')}.xlsx"
        filepath = File.join(output_folder, filename)
        
        puts "📝 Creating #{filename} (#{documents.count} documents)..."
        
        # Create Excel file using the same structure as the main export
        package = Axlsx::Package.new
        workbook = package.workbook
        
        # Main data sheet
        workbook.add_worksheet(name: "#{date.strftime('%B %Y')} Documents") do |sheet|
          # Define styles
          header_style = sheet.styles.add_style(
            bg_color: "366092",
            fg_color: "FFFFFF", 
            b: true,
            alignment: { horizontal: :center }
          )
          
          date_style = sheet.styles.add_style(
            format_code: "yyyy-mm-dd"
          )
          
          wrap_style = sheet.styles.add_style(
            alignment: { wrap_text: true, vertical: :top }
          )
          
          # Header row
          headers = [
            'ID', 'Filename', 'Title', 'Document Type', 'Licensor', 'Licensee', 'Address',
            'Agreement Date', 'Start Date', 'End Date', 'Agreement Period', 'Filtered Data Preview'
          ]
          
          sheet.add_row headers, style: header_style
          
          # Data rows - sort by end_date
          documents.sort_by(&:end_date).each do |doc|
            sheet.add_row [
              doc.id,
              doc.filename,
              doc.title,
              
              doc.licensor,
              doc.licensee,
              doc.address,
              doc.agreement_date,
              doc.start_date,
              doc.end_date,
              doc.agreement_period,
              doc.filtered_data&.truncate(500)
            ], style: [
              nil, nil, nil, wrap_style, wrap_style, wrap_style,
              date_style, date_style, date_style, nil, wrap_style
            ]
          end
          
          # Auto-fit columns
          sheet.column_widths 5, 25, 25, 30, 30, 40, 15, 15, 15, 20, 50
        end
        
        # Summary sheet
        workbook.add_worksheet(name: "Summary") do |sheet|
          title_style = sheet.styles.add_style(
            b: true, 
            sz: 16,
            fg_color: "366092"
          )
          
          header_style = sheet.styles.add_style(
            b: true,
            bg_color: "E1E8F0"
          )
          
          # Title
          sheet.add_row ["#{date.strftime('%B %Y')} - PDF Documents Summary"], style: title_style
          sheet.add_row ["Date Range Filter: #{start_date} to #{end_date}"]
          sheet.add_row []
          
          # Month info
          sheet.add_row ["Month", date.strftime('%B %Y')], style: header_style
          sheet.add_row ["Total Documents", documents.count]
          sheet.add_row ["End Date Range", "#{documents.map(&:end_date).min} to #{documents.map(&:end_date).max}"]
          sheet.add_row []
          
          # Statistics
          with_licensor = documents.count { |doc| doc.licensor.present? }
          with_licensee = documents.count { |doc| doc.licensee.present? }
          with_address = documents.count { |doc| doc.address.present? }
          notarized_count = documents.count { |doc| doc.document_type == "NOTARIZED AGREEMENT" }
          
          sheet.add_row ["Statistic", "Count", "Percentage"], style: header_style
          sheet.add_row ["Documents with Licensor", with_licensor, "#{(with_licensor.to_f / documents.count * 100).round(1)}%"]
          sheet.add_row ["Documents with Licensee", with_licensee, "#{(with_licensee.to_f / documents.count * 100).round(1)}%"]
          sheet.add_row ["Documents with Address", with_address, "#{(with_address.to_f / documents.count * 100).round(1)}%"]
          sheet.add_row ["Notarized Agreements", notarized_count, "#{(notarized_count.to_f / documents.count * 100).round(1)}%"]
          
          sheet.add_row []
          sheet.add_row ["Export Date", Date.current.strftime("%Y-%m-%d")]
          sheet.add_row ["Export Time", Time.current.strftime("%H:%M:%S")]
          
          # Auto-fit columns
          sheet.column_widths 30, 15, 15
        end
        
        # Save the file
        package.serialize(filepath)
        
        generated_files << {
          file: filename,
          path: filepath,
          month: date.strftime('%B %Y'),
          count: documents.count
        }
        
        total_exported += documents.count
        puts "  ✅ #{filename} created successfully"
        
      rescue => e
        puts "  ❌ Error creating file for #{month_year}: #{e.message}"
      end
    end
    
    puts ""
    puts "📋 Export Summary:"
    puts "  Files generated: #{generated_files.count}"
    puts "  Total documents exported: #{total_exported}"
    puts "  Date range: #{start_date} to #{end_date}"
    puts ""
    puts "📁 Generated files:"
    generated_files.each do |file_info|
      puts "  📄 #{file_info[:file]} (#{file_info[:month]}: #{file_info[:count]} documents)"
      puts "     Location: #{file_info[:path]}"
    end
    
    puts ""
    puts "✅ Month-wise export completed!"
    puts "📂 All files saved to: #{output_folder}"
  end

  desc "Clean whitespace from existing Licensor and Licensee fields"
  task :clean_whitespace => :environment do
    puts "🧹 Cleaning whitespace from Licensor and Licensee fields..."
    
    cleaned_count = 0
    total_count = PdfDocument.count
    
    PdfDocument.find_each.with_index do |doc, index|
      puts "Processing #{index + 1}/#{total_count}: #{doc.filename}" if (index + 1) % 100 == 0
      
      updated = false
      
      # Clean licensor field
      if doc.licensor.present?
        cleaned_licensor = clean_whitespace_text(doc.licensor)
        if cleaned_licensor != doc.licensor
          doc.licensor = cleaned_licensor
          updated = true
        end
      end
      
      # Clean licensee field
      if doc.licensee.present?
        cleaned_licensee = clean_whitespace_text(doc.licensee)
        if cleaned_licensee != doc.licensee
          doc.licensee = cleaned_licensee
          updated = true
        end
      end
      
      if updated
        doc.save!
        cleaned_count += 1
        puts "  ✓ Cleaned: #{doc.filename}"
      end
    end
    
    puts ""
    puts "✅ Whitespace cleaning completed!"
    puts "📊 Records cleaned: #{cleaned_count}/#{total_count}"
  end

  # Helper method to clean whitespace from text
  def clean_whitespace_text(text)
    return nil if text.blank?
    
    # Remove all types of whitespace characters including tabs, non-breaking spaces
    text = text.gsub(/[\u00A0\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]/, ' ')
    
    # Replace multiple newlines and spaces with single space
    text = text.gsub(/\n+/, ' ').strip
    text = text.gsub(/\s+/, ' ')
    
    # Remove leading/trailing whitespace and clean up internal whitespace
    text = text.strip.squeeze(' ')
    
    # Clean up common prefixes and suffixes
    text = text.gsub(/^(mr\.|mrs\.|ms\.|dr\.)\s*/i, '\1 ')
    text = text.gsub(/[:\-_]+$/, '').strip
    
    # Final cleanup - remove any remaining extra whitespace
    text = text.strip.squeeze(' ')
    
    text.present? ? text : nil
  end
end
