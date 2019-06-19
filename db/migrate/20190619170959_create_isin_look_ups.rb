class CreateIsinLookUps < ActiveRecord::Migration[5.2]
  def change
    create_table :isin_look_ups do |t|
      t.string :isin

      t.timestamps
    end
  end
end
