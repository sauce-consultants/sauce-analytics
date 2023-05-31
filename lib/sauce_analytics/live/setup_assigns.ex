defmodule SauceAnalytics.Live.SetupAssigns do
  @moduledoc """
  Callback which is invoked on the `Phoenix.LiveView`'s mount using `on_mount/4`. Required when invoked `SauceAnalytics` functions in a `Phoenix.LiveView`.

  Sets up an assign which holds a `SauceAnalytics.ReviveSession`, the name of this assign is configured in the `opts` of `SauceAnalytics`.
  """
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(
        _,
        _params,
        session,
        socket
      ) do
    state = SauceAnalytics.get_state()
    key = Atom.to_string(state.session_name)
    
    %{^key => analytics_session} = session

    SauceAnalytics.Store.maybe_restore_entry(analytics_session.sid)
    %{address: address} = get_connect_info(socket, :peer_data)

    client_ip = Enum.join(Tuple.to_list(address), ".")

    {:cont,
     socket
     |> assign(key, %{analytics_session | client_ip: client_ip})}
  end
end
