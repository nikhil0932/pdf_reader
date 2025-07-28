class PdfDocument < ApplicationRecord
  has_one_attached :file
  
  validates :title, presence: true
  validates :file, presence: true
  
  validate :correct_file_type
  
  # Extract text content from the PDF after the file is attached
  after_commit :extract_text_content, on: :create
  
  private
  
  def correct_file_type
    if file.attached? && !file.content_type.in?(['application/pdf'])
      errors.add(:file, 'must be a PDF file')
    end
  end
  
  def extract_text_content
    return unless file.attached?
    
    # Use perform_later to avoid blocking the web request
    ExtractPdfTextJob.perform_now(self)
  end
end
