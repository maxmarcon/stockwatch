class IexChartEntry < ApplicationRecord

  validates :symbol, :date, :close, :volume, :change, :change_percent, :change_over_time, presence: true

  has_many :iex_symbols, foreign_key: :symbol, primary_key: :symbol
end
