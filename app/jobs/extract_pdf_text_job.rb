class ExtractPdfTextJob < ApplicationJob
  queue_as :default

  def perform(pdf_document)
    return unless pdf_document.file.attached?
    
    begin
      # Open the attached file and extract text
      pdf_document.file.open do |temp_file|
        reader = PDF::Reader.new(temp_file)
        extracted_text = ""
        page_count = 0
        
        reader.pages.each_with_index do |page, index|
          page_count = index + 1
          begin
            page_text = page.text.strip
            extracted_text += page_text + "\n\n" if page_text.present?
          rescue => page_error
            Rails.logger.warn "Error extracting text from page #{index + 1}: #{page_error.message}"
            extracted_text += "[Error extracting text from page #{index + 1}]\n\n"
          end
        end
        
        # Clean up the extracted text
        extracted_text = extracted_text.strip
        extracted_text = "No readable text found in this PDF." if extracted_text.blank?
        
        pdf_document.update_columns(
          content: extracted_text,
          page_count: page_count
        )
        
        # Extract filtered data using the service
        extractor_service = PdfDataExtractorService.new(extracted_text)
        filtered_data = extractor_service.extract_all_data
        
        pdf_document.update_columns(
          licensor: filtered_data[:licensor],
          licensee: filtered_data[:licensee],
          address: filtered_data[:address],
          agreement_date: filtered_data[:agreement_date],
          agreement_period: filtered_data[:agreement_period],
          filtered_data: filtered_data[:filtered_data]
        )
        
        Rails.logger.info "Successfully extracted text and filtered data from PDF: #{pdf_document.title}"
      end
    rescue PDF::Reader::EncryptedPDFError
      pdf_document.update_columns(
        content: "This PDF is password protected and cannot be processed.",
        page_count: 0
      )
      Rails.logger.error "Attempted to process encrypted PDF: #{pdf_document.title}"
    rescue => e
      pdf_document.update_columns(
        content: "Error processing PDF: #{e.message}",
        page_count: 0
      )
      Rails.logger.error "Error extracting PDF text for #{pdf_document.title}: #{e.message}"
    end
  end
end
