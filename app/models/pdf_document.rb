class PdfDocument < ApplicationRecord
  validates :title, presence: true
  validates :filename, presence: true, uniqueness: true
  
  # Extract text content from the PDF after creation (only for batch processing)
  after_commit :extract_text_content, on: :create, if: :should_extract_text?

  private
  
  def should_extract_text?
    # Only extract text for batch processing when content is not already present
    content.blank? && filename.present?
  end
  
  def extract_text_content
    # For batch processing, text is already extracted in the service
    # This is just a placeholder for future enhancements
  end
end
