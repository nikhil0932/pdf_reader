class AddStartDateAndEndDateToPdfDocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :pdf_documents, :start_date, :date
    add_column :pdf_documents, :end_date, :date
  end
end
