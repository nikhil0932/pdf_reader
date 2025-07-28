class AddFilteredFieldsToPdfDocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :pdf_documents, :licensor, :text
    add_column :pdf_documents, :licensee, :text
    add_column :pdf_documents, :filtered_data, :text
  end
end
