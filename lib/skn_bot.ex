defmodule Skn.Bot.Sup do
  use Supervisor
  @name :skn_bot_sup
  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def init(_) do
    children = [
      worker(RWSerializer, [[]]),
    ]
    supervise(children, strategy: :one_for_one)
  end
end

defmodule Skn.Bot do

  def q_correlation_id(bottype, botid) do
    case bottype do
    :none -> botid
    :order -> botid
    :farmer -> "BT_#{botid}"
    _ -> "BT_AH_#{botid}"
    end
  end
end