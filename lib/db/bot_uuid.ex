defmodule Skn.DB.UUID do
  require Skn.Bot.Repo
  require Logger

  def get(id) do
    case :mnesia.dirty_read(:uuid_record, id) do
      [c | _] ->
        {
          :ok,
          %{
            id: Skn.Bot.Repo.uuid_record(c, :id),
            status: Skn.Bot.Repo.uuid_record(c, :status),
            updated: Skn.Bot.Repo.uuid_record(c, :updated)
          }
        }
      _ ->
        {:error, :not_found}
    end
  end

  def update(uuid) do
    ts_now = :erlang.system_time(:millisecond)
    obj = Skn.Bot.Repo.uuid_record id: uuid[:id], status: uuid[:status], updated: ts_now
    if uuid[:status] == 1 do
      case :mnesia.dirty_read(:uuid_record, obj) do
        [c | _] ->
          case Skn.Bot.Repo.uuid_record(c, :status) do
            1 -> {:error, :taken}
            _ ->
              :mnesia.dirty_write(:uuid_record, obj)
          end
        _ ->
          :mnesia.dirty_write(:uuid_record, obj)
      end
    else
      :mnesia.dirty_write(:uuid_record, obj)
    end
  end

  def delete(id) do
    :mnesia.dirty_delete(:uuid_record, id)
  end
end