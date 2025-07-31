class DataExportsController < ApplicationController
  def index
    @total_documents = PdfDocument.count
    @recent_documents = PdfDocument.order(created_at: :desc).limit(10)
  end

  def export_csv
    @pdf_documents = PdfDocument.all
    
    respond_to do |format|
      format.csv do
        headers['Content-Disposition'] = "attachment; filename=\"pdf_documents_#{Date.current.strftime('%Y%m%d')}.csv\""
        headers['Content-Type'] = 'text/csv'
      end
    end
  end

  def export_excel
    @pdf_documents = PdfDocument.all
    
    respond_to do |format|
      format.xlsx do
        headers['Content-Disposition'] = "attachment; filename=\"pdf_documents_#{Date.current.strftime('%Y%m%d')}.xlsx\""
      end
    end
  end

  def export_filtered
    # Build query based on filters
    query = PdfDocument.all
    
    if params[:date_from].present?
      query = query.where('agreement_date >= ?', params[:date_from])
    end
    
    if params[:date_to].present?
      query = query.where('agreement_date <= ?', params[:date_to])
    end
    
    if params[:licensor].present?
      query = query.where('licensor LIKE ?', "%#{params[:licensor]}%")
    end
    
    if params[:licensee].present?
      query = query.where('licensee LIKE ?', "%#{params[:licensee]}%")
    end
    
    if params[:period].present?
      query = query.where('agreement_period LIKE ?', "%#{params[:period]}%")
    end
    
    @pdf_documents = query.order(:created_at)
    
    respond_to do |format|
      format.csv do
        headers['Content-Disposition'] = "attachment; filename=\"filtered_pdf_documents_#{Date.current.strftime('%Y%m%d')}.csv\""
        headers['Content-Type'] = 'text/csv'
        render template: 'data_exports/export_csv'
      end
      
      format.xlsx do
        headers['Content-Disposition'] = "attachment; filename=\"filtered_pdf_documents_#{Date.current.strftime('%Y%m%d')}.xlsx\""
        render template: 'data_exports/export_excel'
      end
    end
  end
end
