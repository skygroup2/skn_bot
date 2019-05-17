defmodule Skn.EA.Repo.Migrations.CreateCardPrice do
  use Ecto.Migration

  def up do
    create_if_not_exists table(:bot_info, primary_key: false) do
      add :uuid,  :string, primary_key: true, size: 512
      add :app,   :string, size: 32
      add :node,  :string, size: 64
      add :data,  :binary
    end
  end

  def down do
    drop table(:bot_info)
  end
end
