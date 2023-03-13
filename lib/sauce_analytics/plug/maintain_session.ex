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

    conn =
      conn
      |> fetch_session()

    session_id = get_session(conn, state.session_id_name)
    user_agent = List.first(get_req_header(conn, "user-agent"))

    conn =
      if session_id == nil do
        session_id = make_ref()

        revive_info = %SauceAnalytics.ReviveSession{
          sid: session_id,
          uid: nil,
          user_agent: user_agent,
          client_ip: Enum.join(Tuple.to_list(conn.remote_ip), ".")
        }

        conn
        |> put_session(state.session_id_name, session_id)
        |> put_session(state.revive_session_name, revive_info)
      else
        conn
      end

    session_id = get_session(conn, state.session_id_name)

    unless SauceAnalytics.Store.session_exists?(session_id) do
      SauceAnalytics.Store.new_session(
        session_id,
        user_agent
      )
    end

    conn
  end
end
