class IexIsinMapping < ApplicationRecord

  validates :isin, presence: true, uniqueness: { scope: :iex_id }

  belongs_to :iex_symbol, foreign_key: :iex_id, primary_key: :iex_id, optional: true, inverse_of: :iex_isin_mapping
end
