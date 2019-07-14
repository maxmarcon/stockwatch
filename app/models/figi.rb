class Figi < ApplicationRecord

  validates :isin, :name, :ticker, :unique_id, :figi, presence: true
end
