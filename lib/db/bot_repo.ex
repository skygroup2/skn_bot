defmodule Skn.Bot.Repo do
  require Record

  @bot_record_fields [id: :nil, config: %{}, id1: 0, id2: 0, id3: 0]
  Record.defrecord :bot_record, @bot_record_fields

  @uuid_record_fields [id: 0, status: 0, updated: 0]
  Record.defrecord :uuid_record, @uuid_record_fields

  def fields(x) do
    Keyword.keys x
  end

  def create_table() do
    :mnesia.create_table(:bot_record,[disc_copies: [node()], record_name: :bot_record, index: [:id1], attributes: fields(@bot_record_fields)])
    :mnesia.create_table(:uuid_record,[disc_copies: [node()], record_name: :uuid_record, attributes: fields(@uuid_record_fields)])
  end

  def create_db() do
    :ets.new(:bot_session, [:public, :set, :named_table, {:read_concurrency, true}])
  end

  def migrate() do
    :mnesia.transform_table(:bot_record, fn x ->
      case x do
        {:bot_record, _id, _config, _id1, _id2, _id3} -> :ignore
        _ -> {:bot_record, elem(x, 1), elem(x, 2), elem(x, 3), nil, nil}
      end
    end,
      fields(@bot_record_fields))
  end
end

