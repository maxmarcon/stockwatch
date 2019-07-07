class CreateApiCallHistory < ActiveRecord::Migration[5.2]
  def change
    create_table :api_calls do |t|

      t.string :api, null: false
      t.string :call_digest, null: false
      t.datetime :called_at

      t.timestamps
    end

    add_index :api_calls, [:api, :call_digest], unique: true
  end
end
