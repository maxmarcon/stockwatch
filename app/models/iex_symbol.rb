class IexSymbol < ApplicationRecord

  self.inheritance_column = nil

  validates :symbol, :name, :date, :type, :region, :currency, presence: true
  validates :iex_id, presence: true, uniqueness: true

  has_one :iex_isin_mapping, foreign_key: :iex_id, primary_key: :iex_id, inverse_of: :iex_symbol
end
