class ApiCall < ApplicationRecord

  validates :api, :call_digest, presence: true

  def self.atomic_api_call(api, call_digest, max_age = nil)
    raise "You need to pass a block" unless block_given?

    begin
      create!(api: api, call_digest: call_digest)
    rescue ActiveRecord::RecordNotUnique
    end

    api_call = find_by(api: api, call_digest: call_digest)

    api_call.with_lock(true) do
      if [api_call.called_at, max_age].any?(&:nil?) || api_call.called_at < max_age.ago
        result = yield

        api_call.called_at = Time.now
        api_call.save!
        [true, result]
      else
        Rails.logger.info("skipping API call to #{[api, call_digest]} because executed in the last #{max_age.inspect}")

        [false, :called_recently]
      end
    end
  end
end
