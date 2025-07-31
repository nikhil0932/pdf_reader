class RemoveActiveStorage < ActiveRecord::Migration[7.1]
  def up
    # Remove foreign key constraints first
    remove_foreign_key :active_storage_attachments, :active_storage_blobs if foreign_key_exists?(:active_storage_attachments, :active_storage_blobs)
    remove_foreign_key :active_storage_variant_records, :active_storage_blobs if foreign_key_exists?(:active_storage_variant_records, :active_storage_blobs)
    
    # Drop Active Storage tables
    drop_table :active_storage_variant_records if table_exists?(:active_storage_variant_records)
    drop_table :active_storage_attachments if table_exists?(:active_storage_attachments)
    drop_table :active_storage_blobs if table_exists?(:active_storage_blobs)
  end
  
  def down
    # This would recreate the Active Storage tables
    # You can run: rails active_storage:install:migrations if you want to restore
    raise ActiveRecord::IrreversibleMigration, "Cannot recreate Active Storage tables. Run 'rails active_storage:install:migrations' to restore."
  end
end
