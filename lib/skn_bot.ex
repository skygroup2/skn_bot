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
