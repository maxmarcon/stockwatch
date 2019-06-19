class AddIsinToIexSymbols < ActiveRecord::Migration[5.2]
  def change
    add_column :iex_symbols, :isin, :string

    add_index :iex_symbols, :isin
    add_index :iex_symbols, :symbol
  end
end
