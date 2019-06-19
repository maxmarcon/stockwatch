class IexSymbol < ApplicationRecord

  self.inheritance_column = nil

  validates :symbol, :name, :date, :type, :region, :currency, presence: true
  validates :iex_id, presence: true, uniqueness: true
end
