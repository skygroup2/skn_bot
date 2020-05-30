defmodule Skn.Bot.Repo do
  require Record

  @bot_record_fields [id: :nil, config: %{}, uid: nil, idx1: 0, idx2: 0, idx3: 0, idx4: 0, idx5: 0]
  Record.defrecord :bot_record, @bot_record_fields

  @uuid_record_fields [id: 0, status: 0, updated: 0]
  Record.defrecord :uuid_record, @uuid_record_fields

  def fields(x) do
    Keyword.keys x
  end

  def create_table() do
    :mnesia.create_table(:bot_record,[disc_copies: [node()], record_name: :bot_record, index: [:uid], attributes: fields(@bot_record_fields)])
    :mnesia.create_table(:bot_record2,[disc_copies: [node()], record_name: :bot_record, index: [:uid], attributes: fields(@bot_record_fields)])
    :mnesia.create_table(:uuid_record,[disc_copies: [node()], record_name: :uuid_record, attributes: fields(@uuid_record_fields)])
  end

  def create_db() do
    :ets.new(:bot_session, [:public, :set, :named_table, {:read_concurrency, true}])
  end
end

