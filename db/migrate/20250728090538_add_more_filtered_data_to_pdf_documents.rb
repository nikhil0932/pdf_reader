class AddMoreFilteredDataToPdfDocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :pdf_documents, :address, :text
    add_column :pdf_documents, :agreement_date, :date
    add_column :pdf_documents, :agreement_period, :string
  end
end
