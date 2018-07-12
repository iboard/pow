defmodule Authex.Plug.Session do
  @moduledoc """
  This plug will handle user authorization using session.

  Example:

    plug Plug.Session,
      store: :cookie,
      key: "_my_app_demo_key",
      signing_salt: "secret"

    plug Authex.Plug.Session,
      repo: MyApp.Repo,
      user: MyApp.User,
      current_user_assigns_key: :current_user,
      session_key: "auth",
      session_store: Authex.Store.CredentialsCache,
      credentials_cache_name: "credentials",
      credentials_cache_ttl: :timer.hours(48),
      users_context: Authex.Ecto.Users
  """
  alias Plug.Conn
  alias Authex.{Plug, Store.CredentialsCache, Config}

  @spec init(Config.t()) :: Config.t()
  def init(config), do: config

  @spec call(Conn.t(), Config.t()) :: Conn.t()
  def call(conn, config) do
    conn = Plug.put_config(conn, Config.put(config, :mod, __MODULE__))

    conn
    |> Plug.current_user()
    |> maybe_fetch_from_session(conn, config)
  end

  @spec create(Conn.t(), any()) :: Conn.t()
  def create(conn, user) do
    key           = UUID.uuid1()
    config        = Plug.fetch_config(conn)
    session_key   = session_key(config)
    store         = store(config)

    delete(conn)
    store.put(config, key, user)

    conn
    |> Conn.put_session(session_key, key)
    |> Plug.assign_current_user(user, config)
  end

  @spec delete(Conn.t()) :: Conn.t()
  def delete(conn) do
    config      = Plug.fetch_config(conn)
    key         = Conn.get_session(conn, session_key(config))
    store       = store(config)
    session_key = session_key(config)

    store.delete(config, key)

    conn
    |> Conn.delete_session(session_key)
    |> Plug.assign_current_user(nil, config)
  end

  defp maybe_fetch_from_session(nil, conn, config) do
    conn
    |> Conn.fetch_session()
    |> get_session(config)
    |> case do
      :not_found -> conn
      user       -> Plug.assign_current_user(conn, user, config)
    end
  end
  defp maybe_fetch_from_session(_user, conn, _config), do: conn

  defp get_session(conn, config) do
    key = Conn.get_session(conn, session_key(config))

    store(config).get(config, key)
  end

  defp session_key(config) do
    Config.get(config, :session_key, "auth")
  end

  defp store(config) do
    Config.get(config, :session_store, CredentialsCache)
  end
end