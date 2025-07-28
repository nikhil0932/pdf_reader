#!/usr/bin/env ruby

# Standalone script to process PDF files from a folder
# Usage: ruby pdf_folder_processor.rb /path/to/pdf/folder

require 'bundler/setup'
require_relative 'config/environment'

class PdfFolderProcessor
  def initialize(folder_path)
    @folder_path = folder_path
  end

  def process_all
    validate_folder!
    
    pdf_files = find_pdf_files
    if pdf_files.empty?
      puts "No PDF files found in '#{@folder_path}'"
      return
    end

    puts "Found #{pdf_files.length} PDF file(s) to process..."
    puts "Starting processing...\n"

    results = process_files(pdf_files)
    display_summary(results, pdf_files.length)
  end

  def check_status
    validate_folder!
    
    pdf_files = find_pdf_files
    if pdf_files.empty?
      puts "No PDF files found in '#{@folder_path}'"
      return
    end

    processed = []
    unprocessed = []

    pdf_files.each do |file_path|
      filename = File.basename(file_path)
      if PdfDocument.exists?(filename: filename)
        processed << filename
      else
        unprocessed << filename
      end
    end

    puts "Folder: #{@folder_path}"
    puts "Total PDF files: #{pdf_files.length}"
    puts "Already processed: #{processed.length}"
    puts "Not yet processed: #{unprocessed.length}"

    if unprocessed.any?
      puts "\nFiles to be processed:"
      unprocessed.each_with_index do |file, index|
        puts "  #{index + 1}. #{file}"
      end
    end
  end

  private

  def validate_folder!
    unless Dir.exist?(@folder_path)
      puts "Error: Folder '#{@folder_path}' does not exist"
      exit(1)
    end
  end

  def find_pdf_files
    Dir.glob(File.join(@folder_path, "*.pdf")).sort
  end

  def process_files(pdf_files)
    results = { success: 0, error: 0, skipped: 0 }

    pdf_files.each_with_index do |file_path, index|
      filename = File.basename(file_path)
      puts "[#{index + 1}/#{pdf_files.length}] Processing: #{filename}"

      begin
        # Check if already processed
        if PdfDocument.exists?(filename: filename)
          puts "  ⚠️  Skipping - already exists in database"
          results[:skipped] += 1
          next
        end

        # Process the file
        processor = PdfFolderProcessorService.new(file_path)
        result = processor.process

        if result[:success]
          puts "  ✅ Successfully processed (ID: #{result[:pdf_document].id})"
          display_extracted_data(result[:pdf_document])
          results[:success] += 1
        else
          puts "  ❌ Error: #{result[:error]}"
          results[:error] += 1
        end

      rescue => e
        puts "  ❌ Unexpected error: #{e.message}"
        results[:error] += 1
      ensure
        puts "" # Empty line for readability
      end
    end

    results
  end

  def display_extracted_data(pdf_document)
    puts "    📄 Title: #{pdf_document.title}"
    puts "    👥 Licensor: #{pdf_document.licensor&.truncate(50)}" if pdf_document.licensor.present?
    puts "    🏠 Licensee: #{pdf_document.licensee&.truncate(50)}" if pdf_document.licensee.present?
    puts "    📅 Agreement Date: #{pdf_document.agreement_date}" if pdf_document.agreement_date.present?
    puts "    ⏰ Period: #{pdf_document.agreement_period}" if pdf_document.agreement_period.present?
  end

  def display_summary(results, total_files)
    puts "="*60
    puts "PROCESSING SUMMARY"
    puts "="*60
    puts "Total files found: #{total_files}"
    puts "Successfully processed: #{results[:success]}"
    puts "Errors encountered: #{results[:error]}"
    puts "Skipped (already exist): #{results[:skipped]}"
    puts "="*60

    if results[:success] > 0
      puts "✅ #{results[:success]} files were successfully processed and stored in the database"
    end

    if results[:error] > 0
      puts "❌ #{results[:error]} files encountered errors during processing"
    end

    if results[:skipped] > 0
      puts "⚠️  #{results[:skipped]} files were skipped (already in database)"
    end
  end
end

# Command line interface
if __FILE__ == $0
  if ARGV.empty?
    puts "Usage:"
    puts "  ruby #{File.basename(__FILE__)} <folder_path> [action]"
    puts ""
    puts "Actions:"
    puts "  process (default) - Process all PDF files in the folder"
    puts "  check            - Check which files are already processed"
    puts ""
    puts "Examples:"
    puts "  ruby #{File.basename(__FILE__)} /path/to/pdfs"
    puts "  ruby #{File.basename(__FILE__)} /path/to/pdfs process"
    puts "  ruby #{File.basename(__FILE__)} /path/to/pdfs check"
    exit(1)
  end

  folder_path = ARGV[0]
  action = ARGV[1] || 'process'

  processor = PdfFolderProcessor.new(folder_path)

  case action.downcase
  when 'process'
    processor.process_all
  when 'check'
    processor.check_status
  else
    puts "Unknown action: #{action}"
    puts "Available actions: process, check"
    exit(1)
  end
end
