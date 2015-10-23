class CreateCategoryCaches < ActiveRecord::Migration
  def up
    create_table :category_caches do |t|
      t.string :name
      t.string :category

      t.timestamps
    end
  end

  def down
    drop_table :category_caches
  end

end