defmodule SauceAnalytics.Plug.MaintainSession do
  @moduledoc """
  Plug responsible for creating entries in `Plug.Session` for clients. Required for `SauceAnalytics` to function properly.

  Two entries are created, the `session_id` entry and the `revive_session` entry.
  The names of these entries are configured in the `opts` of the `SauceAnalytics` GenServer.
  """
  import Plug.Conn

  def init(options) do
    options
  end
  
  def call(conn, _opts) do
    state = SauceAnalytics.get_state()

    {conn, session_id} =
      conn
      |> fetch_session()
      |> create_session(state.session_name)

    unless SauceAnalytics.Store.entry_exists?(session_id) do
      SauceAnalytics.Store.new_entry(session_id)
    end

    conn
  end

  defp create_session(conn, key) do
    session = get_session(conn, key)

    if is_nil(session) do
      session_id = make_ref()

      user_agent = List.first(get_req_header(conn, "user-agent"))

      session = %SauceAnalytics.Session{
        sid: session_id,
        uid: nil,
        user_agent: user_agent,
        client_ip: Enum.join(Tuple.to_list(conn.remote_ip), ".")
      }

      {conn
      |> put_session(key, session), session_id}
    else
      {conn, session}
    end
  end

end
