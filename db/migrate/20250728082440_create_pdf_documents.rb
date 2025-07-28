class CreatePdfDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :pdf_documents do |t|
      t.string :title
      t.text :content
      t.integer :page_count
      t.datetime :uploaded_at

      t.timestamps
    end
  end
end
