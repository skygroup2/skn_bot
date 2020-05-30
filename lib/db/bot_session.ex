defmodule Skn.DB.BotSession do
    require Logger
    def get(bot_id) do
        case :ets.lookup(:bot_session, bot_id) do
            [c|_] -> c
            _ -> nil
        end
    end

    def get(bot_type, bot_id) do
        case bot_type do
        :farmer ->
            get(bot_id)
        :order ->
            get(bot_id)
        _ ->
            get("AH_#{bot_id}")
        end
    end

    def set(bot_type, bot, data) do
        case bot_type do
        :farmer ->
            set(bot, data)
        :order ->
            set(bot, data)
        _ ->
            set("AH_#{bot}", data)
        end
    end

    defp set(bot, data) do
        :ets.insert :bot_session, {bot, data}
    end

    def delete(bot_type, bot_id) do
        case bot_type do
        :farmer ->
            delete(bot_id)
        :order ->
            delete(bot_id)
        _ ->
            delete("AH_#{bot_id}")
        end
    end

    defp delete(bot_id) do
        case get(bot_id) do
        {_, %{pid: pid}} when pid == self() ->
            :ets.delete(:bot_session, bot_id)
        _ ->
            nil
        end
    end
end