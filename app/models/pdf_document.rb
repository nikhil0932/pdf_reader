class PdfDocument < ApplicationRecord
  has_one_attached :file
  
  validates :title, presence: true
  validates :filename, presence: true, uniqueness: true
  
  validate :correct_file_type
  
  # Extract text content from the PDF after the file is attached (only for web uploads)
  after_commit :extract_text_content, on: :create, if: :should_extract_text?
  
  private
  
  def should_extract_text?
    # Only extract text for web uploads (when content is not already present)
    file.attached? && content.blank?
  end
  
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
