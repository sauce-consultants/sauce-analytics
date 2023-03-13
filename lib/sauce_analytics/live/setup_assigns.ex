defmodule SauceAnalytics.Live.SetupAssigns do
  @moduledoc """
  Callback which is invoked on the `Phoenix.LiveView`'s mount using `on_mount/4`. Required when invoked `SauceAnalytics` functions in a `Phoenix.LiveView`.

  Sets up an assign which holds a `SauceAnalytics.ReviveSession`, the name of this assign is configured in the `opts` of `SauceAnalytics`.
  """
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(
        :default,
        _params,
        session,
        socket
      ) do
    state = SauceAnalytics.get_state()
    key_name = Atom.to_string(state.revive_session_name)
    %{^key_name => revive_info} = session

    SauceAnalytics.Store.maybe_revive_session(revive_info)
    %{address: address} = get_connect_info(socket, :peer_data)

    client_ip = Enum.join(Tuple.to_list(address), ".")

    {:cont,
     socket
     |> assign(state.revive_session_name, %{revive_info | client_ip: client_ip})}
  end
end
