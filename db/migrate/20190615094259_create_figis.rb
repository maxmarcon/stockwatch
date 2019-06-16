class CreateFigis < ActiveRecord::Migration[5.2]
  def change
    create_table :figis do |t|

      t.string :figi, null: false
      t.string :isin
      t.string :name, null: false
      t.string :ticker, null: false
      t.string :unique_id, null: false
      t.string :exch_code

      t.timestamps
    end

    add_index :figis, :figi, unique: true
  end
end
