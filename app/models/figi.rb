class Figi < ApplicationRecord

  validates :isin, :name, :ticker, :unique_id, presence: true
  validates :figi, uniqueness: true, presence: true

end
