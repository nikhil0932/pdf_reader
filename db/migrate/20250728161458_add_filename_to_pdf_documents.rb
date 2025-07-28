class AddFilenameToPdfDocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :pdf_documents, :filename, :string
  end
end
