class CreateImageVersions < ActiveRecord::Migration
  def self.up
    create_table :image_versions do |t|
      t.integer :imageversionable_id, :version, :priority
      t.string :imageversionable_type, :state, :error, :label
      t.timestamps
    end
  end

  def self.down
    drop_table :image_versions
  end
end