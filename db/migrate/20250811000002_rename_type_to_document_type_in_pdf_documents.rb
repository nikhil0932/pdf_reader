class RenameTypeToDocumentTypeInPdfDocuments < ActiveRecord::Migration[7.1]
  def change
    rename_column :pdf_documents, :type, :document_type
  end
end
