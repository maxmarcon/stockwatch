class CreateIexChartEntries < ActiveRecord::Migration[5.2]
  def change
    create_table :iex_chart_entries do |t|

      t.string :symbol, null: false
      t.date :date, null: false
      t.float :close, null: false
      t.float :volume, null: false
      t.float :change, null: false
      t.float :change_percent, null: false
      t.float :change_over_time, null: false

      t.timestamps
    end

    add_index :iex_chart_entries, [:symbol, :date], unique: true
  end
end
