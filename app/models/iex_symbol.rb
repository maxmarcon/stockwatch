class IexSymbol < ApplicationRecord

  self.inheritance_column = nil

  validates :symbol, :name, :date, :type, :region, :currency, :iex_id, presence: true

  attr_accessor :isin

  has_one :iex_isin_mapping, foreign_key: :iex_id, primary_key: :iex_id, inverse_of: :iex_symbol
  has_many :iex_chart_entries, foreign_key: :symbol, primary_key: :symbol, inverse_of: :iex_symbols

  def attributes
    super.merge('isin' => isin)
  end
end
