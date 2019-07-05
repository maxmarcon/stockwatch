class ApiCall < ApplicationRecord

  validates :api, :call_digest, presence: true
  validates :api, uniqueness: {scope: :call_digest}

  def self.called?(api, call_digest, max_age = nil)
    query = where(api: api, call_digest: call_digest)
    if max_age
      query = query.where("updated_at >= ?", max_age.ago)
    end

    query.exists?
  end

  def self.record_call(api, call_digest)
    record = find_or_initialize_by(api: api, call_digest: call_digest)

    if record.persisted?
      record.touch
    else
      record.save!
    end
  end
end
