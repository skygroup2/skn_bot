defmodule Skn.DB.BotSession do
  require Logger

  def to_id(bot_type, bot_id) do
    if bot_type in [:farmer, :order] do
      bot_id
    else
      "AH_#{bot_id}"
    end
  end

  def get(bot_id) do
    case :ets.lookup(:bot_session, bot_id) do
      [c] -> c
      _ -> nil
    end
  end

  def get(bot_type, bot_id) do
    get(to_id(bot_type, bot_id))
  end

  def set(bot_type, bot_id, data) do
    set(to_id(bot_type, bot_id), data)
  end

  defp set(bot_id, data) do
    :ets.insert(:bot_session, {bot_id, data})
  end

  def delete(bot_type, bot_id) do
    delete(to_id(bot_type, bot_id))
  end

  def delete(bot_id) do
    case get(bot_id) do
      {_, %{pid: pid}} when pid == self() ->
        :ets.delete(:bot_session, bot_id)
      _ ->
        nil
    end
  end
end