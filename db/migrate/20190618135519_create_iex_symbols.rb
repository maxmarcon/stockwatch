class CreateIexSymbols < ActiveRecord::Migration[5.2]
  def change
    create_table :iex_symbols do |t|

      t.string :symbol, null: false
      t.string :exchange
      t.string :name, null: false
      t.date :date, null: false
      t.string :type, null: false
      t.string :iex_id, null: false
      t.string :region, limit: 2, null: false
      t.string :currency, limit: 3, null: false

      t.timestamps
    end

    add_index :iex_symbols, :iex_id, unique: true
  end
end
