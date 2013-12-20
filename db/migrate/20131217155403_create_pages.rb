class CreatePages < ActiveRecord::Migration
  def change
    create_table :pages do |t|
      t.string :name
      t.string :slug
      t.text :body
      t.text :meta

      t.timestamps
    end
  end
end