defmodule Skn.DB.BotSession do
    require Logger
    def get(botid) do
        case :ets.lookup(:bot_session, botid) do
            [c|_] -> c
            _ -> nil
        end
    end

    def get(bottype, botid) do
        case bottype do
        :farmer ->
            get(botid)
        :order ->
            get(botid)
        _ ->
            get("AH_#{botid}")
        end
    end

    def set(bottype, bot, data) do
        case bottype do
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

    def delete(bottype, botid) do
        case bottype do
        :farmer ->
            delete(botid)
        :order ->
            delete(botid)
        _ ->
            delete("AH_#{botid}")
        end
    end

    defp delete(botid) do
        case get(botid) do
        {_, %{pid: pid}} when pid == self() ->
            :ets.delete(:bot_session, botid)
        _ ->
            nil
        end
    end
end