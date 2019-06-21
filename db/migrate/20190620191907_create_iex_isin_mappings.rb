class CreateIexIsinMappings < ActiveRecord::Migration[5.2]
  def change
    create_table :iex_isin_mappings do |t|

      t.string :isin, null: false
      t.string :iex_id

      t.timestamps
    end

    add_index :iex_isin_mappings, [:isin, :iex_id], unique: true
  end
end
