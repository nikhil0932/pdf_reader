class AddTypeToPdfDocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :pdf_documents, :type, :string, default: 'LEAVE AND LICENSE AGREEMENT'
  end
end
