require 'pdf-reader'

class PdfFolderProcessorService
  def initialize(file_path)
    @file_path = file_path
    @filename = File.basename(file_path)
  end

  def process
    begin
      # Check if file exists
      unless File.exist?(@file_path)
        return { success: false, error: "File not found: #{@file_path}" }
      end

      # Check if it's a PDF file
      unless @filename.downcase.end_with?('.pdf')
        return { success: false, error: "Not a PDF file: #{@filename}" }
      end

      # Extract text content from PDF
      content = extract_pdf_content
      
      if content.blank?
        return { success: false, error: "Could not extract content from PDF" }
      end

      # Extract structured data using existing service
      extractor = PdfDataExtractorService.new(content)
      extracted_data = extractor.extract_all_data

      # Create PDF document record
      pdf_document = create_pdf_document(content, extracted_data)
      
      if pdf_document.persisted?
        return { success: true, pdf_document: pdf_document }
      else
        return { success: false, error: pdf_document.errors.full_messages.join(', ') }
      end

    rescue => e
      return { success: false, error: "Processing error: #{e.message}" }
    end
  end

  private

  def extract_pdf_content
    begin
      reader = PDF::Reader.new(@file_path)
      content = ""
      
      reader.pages.each do |page|
        content += page.text + "\n"
      end
      
      content.strip
    rescue => e
      raise "PDF reading error: #{e.message}"
    end
  end

  def create_pdf_document(content, extracted_data)
    # Calculate page count
    page_count = get_page_count
    
    # Create title from filename (remove extension)
    title = File.basename(@filename, '.pdf')
    
    pdf_document = PdfDocument.new(
      title: title,
      filename: @filename,
      content: content,
      page_count: page_count,
      uploaded_at: Time.current,
      licensor: extracted_data[:licensor],
      licensee: extracted_data[:licensee],
      address: extracted_data[:address],
      agreement_date: parse_date(extracted_data[:agreement_date]),
      agreement_period: extracted_data[:agreement_period],
      filtered_data: extracted_data[:filtered_data]
    )

    # Attach the original file
    if File.exist?(@file_path)
      pdf_document.file.attach(
        io: File.open(@file_path),
        filename: @filename,
        content_type: 'application/pdf'
      )
    end

    pdf_document.save
    pdf_document
  end

  def get_page_count
    begin
      reader = PDF::Reader.new(@file_path)
      reader.page_count
    rescue
      0
    end
  end

  def parse_date(date_string)
    return nil if date_string.blank?
    
    # Try different date formats
    date_formats = [
      '%d/%m/%Y',   # 01/04/2025
      '%d-%m-%Y',   # 01-04-2025
      '%Y-%m-%d',   # 2025-04-01
      '%d %B %Y',   # 01 April 2025
      '%B %d, %Y'   # April 01, 2025
    ]
    
    date_formats.each do |format|
      begin
        return Date.strptime(date_string.strip, format)
      rescue Date::Error
        next
      end
    end
    
    # If no format matches, return nil
    nil
  rescue
    nil
  end
end
