class PdfDocumentsController < ApplicationController
  before_action :set_pdf_document, only: [:show, :destroy]

  def index
    @pdf_documents = PdfDocument.all.order(created_at: :desc)
  end

  def show
    @pdf_document = PdfDocument.find(params[:id])
  end

  def new
    # File upload functionality has been removed
    # Use batch processing instead: ruby pdf_folder_processor.rb /path/to/folder
    redirect_to pdf_documents_path, alert: 'Web upload is disabled. Use batch processing instead.'
  end

  def create
    # File upload functionality has been removed
    redirect_to pdf_documents_path, alert: 'Web upload is disabled. Use batch processing instead.'
  end

  def data_view
    @pdf_document = PdfDocument.find(params[:id])
  end

  def destroy
    @pdf_document.destroy
    redirect_to pdf_documents_url, notice: 'PDF document was successfully deleted.'
  end

  def reprocess
    @pdf_document = PdfDocument.find(params[:id])
    
    if @pdf_document.content.present? && !@pdf_document.content.include?("Error processing PDF")
      # Re-extract filtered data from existing content

      extractor_service = PdfDataExtractorService.new(@pdf_document.content)

      filtered_data = extractor_service.extract_all_data
      
      @pdf_document.update_columns(
        licensor: filtered_data[:licensor],
        licensee: filtered_data[:licensee],
        address: filtered_data[:address],
        agreement_date: filtered_data[:agreement_date],
        agreement_period: filtered_data[:agreement_period],
        start_date: filtered_data[:start_date],
        end_date: filtered_data[:end_date],
        filtered_data: filtered_data[:filtered_data]
      )
      
      redirect_to @pdf_document, notice: 'PDF data has been reprocessed and filtered information updated.'
    else
      redirect_to @pdf_document, alert: 'Cannot reprocess: No content available or content contains errors.'
    end
  end

  private

  def set_pdf_document
    @pdf_document = PdfDocument.find(params[:id])
  end
end
