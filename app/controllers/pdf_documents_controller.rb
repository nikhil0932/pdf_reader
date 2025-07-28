class PdfDocumentsController < ApplicationController
  before_action :set_pdf_document, only: [:show, :destroy]

  def index
    @pdf_documents = PdfDocument.all.order(created_at: :desc)
  end

  def show
    @pdf_document = PdfDocument.find(params[:id])
  end

  def new
    @pdf_document = PdfDocument.new
  end

  def create
    @pdf_document = PdfDocument.new(pdf_document_params)
    @pdf_document.uploaded_at = Time.current

    if @pdf_document.save
      redirect_to @pdf_document, notice: 'PDF was successfully uploaded and processed.'
    else
      render :new, status: :unprocessable_entity
    end
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
        filtered_data: filtered_data[:filtered_data]
      )
      
      redirect_to @pdf_document, notice: 'PDF data has been reprocessed and filtered information updated.'
    else
      # Re-extract everything
      ExtractPdfTextJob.perform_later(@pdf_document)
      redirect_to @pdf_document, notice: 'PDF reprocessing started. Please refresh the page in a few moments.'
    end
  end

  private

  def set_pdf_document
    @pdf_document = PdfDocument.find(params[:id])
  end

  def pdf_document_params
    params.require(:pdf_document).permit(:title, :file)
  end
end
